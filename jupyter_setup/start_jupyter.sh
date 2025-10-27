#!/usr/bin/env bash
# === Start Jupyter (Lab or Notebook) inside RunPod ===
# Usage:
#   bash ~/start_jupyter.sh
# Or make executable:
#   chmod +x ~/start_jupyter.sh && ./start_jupyter.sh

# --------------------------------------------------------
# Configuration
JUP_ENV="/workspace/venv-jupyter"
REQ_FILE="/workspace/req.txt"
JUPYTER_PORT=8889
LOG_FILE=/workspace/jupyter.log

# --------------------------------------------------------
# 1️⃣ Create venv if missing
if [ ! -d "$JUP_ENV" ]; then
  echo "🧩 Creating new Jupyter virtual environment at $JUP_ENV ..."
  python3 -m venv "$JUP_ENV"
  echo "✅ Virtual environment created."
else
  echo "🔄 Using existing Jupyter environment: $JUP_ENV"
fi

# --------------------------------------------------------
# 2️⃣ Activate the environment
source "$JUP_ENV/bin/activate"
# ----------------------------------------------------
# 2️⃣  Ensure core packages are installed
pip install --quiet --upgrade pip setuptools wheel
pip install --quiet jupyterlab notebook ipykernel jupyter-archive

# Patch conflicting pins and install dependencies
if [[ -f "$REQ_FILE" ]]; then
  echo "🩹 Patching known dependency conflicts ..."
  TMP_REQ="/tmp/req.jupyter.patched.txt"
  rm -f "$TMP_REQ"
  cp "$REQ_FILE" "$TMP_REQ"

  # 1) Remove ANY existing pins that can conflict (idempotent)
  sed -i -E '/^protobuf([<=>!]=|==|<|>| )/d' "$TMP_REQ"
  sed -i -E '/^grpcio(-status|-health-checking)?([<=>!]=|==|<|>| )/d' "$TMP_REQ"
  sed -i -E '/^click([<=>!]=|==|<|>| )/d' "$TMP_REQ"
  sed -i -E '/^markdown-mermaid-to-images([<=>!]=|==|<|>| )/d' "$TMP_REQ"

  # 2) Add pins compatible with TF 2.19.1 (protobuf < 6)
  {
    echo 'protobuf>=5.26.1,<6'
    echo 'grpcio==1.71.2'
    echo 'grpcio-status==1.71.2'
    echo 'grpcio-health-checking==1.71.2'
    echo 'click>=8.1.3'   # keep Flask 3.1.x happy
  } >> "$TMP_REQ"

  # (Optional) Show exactly what will be used
  echo "🔎 Effective pins:"
  grep -nE '^(protobuf|grpcio|click|markdown-mermaid-to-images)' "$TMP_REQ" || true

  echo "📦 Installing Notebook dependencies from patched requirements..."
  pip install --upgrade -r "$TMP_REQ"
else
  echo "⚠️  No requirements file found at $REQ_FILE — skipping dependency install."
fi




jupyter notebook --ip=0.0.0.0 --port=8889 --no-browser --NotebookApp.token='' --allow-root

