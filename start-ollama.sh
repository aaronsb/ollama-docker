#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
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

# Array to store available GPU options
AVAILABLE_GPUS=()
AVAILABLE_GPU_NAMES=()

# Check for NVIDIA GPU
echo -e "\n${BLUE}Checking for available GPUs...${NC}"
NVIDIA_AVAILABLE=false
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        # Check if nvidia-container-runtime is available
        if grep -q "nvidia" <<< "$(docker info)" || command -v nvidia-container-runtime &> /dev/null; then
            echo -e "✅ ${GREEN}NVIDIA GPU detected and NVIDIA Container Runtime is available${NC}"
            NVIDIA_AVAILABLE=true
            AVAILABLE_GPUS+=("nvidia")
            
            # Get NVIDIA GPU model
            GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
            if [ -n "$GPU_MODEL" ]; then
                AVAILABLE_GPU_NAMES+=("NVIDIA: $GPU_MODEL")
            else
                AVAILABLE_GPU_NAMES+=("NVIDIA GPU")
            fi
        else
            echo -e "❌ ${YELLOW}NVIDIA GPU detected but NVIDIA Container Runtime is not installed${NC}"
            echo "To use NVIDIA acceleration, install NVIDIA Container Runtime:"
            echo "https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
        fi
    else
        echo -e "❌ ${YELLOW}NVIDIA GPU not detected or driver issue${NC}"
    fi
else
    echo -e "ℹ️  NVIDIA tools not found"
fi

# Check for Intel GPU
INTEL_AVAILABLE=false
if ls /dev/dri/card* &> /dev/null && ls /dev/dri/renderD* &> /dev/null; then
    echo -e "✅ ${GREEN}Intel GPU devices detected${NC}"
    
    # Display available GPU devices
    echo "  Available GPU devices:"
    ls -la /dev/dri/ | grep -E 'card|renderD' | awk '{print "   - " $9 " " $10 " " $11}'
    
    # Check if the current user has access to the video group
    if ! groups | grep -q "video"; then
        echo -e "  ${YELLOW}Warning: Current user is not in the 'video' group${NC}"
        echo "  This may prevent proper access to the GPU."
        echo "  Consider adding your user to the video group with:"
        echo "  sudo usermod -a -G video \$USER"
        echo "  Then log out and log back in for changes to take effect."
    else
        INTEL_AVAILABLE=true
        AVAILABLE_GPUS+=("igpu")
        
        # Try to get Intel GPU model
        if command -v lspci &> /dev/null; then
            GPU_MODEL=$(lspci | grep -i vga | grep -i intel | sed 's/.*: //')
            if [ -n "$GPU_MODEL" ]; then
                AVAILABLE_GPU_NAMES+=("Intel: $GPU_MODEL")
            else
                AVAILABLE_GPU_NAMES+=("Intel iGPU")
            fi
        else
            AVAILABLE_GPU_NAMES+=("Intel iGPU")
        fi
    fi
else
    echo -e "❌ ${YELLOW}Intel GPU devices not detected${NC}"
fi

# Add CPU as a fallback option
AVAILABLE_GPUS+=("cpu")
AVAILABLE_GPU_NAMES+=("CPU only")

# Default to CPU mode
GPU_TYPE="cpu"
CONFIG_FILE="docker-compose.cpu.yml"

# Automatically choose the best available option (prioritize NVIDIA over Intel over CPU)
if [ "$NVIDIA_AVAILABLE" = true ]; then
    GPU_TYPE="nvidia"
    CONFIG_FILE="docker-compose.nvidia.yml"
    DEFAULT_OPTION=1
elif [ "$INTEL_AVAILABLE" = true ]; then
    GPU_TYPE="igpu"
    CONFIG_FILE="docker-compose.igpu.yml"
    DEFAULT_OPTION=2
else
    DEFAULT_OPTION=3
fi

# Let user select GPU mode if multiple options are available
if [ ${#AVAILABLE_GPUS[@]} -gt 1 ]; then
    echo -e "\n${BLUE}Available acceleration options:${NC}"
    for i in "${!AVAILABLE_GPUS[@]}"; do
        if [ $((i+1)) -eq $DEFAULT_OPTION ]; then
            echo -e "${GREEN}$((i+1)). ${AVAILABLE_GPU_NAMES[$i]} (recommended)${NC}"
        else
            echo "$((i+1)). ${AVAILABLE_GPU_NAMES[$i]}"
        fi
    done
    
    read -p "Select acceleration option [$DEFAULT_OPTION]: " GPU_OPTION
    if [ -z "$GPU_OPTION" ]; then
        GPU_OPTION=$DEFAULT_OPTION
    fi
    
    if [ $GPU_OPTION -ge 1 ] && [ $GPU_OPTION -le ${#AVAILABLE_GPUS[@]} ]; then
        GPU_TYPE=${AVAILABLE_GPUS[$((GPU_OPTION-1))]}
        CONFIG_FILE="docker-compose.${GPU_TYPE}.yml"
    else
        echo -e "${YELLOW}Invalid option. Using recommended option: $DEFAULT_OPTION${NC}"
        GPU_OPTION=$DEFAULT_OPTION
        GPU_TYPE=${AVAILABLE_GPUS[$((GPU_OPTION-1))]}
        CONFIG_FILE="docker-compose.${GPU_TYPE}.yml"
    fi
fi

# Create symlink to correct config file
echo -e "\n${BLUE}Preparing configuration...${NC}"
echo "Using $GPU_TYPE configuration ($CONFIG_FILE)..."
ln -sf $CONFIG_FILE docker-compose.yml

# Ask if user wants interactive or detached mode
echo -e "\n${BLUE}Container start mode:${NC}"
echo "1. Detached (run in background) - recommended for regular use"
echo "2. Interactive (run in foreground) - useful for debugging"
read -p "Select run mode [1]: " RUN_MODE
if [ -z "$RUN_MODE" ]; then
    RUN_MODE=1
fi

if [ "$RUN_MODE" -eq 1 ]; then
    RUN_OPTION="-d"
    echo "Running in detached mode"
else
    RUN_OPTION=""
    echo -e "Running in interactive mode (press ${YELLOW}Ctrl+C${NC} to stop)"
fi

# Start Ollama container
echo -e "\n${BLUE}Starting Ollama container...${NC}"
$COMPOSE_CMD up $RUN_OPTION

# If we're in interactive mode, the script will pause here until Ctrl-C
# After Ctrl-C, inform the user that Ollama is no longer running
if [ "$RUN_MODE" -eq 2 ]; then
    echo
    echo -e "${YELLOW}Ollama has been stopped.${NC}"
    echo "To restart Ollama in the background, run: docker compose up -d"
    exit 0
fi

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
    echo "Check the logs with: docker logs -f ollama"
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
echo -e "Current acceleration mode: ${GREEN}$GPU_TYPE${NC}"
echo "See README.md for more information and troubleshooting."