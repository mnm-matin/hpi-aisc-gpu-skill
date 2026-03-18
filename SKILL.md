---
name: hpi-aisc-gpu
description: Use when working on the HPI Scientific Compute or AISC SLURM cluster, including VPN setup, `ssh hpi-cluster`, H100 GPU jobs, `sbatch` or `squeue` or `sacct`, remote log inspection, and writing safe cluster job scripts for new projects. Triggers include requests to run work on HPI, use the cluster, submit a SLURM job, request an H100, monitor a job, connect to `hpi-cluster`, or use AISC GPUs.
---

# HPI AISC GPU Cluster

## Use this skill when

- The user wants to run experiments on the HPI Scientific Compute or AISC infrastructure.
- The task involves `ssh hpi-cluster`, SLURM jobs, H100 GPUs, VPN access, or remote log inspection.
- A project needs a new `.sh` or `.sbatch` submission script for this cluster.

## Non-negotiable rules

- `ssh hpi-cluster` lands on the SLURM login node `lx01`. Never run installs, downloads, training, evaluation, plotting, or model code there.
- The login node is for lightweight admin and I/O only: `sbatch`, `squeue`, `sacct`, `scancel`, `scontrol`, `rsync`, `scp`, `tail`, `less`.
- Start with 1 GPU unless the user already has a stable job. Scale up only after the workflow is proven. Do not leave GPUs allocated while idle. Never request more than 8 H100s.
- Prefer `#SBATCH --constraint=ARCH:X86` for jobs that install wheels or compile native dependencies. ARM plus L40 nodes can break builds.
- Use `uv`, never `python`, `python3`, or `pip` directly.
- All user-specific values (username, paths, SSH key name) live in `~/.ssh/config` and the user's VPN credential files — not in this skill. See **Prerequisites** below.

## Prerequisites (per-user setup)

Each user must have these in place before the skill's workflows apply:

1. **VPN** — the `.ovpn` from HPI, configured and working. See `references/vpn-setup.md` for full setup (OpenVPN, Tunnelblick, split-tunnel tip, SSH KEX fix).
2. **SSH alias** — a `Host hpi-cluster` block in `~/.ssh/config` with your username, key, and `KexAlgorithms curve25519-sha256` (see `references/vpn-setup.md`).
3. **`uv` on the cluster** — installed at `$HOME/.local/bin/uv` (one-time setup via `srun`).

## VPN

The cluster is behind a VPN. Before any `ssh hpi-cluster`, confirm the tunnel is up (`pgrep -af openvpn`). Full connection instructions, the macOS `osascript` trick for non-interactive terminals, and the SSH KEX fix are in `references/vpn-setup.md`.

## Default workflow

1. Confirm VPN is up (see above). Start it if not.
2. Prepare or edit the SLURM script locally.
3. Submit with `ssh hpi-cluster 'cd <repo> && sbatch --parsable <script>'`.
4. Immediately query the real `StdOut` and `StdErr` paths with `scontrol show job`.
5. Monitor with short snapshot commands, not long blocking loops.
6. Tail the exact log files or sync them locally.
7. Cancel jobs that are no longer needed.

## Writing job scripts

- Read `references/hpi-cluster-workflow.md` before writing a new script.
- Start from `assets/slurm_uv_h100_job.sh`.
- Include `set -euo pipefail`.
- Include `#SBATCH -A aisc`, `#SBATCH -p aisc-batch`, explicit `--output`, and explicit `--error`.
- Include `#SBATCH --constraint=ARCH:X86` unless there is a good reason not to.
- Use `#SBATCH --gres=gpu:h100:1` when the job specifically needs H100s; otherwise use the loosest request that still matches the task.
- Exit early if `SLURM_JOB_ID` is missing so the script cannot be run directly on `lx01`.
- Build a job-local workdir under `${SLURM_TMPDIR:-/tmp}`.
- Copy `uv` from `$HOME/.local/bin/uv` into the workdir and create a job-local venv with `uv venv --no-project`.
- Use an explicit repo root env var or fixed path. Do not infer it from `${BASH_SOURCE[0]}` because SLURM runs a copied spool file.
- If the job accesses gated Hugging Face assets or large shared caches, read `references/huggingface-auth.md`.
- If the run should be reproducible later, read `references/experiment-tracking.md` and persist the minimal metadata/metrics/artifacts schema.

## Monitoring jobs

Use this pattern:

```bash
JOB_ID=$(ssh hpi-cluster 'cd ~/repo && sbatch --parsable script.sh')
ssh hpi-cluster "scontrol show job $JOB_ID -o | tr ' ' '\n' | grep -E 'StdOut=|StdErr='"
ssh hpi-cluster "squeue -j $JOB_ID -h -o '%T %M %R' || true"
ssh hpi-cluster "sacct -j $JOB_ID --format=State,Elapsed,ExitCode,MaxRSS,NodeList -n --parsable2"
```

If a live view is necessary, use `tmux` on the cluster rather than a long-running local polling loop.

## References

- VPN setup, SSH KEX fix, split-tunnel tip: `references/vpn-setup.md`
- Commands, pitfalls, and safety details: `references/hpi-cluster-workflow.md`
- Hugging Face auth and cache conventions: `references/huggingface-auth.md`
- Lightweight experiment tracking schema: `references/experiment-tracking.md`
- Starting submission script: `assets/slurm_uv_h100_job.sh`