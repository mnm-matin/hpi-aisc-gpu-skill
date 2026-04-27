# Cluster Script Pre-Submit Checklist

Use this checklist before running any script on the HPI Scientific Compute cluster, including `sbatch` jobs and helper scripts launched through `ssh hpi-cluster` or a Run Node. Mark every item as `pass`, `n/a`, or `blocked`. If anything is `blocked`, stop and ask the user or the helpdesk before executing.

## Execution target

- The script will not run training, evaluation, installs, plotting, preprocessing, model inference, large downloads, or VS Code/Jupyter servers on a login node.
- Login-node commands are limited to lightweight admin and I/O: `sbatch`, `squeue`, `sacct`, `scancel`, `scontrol`, `rsync`, `scp`, `tail`, `less`, and small filesystem checks.
- Run Nodes are used only for lightweight helpers, file management, automation, VS Code server, or job submission, not compute or heavy transfers.
- Any compute work runs through Slurm and the script exits early when `SLURM_JOB_ID` is missing.

## Account, partition, and resources

- The Slurm account was checked with `saccount` unless the correct account is already known for this project.
- The selected partition matches the workload and access rights; `aisc-*` partitions are used only when appropriate for AISC access and preemption is acceptable.
- The first unproven run requests one GPU at most, has a realistic time limit, and does not leave GPUs allocated while idle.
- CPU, memory, GPU, node count, and wall-time requests are justified by the task rather than copied from a larger run.
- Jobs that install wheels or compile native dependencies request `ARCH:X86`, and multiple required constraints are combined in one expression.

## Paths and storage

- The repo path, data path, output path, and log path are explicit; the script does not infer the repo from `${BASH_SOURCE[0]}` under Slurm.
- Durable datasets and outputs go to project storage when available, not `$HOME`; `$HOME` is reserved for code, small configs, credentials, logs, and small caches.
- Scratch usage is temporary and intentional: `$SLURM_SCRATCH` or `$TMP` for per-job local scratch, `/sc/scratch` only for active temporary shared data.
- The script creates required directories, avoids overwriting important outputs accidentally, and cleans temporary files that do not need to persist.

## Downloads, transfers, and network use

- The script does not download a large dataset, crawl URL lists, use torrents, or move large artifacts without explicit user approval.
- `references/dataset-downloads.md` has been read for any dataset download, crawler, torrent, or non-trivial transfer.
- `sc-helpdesk@hpi.de` has been contacted before large internet transfers, full crawls, multi-terabyte ingestion, or high-concurrency transfer plans.
- Download concurrency is explicitly capped, resumable, logged, and tested with a tiny pilot before any larger run.
- URL-list datasets are treated as web crawls; an intermediate-machine plan has been considered for full materialization.

## Environment and dependencies

- The script uses `uv`; it does not call `python`, `python3`, or `pip` directly.
- Dependency installation happens inside a Slurm allocation or job-local environment, never on a login node.
- The script copies or uses `$HOME/.local/bin/uv` intentionally and creates an isolated environment such as `uv venv --no-project` when needed.
- Large caches are placed in project or scratch storage, not silently under `$HOME`.

## Secrets and access

- API tokens, SSH keys, passwords, private URLs, and Hugging Face tokens are not embedded in scripts, command lines, logs, or committed files.
- Gated Hugging Face assets or shared HF caches follow `references/huggingface-auth.md`.
- Remote commands are quoted so local shell expansion cannot leak or corrupt values.

## Logs, monitoring, and failure handling

- The Slurm script includes `set -euo pipefail`, explicit `--output`, and explicit `--error` paths.
- After submission, the real `StdOut` and `StdErr` paths will be read with `scontrol show job` instead of guessed.
- Progress, key parameters, versions, and output locations are logged well enough to debug failures.
- Long monitoring is done with short snapshot commands or `tmux` on the cluster, not fragile local polling loops.
- A stuck, misconfigured, or no-longer-needed job will be cancelled promptly with `scancel`.

## Final gate

- The exact command that will execute on the cluster has been reviewed.
- Any risky action, especially a large download or expensive multi-GPU run, has explicit user approval.
- No checklist item is `blocked`.
