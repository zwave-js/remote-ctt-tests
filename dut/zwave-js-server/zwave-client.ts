/**
 * Z-Wave JS Server WebSocket Client
 *
 * Provides a client wrapper for communicating with zwave-js-server via WebSocket.
 * Includes NodeProxy and EndpointProxy classes that mimic the ZWaveNode interface
 * but route all operations through WebSocket commands.
 */

import WebSocket from "ws";
import { EventEmitter } from "events";
import type { ValueID, ValueMetadata } from "zwave-js";
import type { CommandClasses } from "@zwave-js/core";

// === Types ===

export interface ZWaveClientOptions {
  url: string;
  schemaVersion?: number;
}

interface PendingCommand {
  resolve: (result: unknown) => void;
  reject: (error: Error) => void;
}

interface OutgoingCommand {
  messageId: string;
  command: string;
  [key: string]: unknown;
}

interface IncomingMessage {
  type: "version" | "result" | "event";
  messageId?: string;
  success?: boolean;
  result?: unknown;
  errorCode?: string;
  message?: string;
  event?: {
    source: string;
    event: string;
    [key: string]: unknown;
  };
  driverVersion?: string;
  serverVersion?: string;
  homeId?: number;
  minSchemaVersion?: number;
  maxSchemaVersion?: number;
}

// State types from zwave-js-server
// Server sends values as an array of value objects, not a Record
interface ServerValue {
  commandClass: number;
  endpoint?: number;
  property: string | number;
  propertyKey?: string | number;
  value: unknown;
  metadata: ValueMetadata;
}

interface NodeState {
  nodeId: number;
  values: ServerValue[];
  endpoints: number[];
  [key: string]: unknown;
}

interface ZwaveState {
  controller: {
    homeId: number;
    nodes: NodeState[];
    [key: string]: unknown;
  };
}

// === EndpointProxy ===

export class EndpointProxy {
  constructor(
    private client: ZWaveClient,
    public readonly nodeId: number,
    public readonly index: number
  ) {}

  get commandClasses(): CCProxy {
    return new CCProxy(this.client, this.nodeId, this.index);
  }
}

// === CCProxy ===

/**
 * Proxy for command class API calls.
 * Uses Proxy to intercept property access and method calls.
 */
export class CCProxy {
  constructor(
    private client: ZWaveClient,
    private nodeId: number,
    private endpoint: number
  ) {
    return new Proxy(this, {
      get: (target, prop) => {
        if (typeof prop === "string") {
          // Return a proxy object for the command class
          return target.getCCAPI(prop);
        }
        return undefined;
      },
    });
  }

  private getCCAPI(commandClassName: string): unknown {
    const client = this.client;
    const nodeId = this.nodeId;
    const endpoint = this.endpoint;

    // Map command class names to their numeric IDs
    const ccNameToId: Record<string, number> = {
      Basic: 0x20,
      "Binary Switch": 0x25,
      "Multilevel Switch": 0x26,
      "Binary Sensor": 0x30,
      "Multilevel Sensor": 0x31,
      Meter: 0x32,
      "Color Switch": 0x33,
      "Central Scene": 0x5b,
      Configuration: 0x70,
      Notification: 0x71,
      "Manufacturer Specific": 0x72,
      Powerlevel: 0x73,
      Battery: 0x80,
      "Wake Up": 0x84,
      Association: 0x85,
      Version: 0x86,
      Indicator: 0x87,
      "Door Lock": 0x62,
      "User Code": 0x63,
      "Barrier Operator": 0x66,
      "Entry Control": 0x6f,
      "Thermostat Mode": 0x40,
      "Thermostat Setpoint": 0x43,
      "Thermostat Setback": 0x47,
      "Sound Switch": 0x79,
      "Window Covering": 0x6a,
      "Device Reset Locally": 0x5a,
    };

    const commandClass = ccNameToId[commandClassName] ?? parseInt(commandClassName, 16);

    // Return a proxy that intercepts method calls
    return new Proxy(
      {},
      {
        get: (_target, methodName) => {
          if (typeof methodName === "string") {
            // Return a function that sends the command via WebSocket
            return async (...args: unknown[]) => {
              return client.sendCommand("endpoint.invoke_cc_api", {
                nodeId,
                endpoint,
                commandClass,
                methodName,
                args,
              });
            };
          }
          return undefined;
        },
      }
    );
  }
}

