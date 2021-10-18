FROM ubuntu:20.04

WORKDIR /workdir

# wabt provides wat2wasm
RUN apt-get update
RUN apt-get install -y wabt curl xz-utils

# wasmer may be used as an alternative
ADD https://wasmtime.dev/install.sh wasm_install.sh
RUN chmod a+x wasm_install.sh
RUN ./wasm_install.sh

# Default hello-world payload
ENV WASM_PAYLOAD_URL "https://pastebin.com/raw/QNuuWFFh"
# If "WAT_PAYLOAD" is set to "y", the payload is expected to be a Web Assembly
# Text file, which will be converted to a byte file before being executed.
ENV WAT_PAYLOAD "y"

COPY run_wasm.sh .
RUN chmod a+x ./run_wasm.sh

ENTRYPOINT ./run_wasm.sh
