# Automation of Z-Wave Certification Tests

This project provides a complete framework for running Z-Wave CTT certification tests against a Controller DUT with device emulation based on the "Open Source" Z-Wave stack. It runs natively on Linux, both locally and in CI.

## Prerequisites

- **Linux** (Windows contributors can use WSL2)
- **Node.js 24** or later
- **.NET 10 runtime** — required by CTT Remote 4, not bundled:
  ```bash
  sudo apt-get install -y dotnet-runtime-10.0
  ```
- **32-bit libraries** — the Z-Wave stack `.elf` binaries are 32-bit x86:
  ```bash
  sudo dpkg --add-architecture i386
  sudo apt-get update
  sudo apt-get install -y libc6:i386 libstdc++6:i386
  ```
- **python3** — used by the Zniffer simulator
- The **`gh` CLI**, authenticated, for downloading the Z-Wave stack binaries and
  the CTT package from GitHub

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      Linux (Local or CI)                  │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ Emulated Z-Wave devices (native .elf + python3)     │ │
│  │                                                     │ │
│  │  • Controller 2 → TCP :5001 (CTT Controller2)       │ │
│  │  • Controller 3 → TCP :5002 (CTT Controller3)       │ │
│  │  • End Device 1 → TCP :5003 (CTT EndDevice1)        │ │
│  │  • End Device 2 → TCP :5004 (CTT EndDevice2)        │ │
│  │  • Zniffer      → TCP :4905 (CTT Zniffer)           │ │
│  └─────────────────────────────────────────────────────┘ │
│                          ↑                                │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ ZWaveCTT (CTT Remote 4, .NET 10)                    │ │
│  │ Connects to controllers/devices on ports 5001-5004  │ │
│  │ Serves JSON-RPC on :4711                             │ │
│  └─────────────────────────────────────────────────────┘ │
│                          ↑                                │
│                    WebSocket :4712                        │
│                          ↓                                │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ Orchestrator (src/start.ts)                         │ │
│  │ Controls test execution and coordinates components   │ │
│  └─────────────────────────────────────────────────────┘ │
│                          ↑                                │
│                    WebSocket :4713 (IPC)                  │
│                          ↓                                │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ DUT Runner                                          │ │
│  │ Manages DUT lifecycle and handles CTT prompts        │ │
│  │  • Controller 1 → TCP :5000 (DUT)                   │ │
│  └─────────────────────────────────────────────────────┘ │
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
npm --prefix dut/zwave-js install   # DUT runner dependencies
```

### 3. Install Prerequisites

Install the .NET 10 runtime, the 32-bit libraries, and `python3` as described in
[Prerequisites](#prerequisites).

## Getting Started

### Step 1: Download the Z-Wave stack and CTT

```bash
npm run setup
```

This downloads and unpacks the Z-Wave stack binaries (from
[Z-Wave-Alliance/z-wave-stack-binaries](https://github.com/Z-Wave-Alliance/z-wave-stack-binaries))
into `zwave_stack/bin/`, the CTT package (from
[zwave-js/byoctt](https://github.com/zwave-js/byoctt)) into `ctt/bin/`, and
restores the saved network state from `setup/network-state.zip`. The individual
scripts in `setup/` can also be run directly.

> **Note:** This setup assumes the DUT is a **controller**, which connects to the emulated controller on port 5000. Testing sample applications (end devices) should also be possible but requires copying additional files from the stack binaries, and updating the `zwave_stack/run.sh` script accordingly.

### Step 2: Run Emulated Devices

```bash
npm run devices
```

Starts 6 Z-Wave binaries natively:

| Device | Port | Purpose |
|--------|------|---------|
| Controller 1 | 5000 | **Your DUT connects here** |
| Controller 2 | 5001 | CTT |
| Controller 3 | 5002 | CTT |
| End Device 1 | 5003 | CTT |
| End Device 2 | 5004 | CTT |
| Zniffer | 4905 | CTT packet capture |

These can now be used to set up the CTT project.

### Step 3: Launch CTT directly (optional)

```bash
npm run ctt   # ctt/bin/ZWaveCTT ctt/project/zwave-js.cttsln
```

CTT Remote 4 migrates the existing CTT 3 project on load.

### Step 4: Configure CTT Project

1. Create a new project in the CTT GUI ("Classic" CTT is still needed for project creation)
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
├── <your-project>.cttsln              # Project file
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
    "homeId": "d34db33f",
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

### Step 9: Pack the network-state archive

```bash
./setup/pack-network-state-archive.ts
```

This regenerates `setup/network-state.zip` (emulated-device storage + DUT
storage), which is committed and used by CI. Regenerate it whenever the network
state changes.

CTT is closed-source and must be vendored as a `ctt-setup.zip` archive. This repo
downloads it from a private GitHub repository
([zwave-js/byoctt](https://github.com/zwave-js/byoctt)) via
`download-ctt-archive.ts`; hosting your own private repo and adapting that script
is the recommended approach. Whatever the source, `unpack-ctt-archive.ts` expects
the archive to contain:

```
ctt-setup.zip
├── ctt-bin/      # the CTT Remote 4 Linux distribution: the ZWaveCTT apphost + its DLLs
└── appdata/      # optional seed for ~/.ctt4/ (e.g. a settings.json)
```

CTT reads its Linux settings from `~/.ctt4/settings.json`. The unpack script
sets `SimplicityCommanderPath` to `/usr/bin/true` when no path is configured.
The virtual test environment does not use Simplicity Commander, but ZATS scans
the filesystem for it when the setting is empty.

### Step 10: Git Commit

**Check in:**

- `config.json`
- DUT runner script (`your-dut/run.ts`)
- CTT project files (`ctt/project/`) and keys (`ctt/keys/`)
- Network state archive (`setup/network-state.zip`)

`ctt/bin/`, `zwave_stack/bin/*.elf`, and `setup/ctt-setup.zip` are downloaded at
setup time and are git-ignored.

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
| `--exclude=<name>` | Exclude tests matching name |
| `--dut=<path>` | Path to DUT runner (defaults to `config.json` runner path) |
| `--devices-only` | Only start emulated Z-Wave devices, without CTT or the DUT runner |
| `--verbose` | Show CTT log output |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CTT_PATH` | `ctt/bin` (in the repo) | Path to the CTT installation containing `ZWaveCTT` |

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

The project comes with a ready-to-use GitHub Actions workflow
([.github/workflows/run-zwave.yml](.github/workflows/run-zwave.yml)) for running
CTT tests on `ubuntu-latest`.

Configure two repository secrets, each a GitHub PAT with **Contents: read**:

- `ZW_STACK_TOKEN` — access to [Z-Wave-Alliance/z-wave-stack-binaries](https://github.com/Z-Wave-Alliance/z-wave-stack-binaries)
- `CTT_ARCHIVE_TOKEN` — access to [zwave-js/byoctt](https://github.com/zwave-js/byoctt)

## Troubleshooting

### Check what is listening / running

```bash
ss -ltnp                 # confirm ports 4711 (CTT), 4712 (orchestrator), 5000-5004, 4905
pgrep -fa ZW_zwave       # stack binaries
pgrep -fa ZWaveCTT       # CTT process
```

### Stack binary fails to start with a missing-loader / "No such file or directory" error

The `.elf` binaries are 32-bit. Verify the 32-bit libraries are installed:

```bash
ldd zwave_stack/bin/ZW_zwave_ncp_serial_api_controller.elf   # no "not found" lines
```

If anything is missing, install `libc6:i386 libstdc++6:i386` (see Prerequisites).

### CTT fails to start

Confirm the .NET 10 runtime is present (`dotnet --list-runtimes` shows
`Microsoft.NETCore.App 10.0.x`) and that `ctt/bin/ZWaveCTT` is executable.

### CTT fails with `Error - RequestNodeInfo failed!`

Make sure that the DUT has all command classes set (factory reset may be required) before joining the CTT network.

### CTT fails to communicate securely with the DUT

Make sure that:
- The DUT storage contains the correct files
- The home ID is configured correctly everywhere:
    - `config.json`
    - `ctt/project/Config/TestCaseStaticController.xml` (HomeId attribute)
    - `ctt/project/Config/Saved Items/002_<HOMEID>.xml` (filename)

### Z-Wave stack binaries frequently crash or trigger the watchdog

Something in the storage is likely corrupted. Delete all stack storage files and re-create the CTT network from scratch.
Make sure to update the home ID accordingly, see above.

## Documentation

- **[docs/ipc-protocol.md](docs/ipc-protocol.md)** - DUT Runner IPC protocol specification
- **[CTT-Remote/CTT-Remote.md](CTT-Remote/CTT-Remote.md)** - CTT-Remote API documentation
- **[.github/workflows/run-zwave.yml](.github/workflows/run-zwave.yml)** - CI workflow configuration

## License

MIT

## Support

For issues or questions, please open an issue in the GitHub repository.
