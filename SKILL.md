---
name: hpi-aisc-gpu
description: Use when working on the HPI Scientific Compute or AISC SLURM cluster, including VPN setup, `ssh hpi-cluster`, H100 GPU jobs, `sbatch` or `squeue` or `sacct`, remote log inspection, and writing safe cluster job scripts for new projects. Triggers include requests to run work on HPI, use the cluster, submit a SLURM job, request an H100, monitor a job, connect to `hpi-cluster`, or use AISC GPUs.
---

# HPI AISC GPU Cluster

This skill is aligned with the HPI Scientific Compute docs at `https://docs.sc.hpi.de/`, especially the Terms of Usage, AI Usage Guidelines, Slurm, Storage, Data Transfer, VPN, SSH, and AISC pages.

## Use this skill when

- The user wants to run experiments on the HPI Scientific Compute or AISC infrastructure.
- The task involves `ssh hpi-cluster`, SLURM jobs, H100 GPUs, VPN access, or remote log inspection.
- A project needs a new `.sh` or `.sbatch` submission script for this cluster.

## Non-negotiable rules

- `ssh hpi-cluster` should point at `hpc.sci.hpi.de` and land on one of the cluster login nodes. Never run installs, downloads, training, evaluation, plotting, VS Code servers, or model code there.
- The login node is for lightweight admin and I/O only: `sbatch`, `squeue`, `sacct`, `scancel`, `scontrol`, `rsync`, `scp`, `tail`, `less`.
- Use Run Nodes (`rx01.hpc.sci.hpi.de`, `rx02.hpc.sci.hpi.de`) only for lightweight helper scripts, file management, automation, VS Code server, and job submission. They are limited shared resources, not compute nodes.
- Start with 1 GPU unless the user already has a stable job. Scale up only after the workflow is proven. Do not leave GPUs allocated while idle. Never request more than 8 GPUs.
- Prefer `#SBATCH --constraint=ARCH:X86` for jobs that install wheels or compile native dependencies. ARM plus L40 nodes can break builds.
- Use `uv`, never `python`, `python3`, or `pip` directly.
- Use `saccount` to discover the correct Slurm account. Do not assume `aisc` or `aisc-batch` unless the task is actually using AISC access for an approved project.
- Before executing any script on the cluster, including `sbatch` submissions and helper scripts run through `ssh hpi-cluster` or a Run Node, check it against `references/pre-submit-checklist.md`. Stop if any item is blocked.
- For large downloads or transfers, read `references/dataset-downloads.md` first. Before moving large data, contact `sc-helpdesk@hpi.de`; do not flood the shared uplink or run URL-list crawls from the cluster.
- User-specific VPN, SSH, and credential setup belongs in local config, not committed files. For per-user setup, see `references/vpn-setup.md`.

## Default workflow

1. Confirm VPN is up. Start it using `references/vpn-setup.md` if not.
2. Prepare or edit the SLURM script locally.
3. Check `saccount` if the correct Slurm account is not already known.
4. Review the exact script and cluster command against `references/pre-submit-checklist.md`.
5. Submit with `ssh hpi-cluster 'cd <repo> && sbatch --parsable <script>'` only when every checklist item is `pass` or `n/a`.
6. Immediately query the real `StdOut` and `StdErr` paths with `scontrol show job`.
7. Monitor with short snapshot commands, not long blocking loops.
8. Tail the exact log files or sync them locally.
9. Cancel jobs that are no longer needed.

## Writing job scripts

- Read `references/hpi-cluster-workflow.md` before writing a new script.
- Check `references/pre-submit-checklist.md` before running or submitting the script on the cluster.
- Start from `assets/slurm_uv_h100_job.sh`.
- Include `set -euo pipefail`.
- Include `#SBATCH -A <account>`, a partition that matches the workload, explicit `--output`, and explicit `--error`.
- Include `#SBATCH --constraint=ARCH:X86` unless there is a good reason not to.
- Use `#SBATCH --gpus=1` for generic GPU work. If the job specifically needs H100-class hardware, verify the current features with `sinfo`/`scontrol` and use documented constraints such as `GPU_GEN:HOPPER`, `GPU_MEM:80GB`, or the live cluster's GPU SKU feature.
- Exit early if `SLURM_JOB_ID` is missing so the script cannot be run directly on a login node.
- Build a job-local workdir under `${SLURM_SCRATCH:-${TMP:-/tmp}}`. If fast local scratch is required, request a node with `SCRATCH:NVME` or `SCRATCH:SSD` in the single combined `--constraint` expression.
- Copy `uv` from `$HOME/.local/bin/uv` into the workdir and create a job-local venv with `uv venv --no-project`.
- Use an explicit repo root env var or fixed path. Do not infer it from `${BASH_SOURCE[0]}` because SLURM runs a copied spool file.
- If the job downloads a dataset, crawls URLs, uses torrents, or transfers more than a small amount of data, read `references/dataset-downloads.md` before writing or submitting it.
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

- VPN setup, MTU troubleshooting, split-tunnel tip: `references/vpn-setup.md`
- Commands, pitfalls, and safety details: `references/hpi-cluster-workflow.md`
- Script pre-submit safety checklist: `references/pre-submit-checklist.md`
- Large dataset downloads and transfers: `references/dataset-downloads.md`
- Hugging Face auth and cache conventions: `references/huggingface-auth.md`
- Lightweight experiment tracking schema: `references/experiment-tracking.md`
- Starting submission script: `assets/slurm_uv_h100_job.sh`
