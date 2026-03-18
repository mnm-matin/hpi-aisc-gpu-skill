#!/bin/bash
#SBATCH --job-name=project_job
#SBATCH --account=aisc
#SBATCH --partition=aisc-batch
#SBATCH --constraint=ARCH:X86
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gres=gpu:h100:1
#SBATCH --time=04:00:00
#SBATCH --output=/sc/home/%u/logs/project_job_%j.out
#SBATCH --error=/sc/home/%u/logs/project_job_%j.err

set -euo pipefail

if [ -z "${SLURM_JOB_ID:-}" ]; then
  echo "ERROR: submit this file with sbatch; do not run it directly on lx01."
  exit 2
fi

echo "SLURM_JOB_ID=$SLURM_JOB_ID"
echo "HOSTNAME=$(hostname)"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-}"
echo "SLURM_TMPDIR=${SLURM_TMPDIR:-}"

REPO_ROOT="${PROJECT_REPO_ROOT:-$HOME/my-project}"
if [ ! -d "$REPO_ROOT" ]; then
  echo "ERROR: repo root not found at $REPO_ROOT (set PROJECT_REPO_ROOT)."
  exit 2
fi

WORKDIR="${SLURM_TMPDIR:-/tmp}/project_job_${SLURM_JOB_ID}"
mkdir -p "$WORKDIR"

cp -f "$HOME/.local/bin/uv" "$WORKDIR/uv"
chmod +x "$WORKDIR/uv"
UV="$WORKDIR/uv"

VENV="$WORKDIR/venv"
$UV venv --no-project "$VENV"
PY="$VENV/bin/python"

$UV run --no-project -p "$PY" python -c 'import sys; print("python", sys.version)'

# Install only what this job needs.
$UV pip install --python "$PY" --torch-backend=cu124 \
  torch==2.6.0 \
  torchvision==0.21.0 \
  numpy \
  tqdm

cd "$REPO_ROOT"

# Keep expensive model downloads in $HOME so they survive across jobs.
export HF_HOME="${HF_HOME:-$HOME/embeddings/hf}"
export HF_HUB_CACHE="${HF_HUB_CACHE:-$HF_HOME/hub}"
mkdir -p "$HF_HOME" "$HF_HUB_CACHE"

nvidia-smi || true

# Replace this with the project's real entry point.
$UV run --no-project -p "$PY" python -m your_package.train \
  --config configs/train.yaml \
  ${EXTRA_ARGS:-}