# 🚀 RunPod Auto Setup for VideoCompression

This setup ensures FFmpeg, libvmaf, and VMAF models are correctly installed on RunPod.

---

## 🧩 Prerequisites
A fresh RunPod pod (Ubuntu 24.04 base template) with access to `/workspace`.

---

## 🪜 Setup Steps

1. **Clone the repository**
   ```bash
   cd /workspace
   git clone https://github.com/GarlicBee/VideoCompression.git
   cd VideoCompression
   ```

2. **Run the setup script**
   ```bash
   bash setup_runpod.sh
   ```

   This will:
   - Build FFmpeg with libvmaf support
   - Install Netflix VMAF models
   - Create and activate a Python venv
   - Install all Python dependencies
   - Generate a test video and verify VMAF

3. **Activate environment**
   ```bash
   source runpod_env.sh
   ```

4. **Run the matrix test**
   ```bash
   python matrix.py
   ```

