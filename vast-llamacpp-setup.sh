#!/bin/bash

# ==============================================================================
#  Setup Script for Llama.cpp on Vast.ai (Ubuntu 24.04)
# ==============================================================================
#
#  This script will:
#  1. Install NVIDIA CUDA Toolkit 12.8.
#  2. Install the correct PyTorch version for CUDA 12.8.
#  3. Clone the latest llama.cpp repository.
#  4. Build llama.cpp with CUDA support, intelligently detecting the
#     number of allocated CPU cores in a containerized environment.
#
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

echo "===== Starting Llama.cpp Setup for Ubuntu 24.04 on Vast.ai ====="

# --- 1. Install CUDA Toolkit 12.8 ---
echo
echo "===== Step 1: Installing CUDA Toolkit 12.8 ====="

# Install dependencies for adding repositories
sudo apt-get update
sudo apt-get install -y wget gpg-agent software-properties-common

# Download and install CUDA repo files
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin
sudo mv cuda-ubuntu2404.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda-repo-ubuntu2404-12-8-local_12.8.0-570.86.10-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2404-12-8-local_12.8.0-570.86.10-1_amd64.deb

# Add the GPG key and update apt
sudo cp /var/cuda-repo-ubuntu2404-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update

# Install the CUDA toolkit
echo "--- Installing cuda-toolkit-12-8... This may take a while. ---"
sudo apt-get -y install cuda-toolkit-12-8

# Clean up the downloaded installer
rm cuda-repo-ubuntu2404-12-8-local_12.8.0-570.86.10-1_amd64.deb

# --- Set up CUDA environment variables ---
echo "--- Configuring CUDA environment variables... ---"
# For future sessions
{
    echo ''
    echo '# CUDA Environment Variables'
    echo 'export PATH=/usr/local/cuda-12.8/bin${PATH:+:${PATH}}'
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}'
} >> ~/.bashrc

# For the current script session
export PATH=/usr/local/cuda-12.8/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

# Verify installation
echo "--- Verifying CUDA installation (nvcc) ---"
nvcc --version

# --- 2. Install PyTorch for CUDA 12.8 ---
echo
echo "===== Step 2: Installing PyTorch for CUDA 12.8 ====="
pip install --upgrade pip
pip uninstall -y torch torchvision torchaudio
pip cache purge
pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128

# --- 3. Clone and Build llama.cpp ---
echo
echo "===== Step 3: Cloning and Building llama.cpp with CUDA Support ====="

# Navigate to home directory to ensure a clean start location
cd /workspace

# Remove any previous llama.cpp directory
if [ -d "llama.cpp" ]; then
    echo "--- Removing existing llama.cpp directory ---"
    rm -rf llama.cpp
fi

# Clone the repository
echo "--- Cloning llama.cpp repository ---"
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp

# --- Intelligently Detect Allocated CPU Cores ---
echo "--- Detecting allocated CPU cores for build ---"
if [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -f /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
    CPU_QUOTA=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
    CPU_PERIOD=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)

    if [ "$CPU_QUOTA" = "-1" ]; then
        # Unlimited quota, fall back to nproc
        BUILD_CORES=$(nproc)
        echo "Unlimited CPU quota detected. Using all available cores: $BUILD_CORES"
    else
        # Calculate cores from cgroup quota (ceiling division)
        BUILD_CORES=$(( (CPU_QUOTA + CPU_PERIOD - 1) / CPU_PERIOD ))
        echo "CPU quota detected via cgroups. Using allocated cores: $BUILD_CORES"
    fi
else
    # Fallback for systems without cgroups/CFS files
    BUILD_CORES=$(nproc)
    echo "cgroup CPU quota files not found. Falling back to nproc: $BUILD_CORES"
fi

# Build llama.cpp using CMake
echo "--- Configuring build with CMake (GGML_CUDA=ON) ---"
cmake -B build -DGGML_CUDA=ON

echo "--- Building llama.cpp using $BUILD_CORES cores ---"
# The '--' separates cmake flags from the native build tool's flags (like -j)
cmake --build build --config Release -- -j${BUILD_CORES}

# --- 4. Finalization ---
echo
echo "========================================================================"
echo "                           SETUP COMPLETE!"
echo "========================================================================"
echo
echo "  - CUDA 12.8 and PyTorch are installed."
echo "  - llama.cpp has been successfully built with CUDA support."
echo "  - Binaries are located in: '~/llama.cpp/build/bin/'"
echo
echo "  Example usage (from inside the '~/llama.cpp' directory):"
echo "  ./build/bin/llama-bench -m <path_to_model.gguf> -p 512 -n 512 -ngl 32"
echo
echo "  IMPORTANT: To make the CUDA environment variables permanent,"
echo "  please run 'source ~/.bashrc' or restart your shell."
echo "========================================================================"
