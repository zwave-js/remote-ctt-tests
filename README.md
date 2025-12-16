# Automation of Z-Wave Certification Tests

This project provides a complete framework for running Z-Wave CTT certification tests against a Controller DUT with device emulation based on the "Open Source" Z-Wave stack.

## Prerequisites

As long as CTT-Remote does not run on Linux, we use WSL (Windows Subsystem for Linux) to run the Z-Wave stack binaries in a Linux environment while controlling them from Windows.

- **Windows 10/11** or **Windows Server**
- **WSL with Ubuntu** installed
- **.NET Framework 4.8** (for CTT-Remote)

In addition, the test orchestrator requires:

- **Node.js 24** or later
- The `gh` CLI tool for downloading the Z-Wave stack binaries from GitHub and authentication


## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Windows (Local or CI)                   │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ WSL (Ubuntu) - CTT Devices                         │  │
│  │                                                    │  │
│  │  • Controller 2 → TCP :5001 (CTT Controller1)      │  │
│  │  • Controller 3 → TCP :5002 (CTT Controller3)      │  │
│  │  • End Device 1 → TCP :5003 (CTT EndDevice1)       │  │
│  │  • End Device 2 → TCP :5004 (CTT EndDevice2)       │  │
│  │  • Zniffer      → TCP :4905 (CTT Zniffer)          │  │
│  └────────────────────────────────────────────────────┘  │
│                          ↑                               │
│  ┌────────────────────────────────────────────────────┐  │
│  │ CTT-Remote.exe                                     │  │
│  │ Connects to controllers/devices on ports 5001-5004 │  │
│  └────────────────────────────────────────────────────┘  │
│                          ↑                               │
│                    WebSocket :4712                       │
│                          ↓                               │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Orchestrator                                       │  │
│  │ Controls test execution and coordinates components │  │
│  └────────────────────────────────────────────────────┘  │
│                          ↑                               │
│                    WebSocket :4713                       │
│                          ↓                               │
│  ┌────────────────────────────────────────────────────┐  │
│  │ DUT Runner                                         │  │
│  │ Manages DUT lifecycle and handles CTT prompts      │  │
│  │ Controls DUT device                                │  │
│  └────────────────────────────────────────────────────┘  │
│                          ↓                               │
│  ┌────────────────────────────────────────────────────┐  │
│  │ WSL (Ubuntu) - DUT Device                          │  │
│  │                                                    │  │
│  │  • Controller 1 → TCP :5000 (DUT)                  │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## Installation

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
```

These commands:
- Enable 32-bit architecture support
- Install 32-bit C/C++ libraries required by the Z-Wave binaries
- Make the Z-Wave binaries executable


## Getting Started

### Step 1: Install CTT

CTT is not included in this repository. You need to install it separately. It will later be bundled so it can be used in CI.
If the location differs from the default install location, set the `CTT_PATH` environment variable.

### Step 2: Download Z-Wave Stack

```bash
powershell .\setup\download-zwave-stack.ps1
```

> **Note:** This setup assumes the DUT is a **controller**, which connects to the emulated controller on port 5000. Testing sample applications (end devices) should also be possible but requires copying additional files from the stack binaries, and updating the `zwave_stack/run.sh` script accordingly.

### Step 3: Run Emulated Devices

```bash
npm run devices
```

Starts 6 Z-Wave binaries in WSL:

| Device | Port | Purpose |
|--------|------|---------|
| Controller 1 | 5000 | **Your DUT connects here** |
| Controller 2 | 5001 | CTT |
| Controller 3 | 5002 | CTT |
| End Device 1 | 5003 | CTT |
| End Device 2 | 5004 | CTT |
| Zniffer | 4905 | CTT packet capture |

These can now be used to set up the CTT project.

### Step 4: Configure CTT Project

1. Create a new project in CTT GUI
2. Set up 5 IP-based devices:
   - 2x Controller: `127.0.0.1:5001` and `:5002`
   - 2x End Device: `127.0.0.1:5003` and `:5004`
   - 1x Zniffer: `127.0.0.1:4905`

### Step 5: Set Up CTT Network with DUT

Configure DUT to connect to `tcp://127.0.0.1:5000`, then establish the test network:

- **Option A:** DUT includes CTT devices into its network
- **Option B:** CTT includes DUT into its network

To test both scenarios, you'll need separate CTT projects.

Make sure to finish creation of the network, including the query for DUT capabilities.

### Step 6: Copy CTT Project Files

Copy from CTT's project folder to `ctt/project/`:

```
ctt/project/
├── Config/                            # All config files
├── json/                              # JSON configurations
├── <your-project>.cttsln                    # Project file
└── ZWave_CTT_CommandClasses.cttxml    # Command classes definition
```

### Step 7: Create DUT Runner Script

Implement the IPC protocol (JSON-RPC 2.0 over WebSocket):

