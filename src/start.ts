import { spawn, ChildProcess } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';
import { fileURLToPath } from 'url';
import { createWebSocketServer } from './ws-server.ts';
import type { ManagedWebSocketServer } from './ws-server.ts';
import { runTestCases } from './ctt-client.ts';
import { Driver } from 'zwave-js';
import { ZwavejsServer } from '@zwave-js/server';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 4712;
const ZWAVE_JS_SERVER_PORT = 3000;
const IS_LINUX = process.platform === 'linux';

interface ManagedProcess {
  name: string;
  process: ChildProcess;
  pid?: number;
}

interface ZWaveDevice {
  name: string;
  port: number;
  binary: string;
  storageDir: string;
}

const ZWAVE_DEVICES: ZWaveDevice[] = [
  { name: 'Controller 1 (Z-Wave JS)', port: 5000, binary: 'controller', storageDir: '/tmp/controller1' },
  { name: 'Controller 2 (CTT)', port: 5001, binary: 'controller', storageDir: '/tmp/controller2' },
  { name: 'Controller 3 (CTT)', port: 5002, binary: 'controller', storageDir: '/tmp/controller3' },
  { name: 'End Device 1 (CTT)', port: 5003, binary: 'end_device', storageDir: '/tmp/enddevice1' },
  { name: 'End Device 2 (CTT)', port: 5004, binary: 'end_device', storageDir: '/tmp/enddevice2' },
];

class ProcessManager {
  private processes: ManagedProcess[] = [];
  private wsServer?: ManagedWebSocketServer;
  private zwaveDriver?: Driver;
  private zwaveServer?: ZwavejsServer;

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

  startZWaveStackNative(): void {
    console.log('Starting Z-Wave stack natively on Linux...');

    const zwaveStackDir = path.join(__dirname, '..', 'zwave_stack');
    const controllerBinary = 'ZW_zwave_ncp_serial_api_controller_25_9_0_x86_REALTIME_DEBUG.elf';
    const endDeviceBinary = 'ZW_zwave_ncp_serial_api_end_device_25_9_0_x86_REALTIME_DEBUG.elf';

    for (const device of ZWAVE_DEVICES) {
      const binaryName = device.binary === 'controller' ? controllerBinary : endDeviceBinary;
      const binaryPath = path.join(zwaveStackDir, binaryName);

      console.log(`Starting ${device.name} on port ${device.port}...`);

      const proc = spawn(binaryPath, [
        '--port', device.port.toString(),
        '--storage', device.storageDir
      ], {
        cwd: zwaveStackDir,
        stdio: 'pipe'
      });

      proc.stdout?.on('data', (data) => {
        console.log(`[${device.name}] ${data.toString().trim()}`);
      });

      proc.stderr?.on('data', (data) => {
        console.error(`[${device.name}] ${data.toString().trim()}`);
      });

      proc.on('error', (error) => {
        console.error(`Failed to start ${device.name}:`, error);
      });

      proc.on('exit', (code) => {
        console.log(`${device.name} exited with code ${code}`);
      });

      this.processes.push({
        name: device.name,
        process: proc,
        pid: proc.pid
      });
    }

    console.log('All Z-Wave devices started natively');
  }

  stopZWaveStackNative(): void {
    console.log('Stopping Z-Wave stack processes...');
    // Processes are stopped in the main cleanup loop
  }

  async startZWaveJSServer(): Promise<void> {
    console.log('Starting Z-Wave JS driver and server...');

    const cacheDir = path.join(__dirname, '..', '.zwave-js-cache');
    fs.mkdirSync(cacheDir, { recursive: true });

    // Connect to the simulated controller via TCP
    this.zwaveDriver = new Driver('tcp://127.0.0.1:5000', {
      storage: {
        cacheDir,
      },
      logConfig: {
        enabled: true,
        level: 'warn',
      },
    });

    // Wait for driver to be ready
    await new Promise<void>((resolve, reject) => {
      this.zwaveDriver!.once('driver ready', () => {
        console.log('Z-Wave JS driver is ready');
        resolve();
      });

      this.zwaveDriver!.once('error', (error) => {
        console.error('Z-Wave JS driver error:', error);
        reject(error);
      });

      this.zwaveDriver!.start().catch(reject);
    });

    // Start the Z-Wave JS WebSocket server
    this.zwaveServer = new ZwavejsServer(this.zwaveDriver!, {
      port: ZWAVE_JS_SERVER_PORT,
    });

    await this.zwaveServer.start();
    console.log(`Z-Wave JS server listening on port ${ZWAVE_JS_SERVER_PORT}`);
  }

