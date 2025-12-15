#!/bin/bash
# Start all Z-Wave binaries in the background

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
STORAGE_DIR="$SCRIPT_DIR/storage"

echo "Starting Z-Wave Stack from $SCRIPT_DIR..."

# Helper function to prefix output with process name
run_with_prefix() {
  local prefix="$1"
  shift
  "$@" 2>&1 | sed -u "s/^/[$prefix] /"
}

# Start 3 controllers
echo "Starting Controller 1 (Z-Wave JS) on port 5000..."
run_with_prefix "Controller1" "$BIN_DIR/ZW_zwave_ncp_serial_api_controller.elf" --port 5000 --storage "$STORAGE_DIR/controller1" &

echo "Starting Controller 2 (CTT) on port 6001..."
run_with_prefix "Controller2" "$BIN_DIR/ZW_zwave_ncp_serial_api_controller.elf" --port 6001 --storage "$STORAGE_DIR/controller2" &

echo "Starting Controller 3 (CTT) on port 6002..."
run_with_prefix "Controller3" "$BIN_DIR/ZW_zwave_ncp_serial_api_controller.elf" --port 6002 --storage "$STORAGE_DIR/controller3" &

# Start 2 end devices
echo "Starting End Device 1 on port 6003..."
run_with_prefix "EndDevice1" "$BIN_DIR/ZW_zwave_ncp_serial_api_end_device.elf" --port 6003 --storage "$STORAGE_DIR/enddevice1" &

echo "Starting End Device 2 on port 6004..."
run_with_prefix "EndDevice2" "$BIN_DIR/ZW_zwave_ncp_serial_api_end_device.elf" --port 6004 --storage "$STORAGE_DIR/enddevice2" &

# Start the Zniffer simulator
echo "Starting Zniffer on port 4905..."
run_with_prefix "Zniffer" python3 "$BIN_DIR/zniffer.py" 1234 &

echo "All Z-Wave binaries started!"
echo "Controller 1: localhost:5000 (Z-Wave JS FirstController)"
echo "Controller 2: localhost:6001 (CTT SecondController, proxied via 5001)"
echo "Controller 3: localhost:6002 (CTT ThirdController, proxied via 5002)"
echo "End Device 1: localhost:6003 (CTT FirstEndDevice, proxied via 5003)"
echo "End Device 2: localhost:6004 (CTT SecondEndDevice, proxied via 5004)"
echo "Zniffer:      localhost:4905"

# Wait for all background processes
wait
