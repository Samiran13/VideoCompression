#!/usr/bin/env bash
# Source this before running the project
source /workspace/venv/bin/activate
export PATH=/opt/ffmpeg/bin:$PATH
export PYTHONUNBUFFERED=1
export VMAF_MODEL="/usr/share/vmaf/model/vmaf_v0.6.1.json"
export VMAF_MODEL_PATH="/usr/share/vmaf/model"

# If models are missing, fetch them
if [ ! -f /usr/share/vmaf/model/vmaf_v0.6.1.json ]; then
  echo "Downloading VMAF model..."
  sudo mkdir -p /usr/share/vmaf/model
  sudo git clone --depth=1 https://github.com/Netflix/vmaf.git /usr/share/vmaf
  sudo ln -sf /usr/share/vmaf/model/vmaf_v0.6.1.json /usr/share/model/vmaf_v0.6.1.json
  sudo ln -sf /usr/share/vmaf/model/vmaf_4k_v0.6.1.json /usr/share/model/vmaf_4k_v0.6.1.json
fi

echo "Environment ready ✅"
