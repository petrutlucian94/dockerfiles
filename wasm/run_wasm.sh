#!/bin/bash

set -e

USER_PAYLOAD=/tmp/wasm_user_payload
RUNNABLE_PAYLOAD=/tmp/wasm_runnable_payload

echo "Fetching WASM payload: $WASM_PAYLOAD_URL"
curl $WASM_PAYLOAD_URL -o $USER_PAYLOAD

if [[ $WAT_PAYLOAD == "y" ]]; then
    echo "Converting .wat to .wasm"
    wat2wasm $USER_PAYLOAD -o $RUNNABLE_PAYLOAD
else
    RUNNABLE_PAYLOAD=$USER_PAYLOAD
fi

echo "Executing payload"
~/.wasmtime/bin/wasmtime $RUNNABLE_PAYLOAD
