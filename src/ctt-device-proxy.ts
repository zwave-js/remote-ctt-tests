import * as net from "net";
import c from "ansi-colors";

export type FrameHandler = (
  config: ProxyConfig,
  data: Buffer,
  direction: "toDevice" | "toCTT",
  forward: (data: Buffer) => void,
  respond: (data: Buffer) => void
) => void;

export interface ProxyConfig {
  name: string;
  listenPort: number;
  targetHost: string;
  targetPort: number;
}

interface ProxyConnection {
  clientSocket: net.Socket;
  targetSocket: net.Socket;
}

export class CTTDeviceProxy {
  private servers: net.Server[] = [];
  private connections: ProxyConnection[] = [];
  private frameHandler: FrameHandler;
  private configs: ProxyConfig[];

  constructor(configs: ProxyConfig[], frameHandler: FrameHandler) {
    this.configs = configs;
    this.frameHandler = frameHandler;
  }

  async start(): Promise<void> {
    const startPromises = this.configs.map((config) => this.startProxy(config));
    await Promise.all(startPromises);
    console.log(c.green("All CTT device proxies started"));
  }

  private startProxy(config: ProxyConfig): Promise<void> {
    return new Promise((resolve, reject) => {
      const server = net.createServer((clientSocket) => {
        this.handleConnection(config, clientSocket);
      });

      server.on("error", (err) => {
        console.error(
          c.red(`[Proxy ${config.name}] Server error: ${err.message}`)
        );
        reject(err);
      });

      server.listen(config.listenPort, "127.0.0.1", () => {
        console.log(
          c.dim(
            `[Proxy ${config.name}] Listening on port ${config.listenPort} -> ${config.targetHost}:${config.targetPort}`
          )
        );
        resolve();
      });

      this.servers.push(server);
    });
  }

  private handleConnection(config: ProxyConfig, clientSocket: net.Socket): void {
    console.log(c.dim(`[Proxy ${config.name}] CTT connected`));

    // Connect to target device
    const targetSocket = net.createConnection({
      host: config.targetHost,
      port: config.targetPort,
    });

    const connection: ProxyConnection = {
      clientSocket,
      targetSocket,
    };
    this.connections.push(connection);

    // Device -> CTT (toCTT direction)
    targetSocket.on("data", (data) => {
      this.frameHandler(
        config,
        data,
        "toCTT",
        (forwardData: Buffer) => {
          if (!clientSocket.destroyed) {
            clientSocket.write(forwardData);
          }
        },
        (respondData: Buffer) => {
          if (!targetSocket.destroyed) {
            targetSocket.write(respondData);
          }
        }
      );
    });

    // CTT -> Device (toDevice direction)
    clientSocket.on("data", (data) => {
      this.frameHandler(
        config,
        data,
        "toDevice",
        (forwardData: Buffer) => {
          if (!targetSocket.destroyed) {
            targetSocket.write(forwardData);
          }
        },
        (respondData: Buffer) => {
          if (!clientSocket.destroyed) {
            clientSocket.write(respondData);
          }
        }
      );
    });

    // Handle disconnections
    clientSocket.on("close", () => {
      console.log(c.dim(`[Proxy ${config.name}] CTT disconnected`));
      targetSocket.end();
      this.removeConnection(connection);
    });

    targetSocket.on("close", () => {
      console.log(c.dim(`[Proxy ${config.name}] Device disconnected`));
      clientSocket.end();
      this.removeConnection(connection);
    });

    // Handle errors
    clientSocket.on("error", (err) => {
      console.error(c.red(`[Proxy ${config.name}] CTT error: ${err.message}`));
      targetSocket.destroy();
    });

    targetSocket.on("error", (err) => {
      console.error(
        c.red(`[Proxy ${config.name}] Device error: ${err.message}`)
      );
      clientSocket.destroy();
    });
  }

  private removeConnection(connection: ProxyConnection): void {
    const index = this.connections.indexOf(connection);
    if (index !== -1) {
      this.connections.splice(index, 1);
    }
  }

  async close(): Promise<void> {
    // Close all client connections
    for (const conn of this.connections) {
      conn.clientSocket.destroy();
      conn.targetSocket.destroy();
    }
    this.connections = [];

    // Close all servers
    const closePromises = this.servers.map((server) => {
      return new Promise<void>((resolve) => {
        server.close(() => resolve());
      });
    });
    await Promise.all(closePromises);
    this.servers = [];
    console.log(c.dim("All CTT device proxies closed"));
  }
}
