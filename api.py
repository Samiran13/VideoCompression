from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
from pathlib import Path
import shutil, subprocess, os

app = FastAPI(title="VideoCompression API")

ROOT = Path(__file__).resolve().parent
TEST_VIDEOS = ROOT / "test_videos"
RESULTS = ROOT / "results"
TEST_VIDEOS.mkdir(exist_ok=True)
RESULTS.mkdir(exist_ok=True)

def run_matrix(extra_env=None):
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    proc = subprocess.run(
        ["python", "matrix.py"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr

@app.post("/upload")
async def upload_video(file: UploadFile = File(...)):
    suffix = Path(file.filename).suffix.lower()
    if suffix not in {".mp4", ".mov", ".webm", ".mvi", ".mkv", ".avi"}:
        raise HTTPException(400, f"Unsupported format: {suffix}")
    dest = TEST_VIDEOS / Path(file.filename).name
    with dest.open("wb") as f:
        shutil.copyfileobj(file.file, f)
    return {"ok": True, "saved_as": str(dest)}

@app.post("/run")
async def run_matrix_endpoint(background: bool = False, vmaf_model_path: str | None = None, bg: BackgroundTasks = None):
    extra = {}
    if vmaf_model_path:
        extra["LIBVMAF_MODEL_PATH"] = vmaf_model_path
    if background:
        if bg is None:
            raise HTTPException(500, "BackgroundTasks not available")
        def task():
            code, out, err = run_matrix(extra)
            (RESULTS / "last_run.out").write_text(out)
            (RESULTS / "last_run.err").write_text(err)
        bg.add_task(task)
        return {"ok": True, "message": "matrix.py started in background"}
    code, out, err = run_matrix(extra)
    return JSONResponse({
        "ok": code == 0,
        "code": code,
        "stdout": out[-4000:],
        "stderr": err[-4000:],
    })
