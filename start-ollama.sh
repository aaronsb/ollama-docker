#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Ollama Docker Setup${NC}"
echo "=============================="

# Check for OLLAMA_ORIGINS environment variable
if [ -z "${OLLAMA_ORIGINS}" ]; then
    echo -e "${YELLOW}Note: OLLAMA_ORIGINS not set.${NC}"
    echo "This is required for Chrome extensions to connect to Ollama."
    echo "Options:"
    echo "1. Set to specific extension: chrome-extension://[YOUR_EXTENSION_ID]"
    echo "2. Allow all extensions: chrome-extension://*"
    read -p "Would you like to allow all Chrome extensions? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        export OLLAMA_ORIGINS="chrome-extension://*"
        echo "Set OLLAMA_ORIGINS=chrome-extension://*"
        echo "To make this permanent, add to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo "export OLLAMA_ORIGINS=\"chrome-extension://*\""
    else
        echo "Please set OLLAMA_ORIGINS manually for your specific extension:"
        echo "export OLLAMA_ORIGINS=\"chrome-extension://[YOUR_EXTENSION_ID]\""
        echo "Find your extension ID in chrome://extensions/ (Developer mode)"
    fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${YELLOW}Warning: Docker Compose V2 not found.${NC}"
    if command -v docker-compose &> /dev/null; then
        echo "Using legacy docker-compose."
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}Error: Docker Compose is not installed.${NC}"
        echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
else
    COMPOSE_CMD="docker compose"
fi

# GPU detection
GPU_TYPE="cpu"
CONFIG_FILE="docker-compose.cpu.yml"

# Check for NVIDIA GPU
echo "Checking for NVIDIA GPU..."
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo -e "${GREEN}NVIDIA GPU detected!${NC}"
        
        # Check if nvidia-container-runtime is available
        if grep -q "nvidia" <<< "$(docker info)" || command -v nvidia-container-runtime &> /dev/null; then
            echo "NVIDIA Container Runtime is available."
            GPU_TYPE="nvidia"
            CONFIG_FILE="docker-compose.nvidia.yml"
        else
            echo -e "${YELLOW}Warning: NVIDIA GPU detected but NVIDIA Container Runtime is not installed.${NC}"
            echo "Please install NVIDIA Container Runtime to use GPU acceleration:"
            echo "https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
            echo "Falling back to CPU mode."
        fi
    else
        echo "NVIDIA GPU not detected or driver issue."
    fi
fi

# Check for Intel GPU if NVIDIA is not available or not properly configured
if [ "$GPU_TYPE" == "cpu" ]; then
    echo "Checking for Intel GPU..."
    if ls /dev/dri/card* &> /dev/null && ls /dev/dri/renderD* &> /dev/null; then
        echo -e "${GREEN}Intel GPU devices detected!${NC}"
        
        # Display available GPU devices
        echo "Available GPU devices:"
        ls -la /dev/dri/
        
        # Check if the current user has access to the video group
        if ! groups | grep -q "video"; then
            echo -e "${YELLOW}Warning: Current user is not in the 'video' group.${NC}"
            echo "This may prevent proper access to the GPU."
            echo "Consider adding your user to the video group with:"
            echo "sudo usermod -a -G video \$USER"
            echo "Then log out and log back in for changes to take effect."
        fi
        
        GPU_TYPE="igpu"
        CONFIG_FILE="docker-compose.igpu.yml"
    else
        echo "Intel GPU devices not detected."
        echo "Falling back to CPU-only mode."
    fi
fi

# Create symlink to correct config file
echo "Using $GPU_TYPE configuration ($CONFIG_FILE)..."
ln -sf $CONFIG_FILE docker-compose.yml

# Ask the user to confirm
echo
echo "Ready to start Ollama with $GPU_TYPE acceleration."
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Exiting."
    exit 1
fi

# Start Ollama container
echo "Starting Ollama container..."
$COMPOSE_CMD up -d

# Check if container started successfully
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start Ollama container.${NC}"
    echo "Check the logs with: docker logs ollama"
    exit 1
fi

echo -e "${GREEN}Ollama container started successfully!${NC}"

# Wait for Ollama to initialize
echo "Waiting for Ollama to initialize..."
sleep 5

# Check if Ollama is responding
echo "Checking Ollama API..."
if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo -e "${YELLOW}Warning: Ollama API not responding yet. This is normal on first startup.${NC}"
    echo "It may take a few moments for the service to fully initialize."
else
    echo -e "${GREEN}Ollama API is responding!${NC}"
fi

# Ask if user wants to pull a model
echo
echo "Would you like to pull a model now? This will download the model files."
read -p "Pull llama3 model? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Pulling llama3 model (this may take a while)..."
    docker exec -it ollama ollama pull llama3
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Model pulled successfully!${NC}"
        
        # Ask if user wants to run the model
        echo
        echo "Would you like to run the model now?"
        read -p "Run llama3? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Running llama3 model..."
            docker exec -it ollama ollama run llama3
        fi
    else
        echo -e "${RED}Failed to pull model.${NC}"
        echo "Check the logs with: docker logs ollama"
    fi
fi

echo
echo -e "${GREEN}Setup complete!${NC}"
echo
echo "Quick commands:"
echo "  - List models:    docker exec -it ollama ollama list"
echo "  - Run a model:    docker exec -it ollama ollama run llama3"
echo "  - Pull a model:   docker exec -it ollama ollama pull mistral"
echo "  - Stop Ollama:    docker compose down"
echo "  - View logs:      docker logs -f ollama"
echo
echo "Current acceleration mode: ${GREEN}$GPU_TYPE${NC}"
echo "See README.md for more information and troubleshooting."