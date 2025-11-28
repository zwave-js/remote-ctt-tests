# Docker Setup for Z-Wave Stack on Windows CI

This setup allows you to run Linux Z-Wave binaries in Docker containers on Windows and connect to them via TCP from CTT-Remote or other tools.

## Prerequisites

- Docker Desktop for Windows installed and running
- Ensure Docker is configured to use Linux containers (not Windows containers)

## Architecture

The Z-Wave binaries run in TCP server mode inside Docker containers with ports exposed to Windows:

```
Linux Binary (TCP server in container) → Docker port mapping → Windows Host
```

All 5 Z-Wave binaries run in a single Docker container with the following port mappings:

- **Controller 1** (Z-Wave JS FirstController): `localhost:5000`
- **Controller 2** (CTT SecondController): `localhost:5001`
- **Controller 3** (CTT ThirdController): `localhost:5002`
- **End Device 1** (CTT FirstEndDevice): `localhost:5003`
- **End Device 2** (CTT SecondEndDevice): `localhost:5004`

## Quick Start

### 1. Build and Start Containers

```bash
docker-compose up --build
```

This will:
- Build the Docker image with 32-bit Debian Linux
- Start a single container running all 5 Z-Wave binaries (3 controllers + 2 end devices)
- Expose ports 5000-5004 for all devices
- Each binary runs in its own process within the container

### 2. Configure CTT-Remote to Use Docker Containers

In your CTT project, configure the serial devices to use TCP/IP mode. Use the `setupSerialDevices` JSON-RPC method:

```json
{
  "jsonrpc": "2.0",
  "method": "setupSerialDevices",
  "params": {
    "serialDevices": {
      "FirstController": {
        "DevType": "Controller",
        "SName": "localhost",
        "SPort": 5001,
        "SType": "TCP",
        "ChipSeries": "ZW070x",
        "Library": "ControllerBridgeLib",
        "VersionNumbers": "7.18",
        "ZnifferChipType": 0,
        "SnifferVersion": 0,
        "SnifferRevision": 0
      },
      "SecondController": null,
      "ThirdController": {
        "DevType": "Controller",
        "SName": "localhost",
        "SPort": 5002,
        "SType": "TCP",
        "ChipSeries": "ZW070x",
        "Library": "ControllerBridgeLib",
        "VersionNumbers": "7.18",
        "ZnifferChipType": 0,
        "SnifferVersion": 0,
        "SnifferRevision": 0
      },
      "FirstEndDevice": {
        "DevType": "EndDevice",
        "SName": "localhost",
        "SPort": 5003,
        "SType": "TCP",
        "ChipSeries": "ZW070x",
        "Library": "EndDeviceLib",
        "VersionNumbers": "7.18",
        "ZnifferChipType": 0,
        "SnifferVersion": 0,
        "SnifferRevision": 0
      },
      "SecondEndDevice": {
        "DevType": "EndDevice",
        "SName": "localhost",
        "SPort": 5004,
        "SType": "TCP",
        "ChipSeries": "ZW070x",
        "Library": "EndDeviceLib",
        "VersionNumbers": "7.18",
        "ZnifferChipType": 0,
        "SnifferVersion": 0,
        "SnifferRevision": 0
      },
      "RfRegion": "EU",
      "LRChannel": "Undefined"
    },
    "configureDevices": false
  },
  "id": 0
}
```

Key configuration:
- `SType: "TCP"` - Use TCP connection instead of COM port
- `SName: "localhost"` - Connect to Docker container on localhost
- `SPort: 5001, 5002` - Port numbers for CTT controllers
- `SPort: 5003, 5004` - Port numbers for CTT end devices
- `SecondController: null` - Not used by CTT (reserved for Z-Wave JS)

### 3. Configure Z-Wave JS to Use Controller 1

For Z-Wave JS, connect to `localhost:5000` (FirstController in the Docker setup). This controller is dedicated for Z-Wave JS use.

## Managing Containers

### Start containers (detached mode)

```bash
docker-compose up -d
```

### Stop containers

```bash
docker-compose down
```

### View logs

