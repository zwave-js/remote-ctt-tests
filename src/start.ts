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
  private dockerContainerName = 'zwave-stack';

  async startDockerContainer(): Promise<void> {
    console.log('Starting Docker container for Z-Wave stack...');

    // Start docker compose (using modern Docker CLI plugin)
    const dockerProcess = spawn('docker', ['compose', 'up', '-d'], {
      cwd: path.join(__dirname, '..'),
      stdio: 'inherit',
      shell: true
    });

    return new Promise((resolve, reject) => {
      dockerProcess.on('close', (code) => {
        if (code === 0) {
          console.log('Docker container started successfully');
          resolve();
        } else {
          reject(new Error(`Docker container failed to start with code ${code}`));
        }
      });
    });
  }

  async stopDockerContainer(): Promise<void> {
    console.log('Stopping Docker container...');

    return new Promise((resolve) => {
      const dockerProcess = spawn('docker', ['compose', 'down'], {
        cwd: path.join(__dirname, '..'),
        stdio: 'inherit',
        shell: true
      });

      dockerProcess.on('close', () => {
        console.log('Docker container stopped');
        resolve();
      });
    });
  }

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

    // Stop Docker container
    await this.stopDockerContainer();

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
async function main() {
  const manager = new ProcessManager();
  manager.setupExitHandlers();

  try {
    // Start Docker container first
    await manager.startDockerContainer();

    // Give Docker containers a moment to fully initialize
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Start WebSocket server
    manager.startWebSocketServer();

    // Start CTT-Remote
    manager.startCTTRemote();

    console.log('\nAll services started successfully!');
    console.log('Z-Wave devices available at:');
    console.log('  Controller 1 (Z-Wave JS): localhost:5000');
    console.log('  Controller 2 (CTT):       localhost:5001');
    console.log('  Controller 3 (CTT):       localhost:5002');
    console.log('  End Device 1 (CTT):       localhost:5003');
    console.log('  End Device 2 (CTT):       localhost:5004');
  } catch (error) {
    console.error('Failed to start services:', error);
    await manager.cleanup();
  }
}

main();
