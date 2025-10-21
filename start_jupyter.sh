#!/usr/bin/env bash
# === Start Jupyter (Lab or Notebook) inside RunPod ===
# Usage:
#   bash ~/start_jupyter.sh
# Or make executable:
#   chmod +x ~/start_jupyter.sh && ./start_jupyter.sh

# ----------------------------------------------------
# 1️⃣  Activate virtual environment
source /workspace/venv1/bin/activate

# ----------------------------------------------------
# 2️⃣  Ensure core packages are installed
pip install --quiet jupyterlab notebook ipykernel jupyter-archive

# ----------------------------------------------------
# 3️⃣  Register the venv kernel (if not already present)
python -m ipykernel install --user --name venv1 --display-name "Python (venv1)"

# ----------------------------------------------------
# 4️⃣  Configuration
JUPYTER_PORT=8889
LOG_FILE=~/jupyter.log

# Stop any existing Jupyter processes (optional)
pkill -f "jupyter-lab" >/dev/null 2>&1 || true
pkill -f "jupyter-notebook" >/dev/null 2>&1 || true

# ----------------------------------------------------
# 5️⃣  Start one version (uncomment whichever you prefer)

# ## --- Option A: JupyterLab ---
# nohup jupyter lab \
#   --ip=0.0.0.0 \
#   --port=$JUPYTER_PORT \
#   --no-browser \
#   --allow-root \
#   --ServerApp.token='' \
#   --ServerApp.websocket_ping_interval=60000 \
#   --ServerApp.websocket_ping_timeout=60000 \
#   > "$LOG_FILE" 2>&1 &

# ## --- Option B: Classic Notebook ---
# nohup jupyter notebook \
#   --ip=0.0.0.0 \
#   --port=$JUPYTER_PORT \
#   --no-browser \
#   --allow-root \
#   --NotebookApp.token='' \
#   --NotebookApp.websocket_ping_interval=60000 \
#   --NotebookApp.websocket_ping_timeout=60000 \
#   > "$LOG_FILE" 2>&1 &
jupyter notebook --ip=0.0.0.0 --port=8889 --no-browser --NotebookApp.token='' --allow-root

# ----------------------------------------------------
# 6️⃣  Final message
echo "✅ Jupyter server started on port $JUPYTER_PORT"
echo "📜 Logs: tail -f $LOG_FILE"
echo "🌐 Access via RunPod UI → 'App running on...' → port $JUPYTER_PORT"
