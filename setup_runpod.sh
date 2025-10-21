#!/usr/bin/env bash
set -euo pipefail
echo "=== START: setup_runpod.sh ==="

# -------- 0) Helpers --------
require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1"; exit 1; }; }

# -------- 1) System deps --------
export DEBIAN_FRONTEND=noninteractive
apt update -y
DEPS="git python3 python3-venv python3-pip wget unzip curl ca-certificates \
      build-essential pkg-config yasm nasm meson ninja-build \
      libx264-dev libx265-dev libnuma-dev libvpx-dev libaom-dev \
      libfreetype6-dev libfribidi-dev libass-dev libmp3lame-dev libopus-dev \
      xxd"
echo "Installing: $DEPS"
apt install -y --no-install-recommends $DEPS

require_cmd python3
require_cmd wget
mkdir -p /usr/local/src
cd /usr/local/src

# -------- 2) Build & install libvmaf (with built-in models) --------
if [ ! -d vmaf ]; then
  echo "Cloning netflix/vmaf ..."
  git clone --depth=1 https://github.com/Netflix/vmaf.git
fi

echo "Building libvmaf with built-in models and float features ..."
cd /usr/local/src/vmaf/libvmaf

# NOTE: 'built_in_models' is the correct Meson option name for libvmaf
if [ -d build ]; then
  meson setup --reconfigure build \
    --buildtype release \
    -Dbuilt_in_models=true \
    -Denable_float=true
else
  meson setup build \
    --buildtype release \
    -Dbuilt_in_models=true \
    -Denable_float=true
fi

ninja -C build
ninja -C build install
ldconfig

# -------- 3) Build & install FFmpeg with libvmaf --------
cd /usr/local/src
if [ ! -d FFmpeg ]; then
  echo "Cloning FFmpeg ..."
  git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git
fi

cd FFmpeg
echo "Configuring FFmpeg (shared, dynamically linked) ..."
./configure --prefix=/opt/ffmpeg \
  --extra-cflags="-I/usr/local/include" \
  --extra-ldflags="-L/usr/local/lib" \
  --bindir=/opt/ffmpeg/bin \
  --enable-gpl \
  --enable-libx264 --enable-libx265 \
  --enable-libvpx --enable-libaom \
  --enable-libass --enable-libfreetype \
  --enable-libmp3lame --enable-libopus \
  --enable-libvmaf

make -j"$(nproc)"
make install
ldconfig

# PATH for current and future shells
echo 'export PATH=/opt/ffmpeg/bin:$PATH' >/etc/profile.d/ffmpeg.sh
chmod +x /etc/profile.d/ffmpeg.sh
export PATH=/opt/ffmpeg/bin:$PATH

# -------- 4) Verify ffmpeg build --------
echo "Verifying FFmpeg build..."
if ! ffmpeg -hide_banner -version | grep -q -- --enable-libvmaf; then
  echo "❌ libvmaf not found in FFmpeg build"; exit 1
fi
if ! ffmpeg -hide_banner -filters | grep -qi 'libvmaf'; then
  echo "❌ libvmaf filter missing"; exit 1
fi
echo "✅ FFmpeg has libvmaf."

# -------- 5) Download JSON model files on disk (optional but requested) --------
# Even though built-in models are compiled in, we also keep JSON models at:
#   /usr/share/vmaf/model
echo "Fetching VMAF model files to /usr/share/vmaf/model ..."
mkdir -p /usr/share/vmaf
if [ ! -d /usr/share/vmaf/.git ]; then
  # Clean and re-clone to keep only model files fresh
  rm -rf /usr/share/vmaf
  git clone --depth=1 https://github.com/Netflix/vmaf.git /usr/share/vmaf
fi

mkdir -p /usr/share/model
# Common symlinks for convenience
ln -sf /usr/share/vmaf/model/vmaf_v0.6.1.json      /usr/share/model/vmaf_v0.6.1.json
ln -sf /usr/share/vmaf/model/vmaf_4k_v0.6.1.json    /usr/share/model/vmaf_4k_v0.6.1.json
ln -sf /usr/share/vmaf/model/vmaf_b_v0.6.3.json     /usr/share/model/vmaf_b_v0.6.3.json
ln -sf /usr/share/vmaf/model/vmaf_float_v0.6.1.json /usr/share/model/vmaf_float_v0.6.1.json
ln -sf /usr/share/vmaf/model/vmaf_float_b_v0.6.3.json /usr/share/model/vmaf_float_b_v0.6.3.json
echo "✅ Model JSONs available under /usr/share/vmaf/model and /usr/share/model"

# -------- 6) Project setup (VideoCompression) --------
if [ -d /workspace/VideoCompression ]; then
  cd /workspace/VideoCompression
  mkdir -p test_videos output_videos
  python3 -m venv /workspace/venv
  source /workspace/venv/bin/activate
  pip install --upgrade pip
  pip install numpy pandas opencv-python ffmpeg-python
else
  echo "⚠️ /workspace/VideoCompression not found. Skipping venv + pip for project."
fi

# -------- 7) Runtime env helper --------
cat >/workspace/VideoCompression/runpod_env.sh <<'ENV'
#!/usr/bin/env bash
# Source this before running the project
if [ -d /workspace/venv ]; then
  source /workspace/venv/bin/activate
fi
export PATH=/opt/ffmpeg/bin:$PATH
export PYTHONUNBUFFERED=1
# Optional: point to JSON models directory if you prefer path-based model usage
export VMAF_MODEL_PATH="/usr/share/vmaf/model"
ENV
chmod +x /workspace/VideoCompression/runpod_env.sh || true

# -------- 8) Config.ini check --------
if [ -f /workspace/VideoCompression/config.ini ]; then
  echo "Found config.ini ✅"
else
  echo "⚠️ No config.ini found in /workspace/VideoCompression."
fi

echo "=== DONE: setup_runpod.sh ==="
echo "➡️ Next:"
echo "   source /workspace/VideoCompression/runpod_env.sh"
echo "   ffmpeg -filters | grep -E 'libvmaf|vmafmotion'    # should show both"
echo "   # Example (built-in model name):"
echo "   # ffmpeg -i distorted.mp4 -i reference.mp4 -lavfi \"libvmaf=model=version=vmaf_v0.6.1:log_fmt=json:log_path=/tmp/vmaf.json\" -f null -"
echo "   # Example (JSON path):"
echo "   # ffmpeg -i distorted.mp4 -i reference.mp4 -lavfi \"libvmaf=model='path=/usr/share/vmaf/model/vmaf_v0.6.1.json':log_fmt=json:log_path=/tmp/vmaf.json\" -f null -"
