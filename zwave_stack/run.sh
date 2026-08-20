#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

required_variables=(
  ZWAVE_STORAGE_DIR
  ZWAVE_CONTROLLER1_PORT
  ZWAVE_CONTROLLER2_PORT
  ZWAVE_CONTROLLER3_PORT
  ZWAVE_ENDDEVICE1_PORT
  ZWAVE_ENDDEVICE2_PORT
  ZWAVE_NODE_TEMP_DIR
  ZWAVE_ZNIFFER_PORT
  ZWAVE_ZNIFFER_DISCOVERY_PORT
  ZWAVE_ZNE_PORT
)

for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing required environment variable: $variable" >&2
    exit 1
  fi
done

mkdir -p \
  "$ZWAVE_NODE_TEMP_DIR/controller1" \
  "$ZWAVE_NODE_TEMP_DIR/controller2" \
  "$ZWAVE_NODE_TEMP_DIR/controller3" \
  "$ZWAVE_NODE_TEMP_DIR/enddevice1" \
  "$ZWAVE_NODE_TEMP_DIR/enddevice2"

echo "Starting Z-Wave Stack from $SCRIPT_DIR..."

run_with_prefix() {
  local prefix="$1"
  shift
  "$@" 2>&1 | sed -u "s/^/[$prefix] /"
}

echo "Starting Controller 1 (Z-Wave JS) on port $ZWAVE_CONTROLLER1_PORT..."
run_with_prefix "Controller1" "$BIN_DIR/ZW_zwave_ncp_serial_api_controller.elf" --port "$ZWAVE_CONTROLLER1_PORT" --storage "$ZWAVE_STORAGE_DIR/controller1" --tmp-path "$ZWAVE_NODE_TEMP_DIR/controller1" --id 1 --zne-port "$ZWAVE_ZNE_PORT" &

echo "Starting Controller 2 (CTT) on port $ZWAVE_CONTROLLER2_PORT..."
run_with_prefix "Controller2" "$BIN_DIR/ZW_zwave_ncp_serial_api_controller.elf" --port "$ZWAVE_CONTROLLER2_PORT" --storage "$ZWAVE_STORAGE_DIR/controller2" --tmp-path "$ZWAVE_NODE_TEMP_DIR/controller2" --id 2 --zne-port "$ZWAVE_ZNE_PORT" &

echo "Starting Controller 3 (CTT) on port $ZWAVE_CONTROLLER3_PORT..."
run_with_prefix "Controller3" "$BIN_DIR/ZW_zwave_ncp_serial_api_controller.elf" --port "$ZWAVE_CONTROLLER3_PORT" --storage "$ZWAVE_STORAGE_DIR/controller3" --tmp-path "$ZWAVE_NODE_TEMP_DIR/controller3" --id 3 --zne-port "$ZWAVE_ZNE_PORT" &

echo "Starting End Device 1 on port $ZWAVE_ENDDEVICE1_PORT..."
run_with_prefix "EndDevice1" "$BIN_DIR/ZW_zwave_ncp_serial_api_end_device.elf" --port "$ZWAVE_ENDDEVICE1_PORT" --storage "$ZWAVE_STORAGE_DIR/enddevice1" --tmp-path "$ZWAVE_NODE_TEMP_DIR/enddevice1" --id 4 --zne-port "$ZWAVE_ZNE_PORT" &

echo "Starting End Device 2 on port $ZWAVE_ENDDEVICE2_PORT..."
run_with_prefix "EndDevice2" "$BIN_DIR/ZW_zwave_ncp_serial_api_end_device.elf" --port "$ZWAVE_ENDDEVICE2_PORT" --storage "$ZWAVE_STORAGE_DIR/enddevice2" --tmp-path "$ZWAVE_NODE_TEMP_DIR/enddevice2" --id 5 --zne-port "$ZWAVE_ZNE_PORT" &

echo "Starting Zniffer on port $ZWAVE_ZNIFFER_PORT..."
run_with_prefix "Zniffer" python3 "$BIN_DIR/zniffer.py" 1234 \
  --tcp-port "$ZWAVE_ZNIFFER_PORT" \
  --discovery-port "$ZWAVE_ZNIFFER_DISCOVERY_PORT" \
  --zne-port "$ZWAVE_ZNE_PORT" \
  --node-count 5 &

echo "All Z-Wave binaries started!"
echo "Controller 1: localhost:$ZWAVE_CONTROLLER1_PORT (Z-Wave JS FirstController)"
echo "Controller 2: localhost:$ZWAVE_CONTROLLER2_PORT (CTT SecondController)"
echo "Controller 3: localhost:$ZWAVE_CONTROLLER3_PORT (CTT ThirdController)"
echo "End Device 1: localhost:$ZWAVE_ENDDEVICE1_PORT (CTT FirstEndDevice)"
echo "End Device 2: localhost:$ZWAVE_ENDDEVICE2_PORT (CTT SecondEndDevice)"
echo "Zniffer:      localhost:$ZWAVE_ZNIFFER_PORT"

wait
