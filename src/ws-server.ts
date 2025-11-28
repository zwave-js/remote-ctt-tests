import { WebSocketServer, WebSocket } from 'ws';

export interface WebSocketServerOptions {
  port: number;
  onFatalError?: () => void;
  fatalErrorPatterns?: string[];
}

export interface ManagedWebSocketServer {
  wss: WebSocketServer;
  close: () => Promise<void>;
}

// Error messages that should trigger shutdown
const DEFAULT_FATAL_ERROR_PATTERNS = [
  'Controller is not accessible, aborting',
  // Add more error patterns here as needed
];

function shouldShutdownOnError(message: string, patterns: string[]): boolean {
  return patterns.some(pattern => message.includes(pattern));
}

export function createWebSocketServer(options: WebSocketServerOptions): ManagedWebSocketServer {
  const { port, onFatalError, fatalErrorPatterns = DEFAULT_FATAL_ERROR_PATTERNS } = options;

  const wss = new WebSocketServer({ port });

  console.log(`WebSocket server listening on port ${port}`);

  wss.on('connection', (ws: WebSocket) => {
    console.log('New client connected');

    ws.on('message', (data: Buffer) => {
      const messageStr = data.toString();
      console.log('Received message:', messageStr);

      // Parse JSON-RPC message and check for fatal errors
      try {
        const message = JSON.parse(messageStr);

        if (message.method === 'generalLogMsg' &&
            message.params?.errorType === 'Error' &&
            message.params?.output) {

          if (shouldShutdownOnError(message.params.output, fatalErrorPatterns)) {
            console.error('Fatal error detected, shutting down...');
            if (onFatalError) {
              onFatalError();
            }
          }
        }
      } catch (error) {
        // Ignore JSON parse errors
      }
    });

    ws.on('close', () => {
      console.log('Client disconnected');
    });

    ws.on('error', (error: Error) => {
      console.error('WebSocket error:', error);
    });
  });

  wss.on('error', (error: Error) => {
    console.error('Server error:', error);
  });

  const close = (): Promise<void> => {
    return new Promise((resolve) => {
      wss.close(() => {
        console.log('WebSocket server closed');
        resolve();
      });
    });
  };

  return { wss, close };
}
