#!/usr/bin/env bash
set -euo pipefail
echo "=== START: setup_runpod.sh ==="

# 1) Install system dependencies
apt update -y
DEPS="git python3 python3-venv python3-pip ffmpeg unzip"
echo "Installing: $DEPS"
apt install -y --no-install-recommends $DEPS

# 2) Create Python virtual environment
cd /workspace/VideoCompression
mkdir -p /test_videos /output_videos /results
python3 -m venv /workspace/venv
source /workspace/venv/bin/activate
pip install --upgrade pip

# 3) Install project requirements if available
if [ -f requirements.txt ]; then
  echo "Installing requirements..."
  pip install -r requirements.txt
else
  echo "No requirements.txt found."
  pip install numpy pandas opencv-python ffmpeg-python
fi

# 5) Verify config.ini exists
if [ -f config.ini ]; then
  echo "Found config.ini ✅"
else
  echo "⚠️ No config.ini found. Please ensure it’s present in the project root."
fi

# 6) Export environment for runtime convenience
cat > /workspace/runpod_env.sh <<EOE
source /workspace/venv/bin/activate
cd /workspace/VideoCompression
EOE
chmod +x /workspace/runpod_env.sh

echo "=== DONE: setup_runpod.sh ==="
echo "➡️ Use 'source /workspace/runpod_env.sh' before running the project."
