About
-----

This simple docker file allows running WebAssembly payloads within a container.
Kata Containers may be used to run the container in a VM sandbox for security
reasons.

Here's a sample:
```
git clone https://github.com/petrutlucian94/dockerfiles
sudo time ctr run \
    --mount type=bind,src=$(pwd)/dockerfiles/wasm,dst=/host,options=rbind:ro \
    --env WASM_PAYLOAD_URL=file:///host/hello_world.wat \
    --runtime "io.containerd.kata.v2" \
    --rm -t "$image2" test-wasm
```
