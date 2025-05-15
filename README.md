# Ollama Docker Setup with GPU Support

This repository contains a Docker Compose configuration for running Ollama with automatic GPU detection and acceleration. It supports:

- NVIDIA GPUs (via NVIDIA Container Runtime)
- Intel iGPUs (via OpenVINO)
- CPU-only fallback mode

## Prerequisites

Before you begin, ensure you have the following installed:

- Docker Engine
- Docker Compose (V2 recommended)

### For NVIDIA GPU Support

- NVIDIA GPU with appropriate drivers
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

### For Intel iGPU Support

- Intel GPU drivers (i915)
- Intel Compute Runtime for OpenCL

```bash
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y intel-opencl-icd intel-level-zero-gpu level-zero \
  intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 \
  intel-gpu-tools
  
# Add your user to the 'video' group
sudo usermod -a -G video $USER
# Log out and log back in for changes to take effect
```

## Getting Started

### Starting Ollama

The `start-ollama.sh` script automatically detects your available GPU hardware and configures the appropriate Docker Compose setup.

```bash
# Make the script executable if needed
chmod +x start-ollama.sh

# Run the setup script
./start-ollama.sh
```

This script will:
1. Detect available GPU hardware (NVIDIA, Intel iGPU, or fallback to CPU)
2. Create a symlink to the appropriate Docker Compose configuration
3. Start the Ollama container with the correct GPU access
4. Verify the Ollama API is responsive
5. Offer to pull and run an initial model

### Stopping Ollama

To stop the Ollama container:

```bash
docker compose down
```

## Using Ollama

### API Access

The Ollama API is available at:

```
http://localhost:11434
```

### Running Models

You can run models directly using the Docker container:

```bash
# Run a model
docker exec -it ollama ollama run llama3

# List available models
docker exec -it ollama ollama list

# Pull a new model
docker exec -it ollama ollama pull mistral
```

### Using with Local Ollama Client

If you have the Ollama client installed locally, you can use it to interact with the Docker instance:

```bash
ollama list
ollama run llama3
```

The client will automatically connect to the API endpoint at localhost:11434.

## Managing Models

Models are stored in the Docker volume `ollama_data`. This ensures they persist even if the container is removed.

```bash
# List models
docker exec -it ollama ollama list

# Pull a model
docker exec -it ollama ollama pull llama3

# Remove a model
docker exec -it ollama ollama rm llama3
```

## Troubleshooting

### Checking GPU Access

To verify that Ollama can access the GPU:

#### For NVIDIA GPUs:

```bash
# Check if NVIDIA GPU is visible to the container
docker exec -it ollama nvidia-smi
```

#### For Intel GPUs:

```bash
# Check if Intel GPU devices are properly mounted
docker exec -it ollama ls -la /dev/dri/
# You should see devices like card1, card2, renderD128, renderD129

# Check OpenCL devices (install clinfo in the container if needed)
docker exec -it ollama apt-get update && apt-get install -y clinfo
docker exec -it ollama clinfo

# Check if the container has access to the video group
docker exec -it ollama groups
# Should include 'video' in the output
```

### Viewing Logs

To view the Ollama container logs:

```bash
docker logs -f ollama
```

### Common Issues

1. **NVIDIA GPU not detected**: Ensure NVIDIA Container Toolkit is properly installed and configured.

2. **Intel GPU not detected**: Ensure Intel GPU drivers are properly installed and the /dev/dri devices are available.

3. **Permission issues**: Make sure your user is in the 'video' group and the container has the proper device mappings.

4. **OpenVINO errors**: If you see errors related to OpenVINO, ensure the Intel Compute Runtime is properly installed.

5. **Network connectivity**: The container is configured to use host networking for optimal performance.

## Advanced Configuration

### Environment Variables

You can customize Ollama operation by editing the appropriate Docker Compose file and modifying the environment variables:

```yaml
services:
  ollama:
    # existing configuration...
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_ORIGINS=chrome-extension://*  # For Chrome extension support
      # Add other environment variables as needed
```

#### Chrome Extension Support

To use Ollama with Chrome extensions, you must set the `OLLAMA_ORIGINS` environment variable. There are two ways to do this:

1. **Allow Specific Extension** (Recommended):
   ```bash
   # Replace [YOUR_EXTENSION_ID] with your Chrome extension ID
   export OLLAMA_ORIGINS="chrome-extension://[YOUR_EXTENSION_ID]"
   ```
   Find your extension ID in chrome://extensions/ (enable Developer mode).

2. **Allow All Extensions** (Less Secure):
   ```bash
   export OLLAMA_ORIGINS="chrome-extension://*"
   ```

Make this setting permanent by adding it to your shell profile (~/.bashrc, ~/.zshrc, etc.).

The included `start-ollama.sh` script will prompt you to configure this if not already set.

### Custom Models

To use custom models, you can either:

1. Pull them using the Ollama CLI
2. Import them using the Ollama API
3. Create a custom model with a modelfile:

```bash
# Create a custom model with specific parameters
docker exec -it ollama ollama create mymodel -f /path/to/modelfile
```

Example modelfile (see the included sample):
```
FROM qwen3:8b
PARAMETER num_gpu 1
PARAMETER num_thread 16
PARAMETER num_ctx 131072  
PARAMETER num_batch 1024
```

## License

Ollama is licensed under the MIT License. See the [Ollama GitHub repository](https://github.com/ollama/ollama) for more details.