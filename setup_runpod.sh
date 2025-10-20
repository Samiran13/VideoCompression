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

# -------- 2) Build & install libvmaf + FFmpeg (with --enable-libvmaf) --------
echo "Building FFmpeg with libvmaf ..."
cd /usr/local/src
if [ ! -d vmaf ]; then git clone --depth=1 https://github.com/Netflix/vmaf.git; fi
cd vmaf/libvmaf

# ✅ KEY CHANGE: enable built-in models so libvmaf works without model=... in ffmpeg
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

# -------- 4) (Optional) Download Netflix VMAF models as files --------
# Not required anymore for built-ins, but useful as a fallback and for advanced models
echo "Fetching VMAF model files (optional fallback)..."
cd /usr/share
rm -rf vmaf
git clone --depth=1 https://github.com/Netflix/vmaf.git
mkdir -p /usr/share/model
ln -sf /usr/share/vmaf/model/vmaf_v0.6.1.json /usr/share/model/vmaf_v0.6.1.json
ln -sf /usr/share/vmaf/model/vmaf_4k_v0.6.1.json /usr/share/model/vmaf_4k_v0.6.1.json
echo "VMAF models (files) available at /usr/share/vmaf/model"

# -------- 5) Project setup --------
cd /workspace/VideoCompression
mkdir -p test_videos output_videos
python3 -m venv /workspace/venv1
source /workspace/venv1/bin/activate
pip install --upgrade pip
pip install numpy pandas opencv-python ffmpeg-python

# -------- 6) Create a 2s test video --------
if [ ! -f test_videos/test.mp4 ]; then
  ffmpeg -hide_banner -y -f lavfi -i "smptebars=size=640x360:rate=30" -t 2 -pix_fmt yuv420p test_videos/test.mp4
fi

# -------- 7) Create runtime env helper --------
cat >/workspace/VideoCompression/runpod_env.sh <<'ENV'
#!/usr/bin/env bash
# Source this before running the project
source /workspace/venv1/bin/activate
export PATH=/opt/ffmpeg/bin:$PATH
export PYTHONUNBUFFERED=1
# These are optional now (built-ins are compiled). Keep for advanced usage:
export VMAF_MODEL="/usr/share/vmaf/model/vmaf_v0.6.1.json"
export VMAF_MODEL_PATH="/usr/share/vmaf/model"
ENV
chmod +x /workspace/VideoCompression/runpod_env.sh

# -------- 8) Quick VMAF sanity test (NO model path) --------
echo "Running quick VMAF sanity test (built-ins)..."
set +e
ffmpeg -hide_banner \
  -i test_videos/test.mp4 \
  -i test_videos/test.mp4 \
  -lavfi "[0:v][1:v]libvmaf=log_fmt=json:log_path=vmaf_sanity.json" \
  -f null - >/tmp/vmaf_sanity.log 2>&1
rc=$?
set -e
if [ $rc -eq 0 ]; then
  echo "✅ VMAF filter works WITHOUT model path (built-ins active). See vmaf_sanity.json"
else
  echo "⚠️ Built-in test failed. Check /tmp/vmaf_sanity.log. You can still use model=path=/usr/share/vmaf/model/vmaf_v0.6.1.json"
fi

# -------- 9) Config.ini check --------
if [ -f config.ini ]; then
  echo "Found config.ini ✅"
else
  echo "⚠️ No config.ini found. Please ensure it’s present in the project root."
fi

echo "=== DONE: setup_runpod.sh ==="
echo "➡️ Next:"
echo "   source /workspace/VideoCompression/runpod_env.sh"
echo "   python matrix.py"
