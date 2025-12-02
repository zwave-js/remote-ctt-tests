# Remote CTT Tests with WSL Z-Wave Stack

This project provides a complete setup for running Z-Wave CTT (Certified Test Tool) tests with Linux Z-Wave binaries running in WSL (Windows Subsystem for Linux) on Windows.

## Overview

The setup includes:
- **WSL**: Runs 5 Z-Wave binaries (3 controllers + 2 end devices) using Ubuntu on WSL
- **CTT-Remote**: Windows application for running certification tests
- **WebSocket Server**: For remote control and automation
- **Process Manager**: Coordinates all services with proper lifecycle management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Windows (Local or CI)                    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │ WSL (Ubuntu)                                        │   │
│  │                                                      │   │
│  │  • Controller 1 → TCP :5000 (Z-Wave JS)            │   │
│  │  • Controller 2 → TCP :5001 (CTT SecondController) │   │
│  │  • Controller 3 → TCP :5002 (CTT ThirdController)  │   │
│  │  • End Device 1 → TCP :5003 (CTT FirstEndDevice)   │   │
│  │  • End Device 2 → TCP :5004 (CTT SecondEndDevice)  │   │
│  └────────────────────────────────────────────────────┘   │
│                          ↑                                  │
│         Ports automatically forwarded to Windows            │
│                          ↓                                  │
│  ┌────────────────────────────────────────────────────┐   │
│  │ CTT-Remote.exe                                      │   │
│  │ Connects to controllers/devices on ports 5001-5004 │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │ WebSocket Server (:4712)                            │   │
│  │ Provides remote control interface                   │   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Windows 10/11** or **Windows Server**
- **WSL with Ubuntu** installed
- **Node.js 24** or later
- **.NET Framework 4.8** (for CTT-Remote)

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd remote-ctt-tests
```

### 2. Install Dependencies

```bash
npm install
```

### 3. One-Time WSL Setup

Run these commands in WSL (open WSL terminal with `wsl`):

```bash
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y libc6:i386 libstdc++6:i386
chmod +x zwave_stack/*.elf
```

These commands:
- Enable 32-bit architecture support
- Install 32-bit C/C++ libraries required by the Z-Wave binaries
- Make the Z-Wave binaries executable

### 4. Configure CTT Project for IP Devices

```bash
node update-ctt-devices.js
```

This updates the CTT project ([Project/zwave-js.cttsln](Project/zwave-js.cttsln)) to use TCP/IP devices:
- 800 series (ZW080x) chips
- Stack version 7.23
- IP addresses pointing to localhost with appropriate ports

### 5. Start All Services

```bash
npm start
```

This command will:
1. Start the Z-Wave stack in WSL with all 5 binaries
2. Start the WebSocket server for remote control
3. Launch CTT-Remote with the configured project

**Note**: Ports are automatically forwarded from WSL to Windows, so all services are accessible on `localhost`.

### 6. Access Services

- **Z-Wave Controller 1** (for Z-Wave JS): `localhost:5000`
- **Z-Wave Controller 2** (for CTT): `localhost:5001`
- **Z-Wave Controller 3** (for CTT): `localhost:5002`
- **End Device 1** (for CTT): `localhost:5003`
- **End Device 2** (for CTT): `localhost:5004`
- **WebSocket Server**: `ws://localhost:4712`

## Device Configuration

### CTT Configuration

The CTT project is configured with:

```json
{
  "FirstController": {
    "SName": "localhost",
    "SPort": 5001,
    "SType": "TCP",
    "ChipSeries": "ZW080x",
    "VersionNumbers": "7.23"
  },
  "ThirdController": {
    "SName": "localhost",
    "SPort": 5002,
    "SType": "TCP",
    "ChipSeries": "ZW080x",
    "VersionNumbers": "7.23"
  },
  "FirstEndDevice": {
    "SName": "localhost",
    "SPort": 5003,
    "SType": "TCP",
    "ChipSeries": "ZW080x",
    "VersionNumbers": "7.23"
  },
  "SecondEndDevice": {
    "SName": "localhost",
    "SPort": 5004,
    "SType": "TCP",
    "ChipSeries": "ZW080x",
    "VersionNumbers": "7.23"
  }
}
```

### Z-Wave JS Configuration

To connect Z-Wave JS to the first controller:

```typescript
const serialPort = 'tcp://localhost:5000';
```

## WSL Management

### Check Running Z-Wave Processes in WSL

```bash
wsl ps aux | grep ZW_zwave
```

### Access WSL Shell

```bash
wsl
```

### Stop All Z-Wave Processes

Stop the `npm start` process with Ctrl+C. If processes are still running in WSL:

```bash
wsl pkill -f "ZW_zwave"
```

## Testing

### Test TCP Connections

```powershell
# Test each port
Test-NetConnection -ComputerName localhost -Port 5000
Test-NetConnection -ComputerName localhost -Port 5001
Test-NetConnection -ComputerName localhost -Port 5002
Test-NetConnection -ComputerName localhost -Port 5003
Test-NetConnection -ComputerName localhost -Port 5004
```

### Test with Telnet

```cmd
telnet localhost 5000
```

## CI/CD Integration

The project includes a GitHub Actions workflow ([.github/workflows/run-zwave-wsl.yml](.github/workflows/run-zwave-wsl.yml)) that:

1. Sets up WSL with Ubuntu
2. Installs 32-bit libraries in WSL
3. Starts the Z-Wave stack in WSL
4. Verifies port connectivity from Windows to WSL

The local and CI environments are identical - both use WSL to run the Z-Wave binaries.

### Manual Workflow Trigger

The workflow can be triggered manually from the GitHub Actions tab using the `workflow_dispatch` event.

## File Structure

```
remote-ctt-tests/
├── .github/
│   └── workflows/
│       └── run-zwave-wsl.yml       # CI workflow (uses WSL)
├── CTT-Remote/
│   ├── CTT-Remote.exe              # Test tool executable
│   └── CTT-Remote.md               # Documentation
├── Project/
│   └── zwave-js.cttsln             # CTT project file
├── src/
│   ├── start.ts                    # Process manager
│   └── ws-server.ts                # WebSocket server
├── zwave_stack/
│   ├── ZW_zwave_ncp_serial_api_controller_*.elf  # Controller binaries
│   └── ZW_zwave_ncp_serial_api_end_device_*.elf  # End device binaries
├── start-zwave-stack.sh            # Binary startup script (runs in WSL)
├── update-ctt-devices.js           # CTT config updater
└── README.md                       # This file
```

## Troubleshooting

### WSL Z-Wave Stack Won't Start

1. Verify WSL is running:
   ```cmd
   wsl --status
   ```

2. Check if 32-bit libraries are installed in WSL:
   ```bash
   wsl dpkg --print-foreign-architectures
   ```
   Should output: `i386`

3. Verify binaries are executable:
   ```bash
   wsl ls -la zwave_stack/*.elf
   ```

### Ports Already in Use

Check if ports are already in use:

```cmd
netstat -ano | findstr :5000
netstat -ano | findstr :5001
netstat -ano | findstr :5002
netstat -ano | findstr :5003
netstat -ano | findstr :5004
```

If processes are running, stop them:
```bash
wsl pkill -f "ZW_zwave"
```

### Can't Connect to Devices

1. Verify Z-Wave processes are running in WSL:
   ```bash
   wsl ps aux | grep ZW_zwave
   ```

2. Check if ports are listening in WSL:
   ```bash
   wsl ss -tlnp | grep -E "500[0-4]"
   ```

3. Test connectivity from Windows:
   ```powershell
   Test-NetConnection -ComputerName localhost -Port 5000
   ```

### CTT-Remote Connection Issues

Ensure the CTT project is configured for IP devices by running:

```bash
node update-ctt-devices.js
```

## Advanced Configuration

### Custom Ports

Edit [start-zwave-stack.sh](start-zwave-stack.sh) to change the ports used by the Z-Wave binaries.

### RF Region

The default RF region is EU. To change it, edit the CTT project configuration.

## Documentation

- **[CTT-Remote/CTT-Remote.md](CTT-Remote/CTT-Remote.md)** - CTT-Remote API documentation
- **[.github/workflows/run-zwave-wsl.yml](.github/workflows/run-zwave-wsl.yml)** - CI workflow configuration

## License

MIT

## Support

For issues or questions, please open an issue in the GitHub repository.
