#!/usr/bin/env bash
set -euo pipefail
echo "=== START: setup_runpod.sh ==="

# -------- 0) Helpers --------
require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1"; exit 1; }; }

# -------- 1) System deps --------
export DEBIAN_FRONTEND=noninteractive
apt update -y
DEPS="git python3 python3-venv python3-pip wget unzip build-essential pkg-config yasm nasm meson ninja-build libx264-dev libx265-dev libnuma-dev libvpx-dev libaom-dev libfreetype6-dev libfribidi-dev libass-dev libmp3lame-dev libopus-dev ca-certificates curl xxd"
echo "Installing: $DEPS"
apt install -y --no-install-recommends $DEPS

require_cmd python3
require_cmd wget

# -------- 2) Build & install libvmaf + FFmpeg (with built-in models) --------
echo "Building FFmpeg with libvmaf ..."
cd /usr/local/src
if [ ! -d vmaf ]; then git clone --depth=1 https://github.com/Netflix/vmaf.git; fi
cd vmaf/libvmaf

# enable built-in models
if [ -d build ]; then
  meson setup --reconfigure build --buildtype release -Dbuilt_in_models=true
else
  meson setup build --buildtype release -Dbuilt_in_models=true
fi
ninja -C build
ninja -C build install
ldconfig

cd /usr/local/src
if [ ! -d FFmpeg ]; then git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git; fi
cd FFmpeg
./configure --prefix=/opt/ffmpeg \
  --pkg-config-flags="--static" \
  --extra-cflags="-I/usr/local/include" \
  --extra-ldflags="-L/usr/local/lib" \
  --extra-libs="-lpthread -lm" \
  --bindir=/opt/ffmpeg/bin \
  --enable-gpl --enable-libx264 --enable-libx265 \
  --enable-libvpx --enable-libaom --enable-libass \
  --enable-libfreetype --enable-libmp3lame --enable-libopus \
  --enable-libvmaf
make -j"$(nproc)"
make install
echo 'export PATH=/opt/ffmpeg/bin:$PATH' | tee /etc/profile.d/ffmpeg.sh >/dev/null
export PATH=/opt/ffmpeg/bin:$PATH

# -------- 3) Verify ffmpeg build --------
echo "Verifying FFmpeg build..."
ffmpeg -hide_banner -version | grep -- --enable-libvmaf >/dev/null || { echo "❌ libvmaf not found in FFmpeg build"; exit 1; }
ffmpeg -hide_banner -filters | grep -qi libvmaf || { echo "❌ libvmaf filter missing"; exit 1; }

# -------- 4) Optional fallback models --------
echo "Fetching VMAF model files (optional fallback)..."
cd /usr/share
rm -rf vmaf
git clone --depth=1 https://github.com/Netflix/vmaf.git
mkdir -p /usr/share/model
ln -sf /usr/share/vmaf/model/vmaf_v0.6.1.json /usr/share/model/vmaf_v0.6.1.json
ln -sf /usr/share/vmaf/model/vmaf_4k_v0.6.1.json /usr/share/model/vmaf_4k_v0.6.1.json
echo "VMAF model files available at /usr/share/vmaf/model"

# -------- 5) Project setup --------
cd /workspace/VideoCompression
mkdir -p test_videos output_videos
python3 -m venv /workspace/venv
source /workspace/venv/bin/activate
pip install --upgrade pip
pip install numpy pandas opencv-python ffmpeg-python

# -------- 6) Runtime env helper --------
cat >/workspace/VideoCompression/runpod_env.sh <<'ENV'
#!/usr/bin/env bash
# Source this before running the project
source /workspace/venv/bin/activate
export PATH=/opt/ffmpeg/bin:$PATH
export PYTHONUNBUFFERED=1
ENV
chmod +x /workspace/VideoCompression/runpod_env.sh

# -------- 7) Config.ini check --------
if [ -f config.ini ]; then
  echo "Found config.ini ✅"
else
  echo "⚠️ No config.ini found. Please ensure it's present in the project root."
fi

echo "=== DONE: setup_runpod.sh ==="
echo "➡️ Next:"
echo "   source /workspace/VideoCompression/runpod_env.sh"
echo "   python matrix.py"
