# Remote CTT Tests with Docker Z-Wave Stack

This project provides a complete setup for running Z-Wave CTT (Certified Test Tool) tests with Linux Z-Wave binaries running in Docker on a Windows CI server.

## Overview

The setup includes:
- **Docker Container**: Runs 5 Z-Wave binaries (3 controllers + 2 end devices) in a single container
- **CTT-Remote**: Windows application for running certification tests
- **WebSocket Server**: For remote control and automation
- **Process Manager**: Coordinates all services with proper lifecycle management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Windows CI Server                        │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │ Docker Container (zwave-stack)                      │   │
│  │                                                      │   │
│  │  • Controller 1 → TCP :5000 (Z-Wave JS)            │   │
│  │  • Controller 2 → TCP :5001 (CTT SecondController) │   │
│  │  • Controller 3 → TCP :5002 (CTT ThirdController)  │   │
│  │  • End Device 1 → TCP :5003 (CTT FirstEndDevice)   │   │
│  │  • End Device 2 → TCP :5004 (CTT SecondEndDevice)  │   │
│  └────────────────────────────────────────────────────┘   │
│                          ↑                                  │
│                          │ TCP connections                  │
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

- **Docker Desktop for Windows** (with Linux containers enabled)
- **Node.js 24** or later
- **.NET Framework 4.8** (for CTT-Remote)
- **Windows 10/11** or **Windows Server**

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

### 3. Configure CTT Project for IP Devices

```bash
node update-ctt-devices.js
```

This updates the CTT project ([Project/zwave-js.cttsln](Project/zwave-js.cttsln)) to use TCP/IP devices:
- 800 series (ZW080x) chips
- Stack version 7.23
- IP addresses pointing to localhost with appropriate ports

### 4. Start All Services

```bash
npm start
```

This command will:
1. Build and start the Docker container with all Z-Wave binaries
2. Start the WebSocket server for remote control
3. Launch CTT-Remote with the configured project

### 5. Access Services

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

## Docker Management

### Manual Docker Commands

```bash
# Build the Docker image
docker-compose build

# Start container in background
docker-compose up -d

# View logs
docker-compose logs -f

# Stop container
docker-compose down

# Restart container
docker-compose restart

# Access container shell
docker exec -it zwave-stack bash
```

### Check Running Processes Inside Container

```bash
docker exec -it zwave-stack ps aux | grep ZW_zwave
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

The project includes a GitHub Actions workflow ([.github/workflows/run-ctt-remote.yml](.github/workflows/run-ctt-remote.yml)) that:

1. Sets up Node.js and .NET Framework
2. Builds the Docker container
3. Installs dependencies
4. Configures CTT project for IP devices
5. Runs the complete test suite
6. Cleans up Docker container on completion

### Manual Workflow Trigger

The workflow can be triggered manually from the GitHub Actions tab using the `workflow_dispatch` event.

## File Structure

```
remote-ctt-tests/
├── .github/
│   └── workflows/
│       └── run-ctt-remote.yml      # CI workflow
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
├── docker-compose.yml              # Docker orchestration
├── Dockerfile                      # Container definition
├── start-zwave-stack.sh           # Binary startup script
├── update-ctt-devices.js          # CTT config updater
├── DOCKER_SETUP.md                # Detailed Docker docs
└── README.md                      # This file
```

## Troubleshooting

### Docker Container Won't Start

Check if ports are already in use:

```cmd
netstat -ano | findstr :5000
netstat -ano | findstr :5001
netstat -ano | findstr :5002
netstat -ano | findstr :5003
netstat -ano | findstr :5004
```

### Can't Connect to Devices

1. Verify container is running:
   ```bash
   docker ps
   ```

2. Check container logs:
   ```bash
   docker-compose logs
   ```

3. Verify processes inside container:
   ```bash
   docker exec -it zwave-stack ps aux | grep ZW_zwave
   ```

### CTT-Remote Connection Issues

Ensure the CTT project is configured for IP devices by running:

```bash
node update-ctt-devices.js
```

## Advanced Configuration

### Custom Ports

Edit [docker-compose.yml](docker-compose.yml) to change port mappings:

```yaml
ports:
  - "YOUR_PORT:5000"
```

### RF Region

The default RF region is EU. To change it, edit the CTT project or modify the Docker startup script.

## Documentation

- **[DOCKER_SETUP.md](DOCKER_SETUP.md)** - Comprehensive Docker setup guide
- **[CTT-Remote/CTT-Remote.md](CTT-Remote/CTT-Remote.md)** - CTT-Remote API documentation

## License

MIT

## Support

For issues or questions, please open an issue in the GitHub repository.