// === NodeProxy ===

export class NodeProxy {
  public readonly id: number;
  private _state: NodeState;
  public interviewComplete: boolean = false;

  constructor(
    private client: ZWaveClient,
    state: NodeState
  ) {
    this.id = state.nodeId;
    this._state = state;
  }

  /**
   * Update the cached state (called when events are received)
   */
  updateState(state: Partial<NodeState>): void {
    this._state = { ...this._state, ...state };
  }

  /**
   * Find a value entry in the array by matching valueId fields
   */
  private findValueEntry(valueId: ValueID): ServerValue | undefined {
    if (!this._state.values || !Array.isArray(this._state.values)) {
      return undefined;
    }
    return this._state.values.find(
      (v) =>
        v.commandClass === valueId.commandClass &&
        (v.endpoint ?? 0) === (valueId.endpoint ?? 0) &&
        v.property === valueId.property &&
        v.propertyKey === valueId.propertyKey
    );
  }

  /**
   * Update a specific value in the cache
   */
  updateValue(valueId: ValueID, value: unknown, metadata?: ValueMetadata): void {
    if (!this._state.values || !Array.isArray(this._state.values)) {
      this._state.values = [];
    }

    const existing = this.findValueEntry(valueId);
    if (existing) {
      existing.value = value;
      if (metadata) {
        existing.metadata = metadata;
      }
    } else {
      this._state.values.push({
        commandClass: valueId.commandClass,
        endpoint: valueId.endpoint,
        property: valueId.property,
        propertyKey: valueId.propertyKey,
        value,
        metadata: metadata ?? ({} as ValueMetadata),
      });
    }
  }

  /**
   * Get a value from the cached state (synchronous)
   */
  getValue<T = unknown>(valueId: ValueID): T | undefined {
    const entry = this.findValueEntry(valueId);
    return entry?.value as T | undefined;
  }

  /**
   * Set a value via WebSocket command (async)
   */
  async setValue(valueId: ValueID, value: unknown, options?: unknown): Promise<unknown> {
    return this.client.sendCommand("node.set_value", {
      nodeId: this.id,
      valueId,
      value,
      options,
    });
  }

  /**
   * Get value metadata from cached state (synchronous)
   */
  getValueMetadata(valueId: ValueID): ValueMetadata {
    const entry = this.findValueEntry(valueId);
    return entry?.metadata ?? ({} as ValueMetadata);
  }

  /**
   * Get all defined value IDs via WebSocket command
   */
  async getDefinedValueIDs(): Promise<ValueID[]> {
    const result = await this.client.sendCommand("node.get_defined_value_ids", {
      nodeId: this.id,
    });
    return (result as { valueIds: ValueID[] }).valueIds;
  }

  /**
   * Get an endpoint proxy
   */
  getEndpoint(index: number): EndpointProxy {
    return new EndpointProxy(this.client, this.id, index);
  }

  /**
   * Get command classes for the root endpoint (endpoint 0)
   */
  get commandClasses(): CCProxy {
    return new CCProxy(this.client, this.id, 0);
  }

  /**
   * Refresh node info via WebSocket command
   */
  async refreshInfo(): Promise<void> {
    await this.client.sendCommand("node.refresh_info", {
      nodeId: this.id,
    });
  }

  /**
   * Poll a specific value via WebSocket command
   */
  async pollValue(valueId: ValueID): Promise<unknown> {
    const result = await this.client.sendCommand("node.poll_value", {
      nodeId: this.id,
      valueId,
    });
    return (result as { value: unknown }).value;
  }

  /**
   * Ping the node
   */
  async ping(): Promise<boolean> {
    const result = await this.client.sendCommand("node.ping", {
      nodeId: this.id,
    });
    return (result as { responded: boolean }).responded;
  }
}

// === ZWaveClient ===

export class ZWaveClient extends EventEmitter {
  private ws: WebSocket | null = null;
  private messageId = 0;
  private pendingCommands = new Map<string, PendingCommand>();
  private state: ZwaveState | null = null;
  private schemaVersion: number;
  private connected = false;
  private nodeProxies = new Map<number, NodeProxy>();