  async stopZWaveJSServer(): Promise<void> {
    if (this.zwaveServer) {
      console.log('Stopping Z-Wave JS server...');
      await this.zwaveServer.destroy();
    }
    if (this.zwaveDriver) {
      console.log('Stopping Z-Wave JS driver...');
      await this.zwaveDriver.destroy();
    }
  }

  setupWineAppData(): void {
    console.log('Setting up Wine AppData for CTT...');

    const homeDir = os.homedir();
    const winePrefix = process.env.WINEPREFIX || path.join(homeDir, '.wine');
    const dosdevices = path.join(winePrefix, 'dosdevices');
    const wineAppDataRoaming = path.join(winePrefix, 'drive_c', 'users', os.userInfo().username, 'AppData', 'Roaming');
    const wineZWaveAlliance = path.join(wineAppDataRoaming, 'Z-Wave Alliance');
    const repoAppData = path.join(__dirname, '..', 'appdata');
    const repoRoot = path.join(__dirname, '..');

    // Remove Z: drive mapping to prevent Wine from accessing Linux root filesystem
    // This avoids errors like "Z:\home\runner\..." path access issues
    const zDriveLink = path.join(dosdevices, 'z:');
    try {
      fs.unlinkSync(zDriveLink);
      console.log('Removed Z: drive mapping');
    } catch (err: unknown) {
      if ((err as NodeJS.ErrnoException).code !== 'ENOENT') {
        console.warn('Could not remove Z: drive:', err);
      }
    }

    // Map the repository to X: drive so CTT-Remote can access it via Windows paths
    const xDriveLink = path.join(dosdevices, 'x:');
    try {
      fs.unlinkSync(xDriveLink);
    } catch {
      // Ignore if doesn't exist
    }
    fs.symlinkSync(repoRoot, xDriveLink);
    console.log(`Mapped X: drive to ${repoRoot}`);

    // Ensure Wine AppData/Roaming directory exists
    fs.mkdirSync(wineAppDataRoaming, { recursive: true });

    // Check if symlink or folder already exists
    // Note: Use lstatSync to detect broken symlinks (existsSync returns false for them)
    try {
      const stats = fs.lstatSync(wineZWaveAlliance);
      if (stats.isSymbolicLink()) {
        const target = fs.readlinkSync(wineZWaveAlliance);
        if (target === repoAppData) {
          console.log('Symlink already exists and points to correct location');
          return;
        }
        fs.unlinkSync(wineZWaveAlliance);
        console.log('Removed existing symlink (wrong target)');
      } else {
        fs.rmSync(wineZWaveAlliance, { recursive: true });
        console.log('Removed existing Z-Wave Alliance folder');
      }
    } catch (err: unknown) {
      // ENOENT means path doesn't exist, which is fine
      if ((err as NodeJS.ErrnoException).code !== 'ENOENT') {
        throw err;
      }
    }

    // Create symlink from Wine's Z-Wave Alliance to repo's appdata
    fs.symlinkSync(repoAppData, wineZWaveAlliance, 'dir');
    console.log(`Created symlink: ${wineZWaveAlliance} -> ${repoAppData}`);

    // Create Program Files folders that CTT might try to access
    const programFiles = path.join(winePrefix, 'drive_c', 'Program Files');
    const programFilesX86 = path.join(winePrefix, 'drive_c', 'Program Files (x86)');
    fs.mkdirSync(programFiles, { recursive: true });
    fs.mkdirSync(programFilesX86, { recursive: true });
    console.log('Ensured Program Files directories exist');

    // CTT-Remote tries to access %ProgramW6432% as a literal path when env var isn't expanded
    // Create empty folders to prevent crashes
    const cttRemoteDir = path.join(__dirname, '..', 'CTT-Remote');
    const literalProgramW6432 = path.join(cttRemoteDir, '%ProgramW6432%');
    const literalProgramFilesX86 = path.join(cttRemoteDir, '%ProgramFiles(x86)%');
    fs.mkdirSync(literalProgramW6432, { recursive: true });
    fs.mkdirSync(literalProgramFilesX86, { recursive: true });
    console.log('Created fallback folders for unexpanded env vars');
  }

