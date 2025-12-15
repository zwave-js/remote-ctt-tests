#!/bin/bash
# Start all Z-Wave binaries in the background
# Note: Run this script from the repository root directory

echo "Starting Z-Wave Stack..."

# Helper function to prefix output with process name
run_with_prefix() {
  local prefix="$1"
  shift
  "$@" 2>&1 | sed -u "s/^/[$prefix] /"
}

# Start 3 controllers
echo "Starting Controller 1 (Z-Wave JS) on port 5000..."
run_with_prefix "Controller1" ./zwave_stack/bin/ZW_zwave_ncp_serial_api_controller.elf --port 5000 --storage ./zwave_stack/storage/controller1 &

echo "Starting Controller 2 (CTT) on port 6001..."
run_with_prefix "Controller2" ./zwave_stack/bin/ZW_zwave_ncp_serial_api_controller.elf --port 6001 --storage ./zwave_stack/storage/controller2 &

echo "Starting Controller 3 (CTT) on port 6002..."
run_with_prefix "Controller3" ./zwave_stack/bin/ZW_zwave_ncp_serial_api_controller.elf --port 6002 --storage ./zwave_stack/storage/controller3 &

# Start 2 end devices
echo "Starting End Device 1 on port 6003..."
run_with_prefix "EndDevice1" ./zwave_stack/bin/ZW_zwave_ncp_serial_api_end_device.elf --port 6003 --storage ./zwave_stack/storage/enddevice1 &

echo "Starting End Device 2 on port 6004..."
run_with_prefix "EndDevice2" ./zwave_stack/bin/ZW_zwave_ncp_serial_api_end_device.elf --port 6004 --storage ./zwave_stack/storage/enddevice2 &

# Start the Zniffer simulator
echo "Starting Zniffer on port 4905..."
run_with_prefix "Zniffer" python3 ./zwave_stack/bin/zniffer.py 1234 &

echo "All Z-Wave binaries started!"
echo "Controller 1: localhost:5000 (Z-Wave JS FirstController)"
echo "Controller 2: localhost:6001 (CTT SecondController, proxied via 5001)"
echo "Controller 3: localhost:6002 (CTT ThirdController, proxied via 5002)"
echo "End Device 1: localhost:6003 (CTT FirstEndDevice, proxied via 5003)"
echo "End Device 2: localhost:6004 (CTT SecondEndDevice, proxied via 5004)"
echo "Zniffer:      localhost:4905"

# Wait for all background processes
wait
