#!/usr/bin/env bash
set -euo pipefail

: "${MODE:=api}"          # api | run | jupyter
: "${JUPYTER_PORT:=8889}"
: "${JUPYTER_TOKEN:=}"
: "${JUPYTER_DIR:=/workspace}"   # or /workspace if you mount that

echo "FFmpeg:"
ffmpeg -hide_banner -version | head -n 3 || true
echo "Filter check:"
ffmpeg -hide_banner -filters | grep -i vmaf || true
echo "LIBVMAF_MODEL_PATH=${LIBVMAF_MODEL_PATH:-}"

if [ "$MODE" = "jupyter" ]; then
  jupyter lab --ip=0.0.0.0 --port="${JUPYTER_PORT}" --no-browser \
    --NotebookApp.token="${JUPYTER_TOKEN}" --NotebookApp.password='' \
    --NotebookApp.notebook_dir="${JUPYTER_DIR}"
elif [ "$MODE" = "run" ]; then
  python /app/matrix.py
else
  uvicorn api:app --host 0.0.0.0 --port 8000
fi