  startCTTRemote(): ManagedProcess {
    const cttRemotePath = path.join(__dirname, '..', 'CTT-Remote', 'CTT-Remote.exe');
    const solutionPath = path.join(__dirname, '..', 'Project', 'zwave-js.cttsln');

    console.log(`Starting CTT-Remote: ${cttRemotePath} ${solutionPath}`);

    let cttProcess: ChildProcess;

    if (IS_LINUX) {
      // On Linux, use Wine to run the Windows executable
      // Use Windows-style paths via X: drive mapping
      console.log('Using Wine to run CTT-Remote on Linux...');
      const wineCttRemotePath = 'X:\\CTT-Remote\\CTT-Remote.exe';
      const wineSolutionPath = 'X:\\Project\\zwave-js.cttsln';

      cttProcess = spawn('wine', [wineCttRemotePath, wineSolutionPath], {
        cwd: path.join(__dirname, '..', 'CTT-Remote'),
        stdio: 'inherit',
        env: {
          ...process.env,
          WINEDEBUG: '-all',  // Suppress Wine debug messages
          // Set Windows environment variables with Windows-style paths
          ProgramW6432: 'C:\\Program Files',
          'ProgramFiles(x86)': 'C:\\Program Files (x86)',
          ProgramFiles: 'C:\\Program Files',
        }
      });
    } else {
      // On Windows, run directly
      cttProcess = spawn(cttRemotePath, [solutionPath], {
        cwd: path.join(__dirname, '..', 'CTT-Remote'),
        stdio: 'inherit',
        windowsHide: true
      });
    }

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
      onFatalError: () => this.cleanup(),
      onProjectLoaded: () => {
        console.log('\n✓ Project loaded successfully!');
        console.log('Waiting 5 seconds before running test...\n');

        // Wait 5 seconds then run the test
        setTimeout(async () => {
          try {
            console.log('\n--- Running test case AGD_AssociationGroupData_Rev01 ---');
            const result = await runTestCases({
              testCaseNames: ['AGD_AssociationGroupData_Rev01'],
              endPointIds: [0],
              ZWaveExecutionModes: ['Classic'],
            });
            console.log('Test started:', result);
          } catch (error) {
            console.error('Failed to run test case:', error);
          }
        }, 5000);
      }
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

    // Stop Z-Wave JS server and driver
    await this.stopZWaveJSServer();

    // Kill all managed processes
    for (const managedProcess of this.processes) {
      this.killProcess(managedProcess);
    }

    // Close WebSocket server
    if (this.wsServer) {
      await this.wsServer.close();
    }

    // Stop Docker container (only on Windows where we use Docker)
    if (!IS_LINUX) {
      await this.stopDockerContainer();
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
async function main() {
  const manager = new ProcessManager();
  manager.setupExitHandlers();

  try {
    if (IS_LINUX) {
      // On Linux, run Z-Wave stack natively
      console.log('Running on Linux - using native Z-Wave binaries');
      manager.startZWaveStackNative();
    } else {
      // On Windows, use Docker for Z-Wave stack
      console.log('Running on Windows - using Docker for Z-Wave stack');
      await manager.startDockerContainer();
    }

    // Give Z-Wave devices a moment to fully initialize
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Start Z-Wave JS driver and server (connects to simulated controller on port 5000)
    await manager.startZWaveJSServer();

    // Start WebSocket server for CTT communication
    manager.startWebSocketServer();

    // Setup Wine AppData before starting CTT-Remote on Linux
    if (IS_LINUX) {
      manager.setupWineAppData();
    }

    // Start CTT-Remote
    manager.startCTTRemote();

    console.log('\nAll services started successfully!');
    console.log('Z-Wave devices available at:');
    console.log('  Controller 1 (Z-Wave JS): localhost:5000');
    console.log('  Controller 2 (CTT):       localhost:5001');
    console.log('  Controller 3 (CTT):       localhost:5002');
    console.log('  End Device 1 (CTT):       localhost:5003');
    console.log('  End Device 2 (CTT):       localhost:5004');
    console.log(`  Z-Wave JS Server:         ws://localhost:${ZWAVE_JS_SERVER_PORT}`);
  } catch (error) {
    console.error('Failed to start services:', error);
    await manager.cleanup();
  }
}

main();
