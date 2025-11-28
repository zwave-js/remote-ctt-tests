import { spawn, ChildProcess } from 'child_process';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { createWebSocketServer } from './ws-server.ts';
import type { ManagedWebSocketServer } from './ws-server.ts';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 4712;

interface ManagedProcess {
  name: string;
  process: ChildProcess;
  pid?: number;
}

class ProcessManager {
  private processes: ManagedProcess[] = [];
  private wsServer?: ManagedWebSocketServer;

  startCTTRemote(): ManagedProcess {
    const cttRemotePath = path.join(__dirname, '..', 'CTT-Remote', 'CTT-Remote.exe');
    const solutionPath = path.join(__dirname, '..', 'Project', 'zwave-js.cttsln');

    console.log(`Starting CTT-Remote: ${cttRemotePath} ${solutionPath}`);

    const cttProcess = spawn(cttRemotePath, [solutionPath], {
      cwd: path.join(__dirname, '..', 'CTT-Remote'),
      stdio: 'inherit',
      windowsHide: true
    });

    cttProcess.on('error', (error) => {
      console.error('Failed to start CTT-Remote:', error);
    });

    cttProcess.on('exit', (code) => {
      console.log(`CTT-Remote exited with code ${code}`);
    });

    const managedProcess: ManagedProcess = {
      name: 'CTT-Remote',
      process: cttProcess,
      pid: cttProcess.pid
    };

    this.processes.push(managedProcess);
    return managedProcess;
  }

  startWebSocketServer(): void {
    this.wsServer = createWebSocketServer({
      port: PORT,
      onFatalError: () => this.cleanup()
    });
  }

  killProcess(managedProcess: ManagedProcess): void {
    const { pid, process: proc } = managedProcess;

    if (pid && process.platform === 'win32') {
      // On Windows, use taskkill to kill the process tree
      try {
        spawn('taskkill', ['/pid', pid.toString(), '/T', '/F'], {
          stdio: 'ignore'
        });
      } catch (error) {
        console.error(`Error killing ${managedProcess.name}:`, error);
      }
    } else if (proc && !proc.killed) {
      proc.kill();
    }
  }

  async cleanup(): Promise<void> {
    console.log('Shutting down...');

    // Kill all managed processes
    for (const managedProcess of this.processes) {
      this.killProcess(managedProcess);
    }

    // Close WebSocket server
    if (this.wsServer) {
      await this.wsServer.close();
    }

    process.exit(0);
  }

  setupExitHandlers(): void {
    // Handle various exit signals
    process.on('SIGINT', () => this.cleanup());  // Ctrl+C
    process.on('SIGTERM', () => this.cleanup()); // Termination signal

    process.on('exit', () => {
      // Synchronous kill on exit
      for (const managedProcess of this.processes) {
        const { pid } = managedProcess;
        if (pid && process.platform === 'win32') {
          try {
            require('child_process').execSync(`taskkill /pid ${pid} /T /F`, {
              stdio: 'ignore'
            });
          } catch (error) {
            // Ignore errors on exit
          }
        }
      }
    });

    // Handle uncaught errors
    process.on('uncaughtException', (error) => {
      console.error('Uncaught exception:', error);
      this.cleanup();
    });

    process.on('unhandledRejection', (reason, promise) => {
      console.error('Unhandled rejection at:', promise, 'reason:', reason);
      this.cleanup();
    });
  }
}

// Main execution
const manager = new ProcessManager();
manager.setupExitHandlers();
manager.startWebSocketServer();
manager.startCTTRemote();
