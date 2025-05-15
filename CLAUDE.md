# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains a Docker Compose configuration for running Ollama with automatic GPU detection and acceleration. It supports:

- NVIDIA GPUs (via NVIDIA Container Runtime)
- Intel iGPUs (via OpenVINO)
- CPU-only fallback mode

## Docker Configuration

The setup includes three Docker Compose configurations:
- `docker-compose.nvidia.yml` - NVIDIA GPU acceleration
- `docker-compose.igpu.yml` - Intel GPU acceleration with OpenVINO
- `docker-compose.cpu.yml` - CPU-only mode

The `start-ollama.sh` script automatically detects available GPU hardware and creates a symlink to the appropriate configuration.

## Common Commands

### Container Management

```bash
# Start Ollama with automatic GPU detection
./start-ollama.sh

# Start the Ollama container using current config
docker compose up -d

# Stop the Ollama container
docker compose down

# View container logs
docker logs -f ollama
```

### Model Management

```bash
# List available models
docker exec -it ollama ollama list

# Pull a model
docker exec -it ollama ollama pull llama3

# Run a model interactively
docker exec -it ollama ollama run llama3

# Remove a model
docker exec -it ollama ollama rm llama3
```

### Customizing Models

Custom models can be defined using a modelfile:

```bash
# Create a custom model from an existing one
docker exec -it ollama ollama create mymodel -f /path/to/modelfile

# Example modelfile content:
# FROM llama3
# PARAMETER num_gpu 1
# PARAMETER num_thread 16
# PARAMETER num_ctx 8192
```

### GPU Verification

#### For NVIDIA GPUs:

```bash
# Check if NVIDIA GPU is visible to the container
docker exec -it ollama nvidia-smi
```

#### For Intel GPUs:

```bash
# Check if Intel GPU devices are properly mounted
docker exec -it ollama ls -la /dev/dri/

# Check OpenCL devices (may need to install clinfo)
docker exec -it ollama apt-get update && apt-get install -y clinfo
docker exec -it ollama clinfo
```

## Troubleshooting

1. If NVIDIA GPU acceleration is not working, verify:
   - The host system has NVIDIA drivers installed
   - NVIDIA Container Toolkit is properly installed and configured

2. If Intel GPU acceleration is not working, verify:
   - The host system has Intel GPU drivers installed
   - `/dev/dri` devices are available on the host
   - User running Docker is in the 'video' group

3. For Chrome extension support:
   - Set `OLLAMA_ORIGINS=chrome-extension://*` or specific extension IDs

4. Performance tuning:
   - Adjust `OLLAMA_CPU_THREADS` in docker-compose files based on your CPU cores
   - Configure memory limits based on your system resources

5. API availability:
   - The Ollama API is available at http://localhost:11434
   - Test with: `curl http://localhost:11434/api/tags`