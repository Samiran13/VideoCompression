# 🚀 RunPod Auto Setup for VideoCompression

This setup ensures FFmpeg, libvmaf, and VMAF models are correctly installed on RunPod.

---

## 🧩 Prerequisites
A fresh RunPod pod (Ubuntu 24.04 base template) with access to `/workspace`.

---

## 🪜 Setup Steps

1. **Run the setup script**
   ```bash
   cd /workspace
   bash setup_runpod.sh
   ```

   This will:
   - Build FFmpeg with libvmaf support
   - Install Netflix VMAF models

2. **Start jupyter and Install dependencies**
   ```bash
   bash start_jupyter.sh
   ```

