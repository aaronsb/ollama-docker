# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains a Docker Compose configuration for running Ollama with Intel iGPU acceleration. It is designed to provide an easy-to-deploy containerized environment for running large language models using Ollama, optimized for Intel integrated GPUs.

## Docker Configuration

The setup uses Docker Compose with the following key components:
- Mounts Intel GPU devices for hardware acceleration
- Configures OpenVINO for optimized Intel GPU performance
- Sets up persistent storage for models in `./ollama_data`
- Exposes the Ollama API on port 11434

## Common Commands

### Container Management

```bash
# Start the Ollama container
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

```bash
# Check if Intel GPU devices are properly mounted
docker exec -it ollama ls -la /dev/dri/

# Check OpenCL devices (may need to install clinfo)
docker exec -it ollama apt-get update && apt-get install -y clinfo
docker exec -it ollama clinfo
```

## Troubleshooting

1. If Intel GPU acceleration is not working, verify:
   - The host system has Intel GPU drivers installed
   - `/dev/dri` devices are available on the host
   - User running Docker is in the 'video' group

2. For Chrome extension support:
   - Set `OLLAMA_ORIGINS=chrome-extension://*` or specific extension IDs

3. Performance tuning:
   - Adjust `OLLAMA_CPU_THREADS` in docker-compose.yml based on your CPU cores
   - Configure memory limits based on your system resources

4. API availability:
   - The Ollama API is available at http://localhost:11434
   - Test with: `curl http://localhost:11434/api/tags`