  constructor(private options: ZWaveClientOptions) {
    super();
    this.schemaVersion = options.schemaVersion ?? 44; // Latest schema version
  }

  /**
   * Connect to the zwave-js-server
   */
  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.options.url);

      this.ws.on("open", () => {
        console.log("[ZWaveClient] Connected to zwave-js-server");
      });

      this.ws.on("message", async (data) => {
        try {
          const message: IncomingMessage = JSON.parse(data.toString());
          await this.handleMessage(message, resolve, reject);
        } catch (error) {
          console.error("[ZWaveClient] Failed to parse message:", error);
        }
      });

      this.ws.on("close", () => {
        console.log("[ZWaveClient] Disconnected from zwave-js-server");
        this.connected = false;
        this.emit("disconnected");
      });

      this.ws.on("error", (error) => {
        console.error("[ZWaveClient] WebSocket error:", error);
        if (!this.connected) {
          reject(error);
        }
        this.emit("error", error);
      });
    });
  }

  /**
   * Handle incoming messages from the server
   */
  private async handleMessage(
    message: IncomingMessage,
    connectResolve: () => void,
    connectReject: (error: Error) => void
  ): Promise<void> {
    switch (message.type) {
      case "version": {
        console.log(
          `[ZWaveClient] Server version: ${message.serverVersion}, Driver version: ${message.driverVersion}`
        );
        // Send set_api_schema command (required before start_listening)
        const schemaMessageId = this.getNextMessageId();
        this.pendingCommands.set(schemaMessageId, {
          resolve: async () => {
            // After schema is set, send start_listening
            const listenMessageId = this.getNextMessageId();
            this.pendingCommands.set(listenMessageId, {
              resolve: (result) => {
                if (result && typeof result === "object" && "state" in result) {
                  this.state = (result as { state: ZwaveState }).state;
                  this.initializeNodeProxies();
                  this.connected = true;
                  console.log("[ZWaveClient] Received state, connection complete");
                  connectResolve();
                }
              },
              reject: connectReject,
            });
            this.sendRaw({
              messageId: listenMessageId,
              command: "start_listening",
            });
          },
          reject: connectReject,
        });
        this.sendRaw({
          messageId: schemaMessageId,
          command: "set_api_schema",
          schemaVersion: this.schemaVersion,
        });
        break;
      }

      case "result": {
        const pending = this.pendingCommands.get(message.messageId!);
        if (pending) {
          this.pendingCommands.delete(message.messageId!);
          if (message.success) {
            pending.resolve(message.result);
          } else {
            pending.reject(
              new Error(message.message ?? `Command failed: ${message.errorCode}`)
            );
          }
        }
        break;
      }

      case "event": {
        this.handleEvent(message.event!);
        break;
      }
    }
  }

  /**
   * Handle events from the server
   */
  private handleEvent(event: { source: string; event: string; [key: string]: unknown }): void {
    const { source, event: eventName, ...data } = event;

    // Emit the raw event for handlers to process
    this.emit("event", { source, event: eventName, ...data });

    // Handle specific events
    switch (source) {
      case "controller": {
        this.handleControllerEvent(eventName, data);
        break;
      }
      case "node": {
        this.handleNodeEvent(eventName, data);
        break;
      }
    }
  }

  /**
   * Handle controller events
   */
  private handleControllerEvent(eventName: string, data: Record<string, unknown>): void {
    switch (eventName) {
      case "node added": {
        const nodeState = data.node as NodeState;
        if (nodeState) {
          const proxy = new NodeProxy(this, nodeState);
          this.nodeProxies.set(nodeState.nodeId, proxy);
          this.emit("node added", proxy);
        }
        break;
      }
      case "node removed": {
        const nodeId = data.node as number;
        this.nodeProxies.delete(nodeId);
        this.emit("node removed", nodeId);
        break;
      }
      case "grant security classes": {
        this.emit("grant security classes", data);
        break;
      }
      case "validate dsk and enter pin": {
        this.emit("validate dsk and enter pin", data);
        break;
      }
      case "inclusion started":
      case "inclusion stopped":
      case "exclusion started":
      case "exclusion stopped": {
        this.emit(eventName, data);
        break;
      }
    }
  }

  /**
   * Handle node events
   */
  private handleNodeEvent(eventName: string, data: Record<string, unknown>): void {
    const nodeId = data.nodeId as number;
    const node = this.nodeProxies.get(nodeId);

    switch (eventName) {
      case "value updated":
      case "value added": {
        const args = data.args as {
          commandClass: number;
          endpoint?: number;
          property: string | number;
          propertyKey?: string | number;
          newValue: unknown;
        };
        if (node && args) {
          node.updateValue(
            {
              commandClass: args.commandClass,
              endpoint: args.endpoint,
              property: args.property,
              propertyKey: args.propertyKey,
            },
            args.newValue
          );
        }
        this.emit("node value updated", node, args);
        break;
      }
      case "value notification": {
        this.emit("node value notification", node, data.args);
        break;
      }
      case "metadata updated": {
        // Update cached metadata when it changes
        const args = data.args as {
          commandClass: number;
          endpoint?: number;
          property: string | number;
          propertyKey?: string | number;
          metadata: ValueMetadata;
        };
        if (node && args?.metadata) {
          node.updateValue(
            {
              commandClass: args.commandClass,
              endpoint: args.endpoint,
              property: args.property,
              propertyKey: args.propertyKey,
            },
            node.getValue({
              commandClass: args.commandClass,
              endpoint: args.endpoint,
              property: args.property,
              propertyKey: args.propertyKey,
            }),
            args.metadata
          );
        }
        break;
      }
      case "notification": {
        this.emit("node notification", node, data);
        break;
      }
      case "interview completed": {
        if (node) {
          node.interviewComplete = true;
        }
        this.emit("node interview completed", node);
        break;
      }
      case "ready": {
        // Update node with full state from the "ready" event (includes all values and metadata)
        const nodeState = data.nodeState as NodeState | undefined;
        if (node) {
          node.interviewComplete = true;
          if (nodeState) {
            node.updateState(nodeState);
          }
        }
        this.emit("node ready", node);
        break;
      }
    }
  }

  /**
   * Initialize node proxies from the initial state
   */
  private initializeNodeProxies(): void {
    if (!this.state?.controller?.nodes) return;

    for (const nodeState of this.state.controller.nodes) {
      const proxy = new NodeProxy(this, nodeState);
      this.nodeProxies.set(nodeState.nodeId, proxy);
    }
  }

  /**
   * Get the next message ID
   */
  private getNextMessageId(): string {
    return String(++this.messageId);
  }

  /**
   * Send a raw command to the server
   */
  private sendRaw(command: OutgoingCommand): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }
    this.ws.send(JSON.stringify(command));
  }

  /**
   * Send a command and wait for the response
   */
  async sendCommand(command: string, params: Record<string, unknown> = {}): Promise<unknown> {
    const messageId = this.getNextMessageId();

    return new Promise((resolve, reject) => {
      this.pendingCommands.set(messageId, { resolve, reject });

      const message: OutgoingCommand = {
        messageId,
        command,
        ...params,
      };

      try {
        this.sendRaw(message);
      } catch (error) {
        this.pendingCommands.delete(messageId);
        reject(error);
      }

      // Timeout after 30 seconds
      setTimeout(() => {
        if (this.pendingCommands.has(messageId)) {
          this.pendingCommands.delete(messageId);
          reject(new Error(`Command ${command} timed out`));
        }
      }, 30000);
    });
  }

  /**
   * Start listening for events (must be called after connect)
   */
  async startListening(): Promise<ZwaveState> {
    const result = await this.sendCommand("start_listening");
    return (result as { state: ZwaveState }).state;
  }

  /**
   * Get a node proxy by ID
   */
  getNode(nodeId: number): NodeProxy | undefined {
    return this.nodeProxies.get(nodeId);
  }

  /**
   * Get all node proxies
   */
  getAllNodes(): NodeProxy[] {
    return Array.from(this.nodeProxies.values());
  }

  /**
   * Check if a node exists
   */
  hasNode(nodeId: number): boolean {
    return this.nodeProxies.has(nodeId);
  }

  /**
   * Get the current state
   */
  getState(): ZwaveState | null {
    return this.state;
  }

  /**
   * Check if connected
   */
  isConnected(): boolean {
    return this.connected;
  }

  /**
   * Disconnect from the server
   */
  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.connected = false;
    this.pendingCommands.clear();
    this.nodeProxies.clear();
  }
}
