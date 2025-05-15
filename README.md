# Ollama Docker Setup with Intel iGPU Support

This repository contains a Docker Compose configuration for running Ollama with Intel iGPU acceleration.

## Prerequisites

Before you begin, ensure you have the following installed:

- Docker Engine
- Docker Compose
- Intel GPU drivers (i915)
- Intel Compute Runtime for OpenCL

### Setting Up Intel iGPU for Docker

To ensure your Intel iGPU is properly configured for Docker:

1. Make sure you have the latest Intel drivers installed:

```bash
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y intel-opencl-icd intel-level-zero-gpu level-zero \
  intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 \
  intel-gpu-tools
```

2. Add your user to the 'video' group to access GPU devices:

```bash
sudo usermod -a -G video $USER
# Log out and log back in for changes to take effect
```

3. Verify your Intel GPU is detected:

```bash
ls -la /dev/dri/
# You should see devices like card1, card2, renderD128, renderD129
```

## Getting Started

### Starting Ollama

To start the Ollama container:

```bash
docker compose up -d
```

This will:
- Pull the latest Ollama image if not already present
- Create a Docker volume for persistent storage
- Start the container in detached mode
- Configure GPU access

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

To verify that Ollama can access the Intel GPU:

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

1. **GPU not detected**: Ensure Intel GPU drivers are properly installed and the /dev/dri devices are available.

2. **Permission issues**: Make sure your user is in the 'video' group and the container has the proper device mappings.

3. **OpenVINO errors**: If you see errors related to OpenVINO, ensure the Intel Compute Runtime is properly installed.

4. **Network connectivity**: The container is configured to use the host network for optimal performance.

## Advanced Configuration

### Environment Variables

You can add environment variables to the Docker Compose file to customize Ollama:

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

## License

Ollama is licensed under the MIT License. See the [Ollama GitHub repository](https://github.com/ollama/ollama) for more details.