- Connect to port 4713 (or `RUNNER_IPC_PORT` env var)
- Required methods:
  - `ready` notification (on connect)
  - `start` (initialize DUT with controllerUrl and security keys)
  - `stop` (shutdown DUT)
  - `handleCttPrompt` (respond to CTT prompts)

See [dut/zwave-js/run.ts](dut/zwave-js/run.ts) for a reference implementation and [docs/ipc-protocol.md](docs/ipc-protocol.md) for the full protocol specification.

### Step 8: Update config.json

```json
{
  "dut": {
    "name": "Your DUT Name",
    "runnerPath": "your-dut/run.ts",
    "homeId": "e6d68af7",
    "storageDir": "your-dut/storage",
    "storageFileFilter": ["%HOME_ID_LOWER%.jsonl"]
  }
}
```

**Field explanations:**

- `runnerPath`: Path to your DUT runner script. Supports Node.js (TypeScript/JavaScript), Python, or any executable that your system can handle running directly, e.g. with a shebang.
- `homeId`: Must match the Home ID of your test network (from CTT setup)
- `storageDir` / `storageFileFilter`: Used to transfer DUT network state to GitHub for automated CI testing. The filter patterns support placeholders:
  - `%HOME_ID_LOWER%` - homeId in lowercase
  - `%HOME_ID_UPPER%` - homeId in uppercase

### Step 9: Pack Archives

```bash
powershell .\setup\pack-ctt-archive.ps1
powershell .\setup\pack-network-state-archive.ps1
```

Both archives are required for CI/automated testing. They will need to be regenerated if the CTT setup or project changes.

- **ctt-setup.zip**: Contains CTT (closed-source, vendored) keys, appdata, and configuration
- **network-state.zip**: Contains network state for emulated Z-Wave devices and DUT storage

### Step 10: Git Commit

**Check in:**

- `config.json`
- DUT runner script (`your-dut/run.ts`)
- CTT project files (`ctt/project/`)
- Setup archives (`setup/ctt-setup.zip`, `setup/network-state.zip`)

**Update .gitignore:**

The default `.gitignore` excludes common paths, but may need modifications depending on how your DUT stores state. 
Add exclusions for your DUT's storage directory (e.g., `your-dut/storage/`). This should be included in the `network-state.zip` archive instead.

## Testing and CI/CD

To test locally, run:

```bash
npm run start -- [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--discover` | List all available test cases grouped by category |
| `--test=<name>` | Run a specific test by name |
| `--test=<n1>,<n2>` | Run multiple tests (comma-separated) |
| `--category=<cat>` | Run all tests in a category (partial match, case-insensitive) |
| `--category=<c1>,<c2>` | Run tests from multiple categories |
| `--group=<grp>` | Run tests in a group (`Automatic` or `Interactive`) |
| `--group=<g1>,<g2>` | Run tests from multiple groups |
| `--dut=<path>` | Path to DUT runner (defaults to `config.json` runner path) |
| `--devices-only` | Only start emulated Z-Wave devices, without CTT or the DUT runner |
| `--verbose` | Show CTT-Remote log output |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CTT_PATH` | `C:\Program Files (x86)\Z-Wave Alliance\Z-Wave CTT 3` | Path to CTT installation |

### Examples

```bash
# List all available tests
npm run start -- --discover

# Run a single test
npm run start -- --test=CC_Binary_Switch_Set

# Run multiple specific tests
npm run start -- --test=CC_Binary_Switch_Set,CC_Binary_Switch_Get

# Run all automatic tests (for CI)
npm run start -- --group=Automatic

# Run all tests in a category
npm run start -- --category=Binary

# Combine filters (category AND group)
npm run start -- --category=Binary --group=Automatic

# Start only the emulated devices (for manual testing)
npm run start -- --devices-only

# Run with verbose CTT output
npm run start -- --test=CC_Binary_Switch_Set --verbose
```

The project comes with a ready-to-use GitHub Actions workflow for running CTT tests in CI using WSL. For now, only tests from the "Automatic" group are supported, because they don't require manual interaction.

To use the workflow, configure a repository secret named `ZW_STACK_TOKEN` with a GitHub PAT that has **Contents: read** permission for the [Z-Wave-Alliance/z-wave-stack-binaries](https://github.com/Z-Wave-Alliance/z-wave-stack-binaries) repository.

## Documentation

- **[docs/ipc-protocol.md](docs/ipc-protocol.md)** - DUT Runner IPC protocol specification
- **[CTT-Remote/CTT-Remote.md](CTT-Remote/CTT-Remote.md)** - CTT-Remote API documentation
- **[.github/workflows/run-zwave-wsl.yml](.github/workflows/run-zwave-wsl.yml)** - CI workflow configuration

## License

MIT

## Support

For issues or questions, please open an issue in the GitHub repository.