```bash
# All containers
docker-compose logs -f

# Specific container
docker-compose logs -f zwave-controller-1
docker-compose logs -f zwave-controller-2
docker-compose logs -f zwave-end-device-1
```

### Restart the container

```bash
docker-compose restart
```

## Advanced Usage

### Custom Port Mapping

Edit [docker-compose.yml](docker-compose.yml) to change port mappings:

```yaml
ports:
  - "YOUR_PORT:5000"  # Change YOUR_PORT to desired Windows port
```

### Interactive Shell Access

To access the container's shell:

```bash
docker exec -it zwave-stack bash
```

Once inside, you can check running processes:

```bash
ps aux | grep ZW_zwave
```

### Testing TCP Connection

You can test the connection using telnet or PowerShell:

```bash
# Test from Windows
telnet localhost 5000  # Controller 1 (Z-Wave JS)
telnet localhost 5001  # Controller 2 (CTT)
telnet localhost 5002  # Controller 3 (CTT)
telnet localhost 5003  # End Device 1 (CTT)
telnet localhost 5004  # End Device 2 (CTT)

# Or using PowerShell
Test-NetConnection -ComputerName localhost -Port 5000
Test-NetConnection -ComputerName localhost -Port 5001
Test-NetConnection -ComputerName localhost -Port 5002
Test-NetConnection -ComputerName localhost -Port 5003
Test-NetConnection -ComputerName localhost -Port 5004
```

## CI/CD Integration

### GitHub Actions Example

```yaml
jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Start Z-Wave containers
        run: docker-compose up -d

      - name: Wait for containers to be ready
        run: |
          Start-Sleep -Seconds 5
          docker ps

      - name: Run tests
        run: npm test

      - name: Stop containers
        if: always()
        run: docker-compose down
```

## Troubleshooting

### Container won't start

Check if ports are already in use:

```cmd
netstat -ano | findstr :5000
netstat -ano | findstr :5001
netstat -ano | findstr :5002
netstat -ano | findstr :5003
netstat -ano | findstr :5004
```

### Can't connect to TCP port

1. Verify containers are running:
   ```bash
   docker ps
   ```

2. Check container logs:
   ```bash
   docker-compose logs
   ```

3. Verify port is accessible:
   ```powershell
   Test-NetConnection -ComputerName localhost -Port 5000
   ```

### Binary crashes immediately

Check the logs for errors:
```bash
docker-compose logs -f
```

Common issues:
- Missing shared libraries (check with `docker exec -it zwave-stack ldd /app/*.elf`)
- Port already in use (check with `netstat -ano | findstr :5000`)
- Binary failed to start in TCP mode (check logs with `docker-compose logs`)
- Processes not running (check with `docker exec -it zwave-stack ps aux | grep ZW_zwave`)

## Network Access from Other Machines

To access the PTY ports from other machines on your network:

1. Update [docker-compose.yml](docker-compose.yml) to bind to all interfaces:
   ```yaml
   ports:
     - "0.0.0.0:5000:5000"
   ```

2. Connect from remote machine:
   ```cmd
   telnet <windows-ci-server-ip> 5000
   ```

3. Ensure Windows Firewall allows incoming connections on these ports.

## Binary Command-Line Options

The Z-Wave binaries support the following options:

```
  -d, --debug                Don't fork process
  -f, --fifo                 Use FIFO based communication
  -i, --id=ID                Use routed ZNE with ID
  -m, --tmp-path=PATH        Node TMP path
  -p, --port=PORT            Port for TCP server mode of UART module
  -r, --region=REGION        Radio region
  -s, --storage=PATH         Storage PATH
  -t, --pty                  Use PTY mode of UART module
  -z, --zne-port=PORT        Port for routed ZNE
```

This setup uses `--port` to run in TCP server mode.

## Files Created

- [Dockerfile](Dockerfile) - Container definition for 32-bit Debian with required dependencies
- [docker-compose.yml](docker-compose.yml) - Single container orchestration with all 5 devices
- [start-zwave-stack.sh](start-zwave-stack.sh) - Startup script that launches all 5 binaries
