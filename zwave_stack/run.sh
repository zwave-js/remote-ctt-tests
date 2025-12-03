#!/bin/bash
# Start all Z-Wave binaries in the background
# Note: Run this script from the repository root directory

echo "Starting Z-Wave Stack..."

# Start 3 controllers
echo "Starting Controller 1 (Z-Wave JS) on port 5000..."
./zwave_stack/bin/ZW_zwave_ncp_serial_api_controller_25_9_0_x86_REALTIME_DEBUG.elf --port 5000 --storage ./zwave_stack/storage/controller1 &

echo "Starting Controller 2 (CTT) on port 5001..."
./zwave_stack/bin/ZW_zwave_ncp_serial_api_controller_25_9_0_x86_REALTIME_DEBUG.elf --port 5001 --storage ./zwave_stack/storage/controller2 &

echo "Starting Controller 3 (CTT) on port 5002..."
./zwave_stack/bin/ZW_zwave_ncp_serial_api_controller_25_9_0_x86_REALTIME_DEBUG.elf --port 5002 --storage ./zwave_stack/storage/controller3 &

# Start 2 end devices
echo "Starting End Device 1 on port 5003..."
./zwave_stack/bin/ZW_zwave_ncp_serial_api_end_device_25_9_0_x86_REALTIME_DEBUG.elf --port 5003 --storage ./zwave_stack/storage/enddevice1 &

echo "Starting End Device 2 on port 5004..."
./zwave_stack/bin/ZW_zwave_ncp_serial_api_end_device_25_9_0_x86_REALTIME_DEBUG.elf --port 5004 --storage ./zwave_stack/storage/enddevice2 &

echo "All Z-Wave binaries started!"
echo "Controller 1: localhost:5000 (Z-Wave JS FirstController)"
echo "Controller 2: localhost:5001 (CTT SecondController)"
echo "Controller 3: localhost:5002 (CTT ThirdController)"
echo "End Device 1: localhost:5003 (CTT FirstEndDevice)"
echo "End Device 2: localhost:5004 (CTT SecondEndDevice)"

# Wait for all background processes
wait
