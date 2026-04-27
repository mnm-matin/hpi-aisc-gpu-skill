# HPI Cluster Workflow

## Access

- `ssh hpi-cluster` should use a local SSH alias for `hpc.sci.hpi.de` and lands on one of the HPI Scientific Compute login nodes.
- The cluster is behind a VPN. Always confirm the tunnel is up before SSH.
- Official docs:
  - SCI docs: `https://docs.sc.hpi.de/`
  - Terms of Usage: `https://docs.sc.hpi.de/Terms-of-Usage/`
  - AI Usage Guidelines: `https://docs.sc.hpi.de/AI-Usage-Guidelines/`
  - AISC docs: `https://docs.sc.hpi.de/aisc/`
  - VPN docs: `https://docs.sc.hpi.de/VPN/`
  - SLURM basics: `https://docs.sc.hpi.de/cluster/SLURM/Basics/`
  - Login nodes: `https://docs.sc.hpi.de/cluster/Resources/Login-Nodes/`
  - Run nodes: `https://docs.sc.hpi.de/cluster/Resources/Run-Nodes/`
  - Data transfer: `https://docs.sc.hpi.de/cluster/Storage/Data-Transfer/`

## VPN and SSH setup

Configure the VPN, `hpi-cluster` SSH alias, optional split tunnel, and local MTU troubleshooting from `references/vpn-setup.md`. User-specific values such as usernames, key paths, VPN profiles, and credential files should stay in local config.

Verify connectivity before submitting jobs:

```bash
ssh -o ConnectTimeout=5 hpi-cluster hostname
```

Expected output: a login-node hostname. The docs describe `hpc.sci.hpi.de` as the hostname that automatically connects to one of the available login nodes.

> **VPN MTU troubleshooting**: The official VPN troubleshooting page documents SSH timeouts as a possible MTU issue and recommends adding `tun-mtu 1400` to the `.ovpn` file.
>
> If SSH still hangs at key exchange on a local OpenSSH client, adding `KexAlgorithms curve25519-sha256` to the `hpi-cluster` block in `~/.ssh/config` has also helped locally.

## Login node safety

Treat login nodes as admin-only.

The exact login node may vary; this rule applies to all login nodes reached through `hpc.sci.hpi.de`.

Allowed there:

- `sbatch`, `squeue`, `sacct`, `scancel`, `scontrol`
- `rsync`, `scp`
- `tail`, `less`
- small `ls`, `du`, `rm`

Never do this on login nodes:

- `uv venv`, `uv pip install`, `pip install`
- `uv run -m ...` for training, evaluation, embedding generation, or plotting
- model inference, `torch`, `transformers`, or other heavy Python work
- large downloads or dataset preparation
- VS Code remote server, Jupyter, or JetBrains remote sessions

If the user needs an interactive compute shell, use `srun --pty ...`, not the login node.

If the user needs a lightweight long-lived helper process, use a Run Node (`rx01.hpc.sci.hpi.de` or `rx02.hpc.sci.hpi.de`). Run Nodes are capped at 8 GiB RAM and 4 CPU cores per user and must not be used for heavy compute or large downloads.

## Large data transfers and dataset downloads

Read `references/dataset-downloads.md` before writing a job that downloads datasets, crawls URL lists, uses torrents, or moves large artifacts.

Key rules from the HPI docs:

- Contact `sc-helpdesk@hpi.de` before large transfers.
- The cluster shares a 10 Gbit/s internet uplink with all users and the HPI campus network.
- Large internet transfers must run on compute nodes, not login nodes.
- Jobs that flood the network may be killed as Terms-of-Usage violations.
- URL-list datasets such as GRIT should normally be crawled through an intermediate machine and transferred as staged shards, rather than fetched directly from the cluster at high concurrency.

## Submit jobs

Prefer submission from the local machine through SSH so the workflow is reproducible and visible:

```bash
ssh hpi-cluster 'cd ~/my-project && sbatch --parsable path/to/job.sbatch'
```

Use `--parsable` so the caller gets a stable job id.

After submission, ask SLURM for the real log paths instead of guessing them:

```bash
ssh hpi-cluster "scontrol show job $JOB_ID -o | tr ' ' '\n' | grep -E 'StdOut=|StdErr='"
```

## Monitor jobs

Prefer short snapshot checks you can re-run:

```bash
ssh hpi-cluster "squeue -j $JOB_ID -h -o '%T %M %R'"
ssh hpi-cluster "sacct -j $JOB_ID --format=State,Elapsed,ExitCode,MaxRSS,NodeList -n --parsable2"
```

Tail exact log files once you know their paths:

```bash
ssh hpi-cluster "tail -n 80 /path/to/stdout.log"
ssh hpi-cluster "tail -n 80 /path/to/stderr.log"
```

If a live follow view is necessary, open `tmux` on the cluster:

```bash
ssh hpi-cluster
tmux new -s job_$JOB_ID
tail -f /path/to/stdout.log
```

For local inspection in VS Code, sync logs down instead of holding a remote tail open:

```bash
mkdir -p cluster/_remote_logs
rsync -az hpi-cluster:~/experiments/logs/ cluster/_remote_logs/
```

## Resource hygiene

- Default to 1 GPU while validating a new pipeline.
- Only scale once the job is stable and the user asked for it.
- Release GPUs quickly when a run is blocked or idle.
- At this site, never allocate more than 8 GPUs.
- If the job depends on x86 wheels or compiled extensions, include `#SBATCH --constraint=ARCH:X86`.
- Use `#SBATCH --gpus=N` for generic GPU work. If H100-class hardware is required, verify current features with `sinfo`/`scontrol` and use documented constraints such as `GPU_GEN:HOPPER`, `GPU_MEM:80GB`, or the live cluster's GPU SKU feature.
- Keep requested time limits realistic; shorter accurate jobs are easier for Slurm backfill to schedule.

## Job script pattern

Use these defaults unless the project has stronger requirements:

```bash
#SBATCH --account=<account>
#SBATCH --partition=gpu-batch
#SBATCH --constraint=ARCH:X86
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gpus=1
#SBATCH --time=04:00:00
```

Use `aisc-batch` only for AISC workloads or when you intentionally choose preemptible AISC hardware. External AISC users can use only `aisc-*` partitions; HPI users may use AISC partitions when nodes are idle, but jobs may be preempted by AISC-funded workloads.

Operational pattern:

- `set -euo pipefail`
- guard on `SLURM_JOB_ID`
- explicit repo root env var such as `PROJECT_REPO_ROOT`
- workdir under `${SLURM_SCRATCH:-${TMP:-/tmp}}`
- copy `uv` from `$HOME/.local/bin/uv`
- `uv venv --no-project`
- install only the packages the job needs
- keep large caches and datasets in project storage when downloads are expensive; keep `$HOME` under the 200 GB quota

## Common pitfalls

- Quote remote commands so local shell expansion does not happen by accident.
- `sbatch --export=...` splits values on commas. Prefer positional args or set complex env vars inside the script.
- SLURM runs a copied spool version of the script, so `${BASH_SOURCE[0]}` is not a reliable repo locator.
- Mixed architecture scheduling can surface obscure build failures. If in doubt, pin `ARCH:X86`.
- Multiple `--constraint` flags do not combine; the last one wins. Put all required features in one expression such as `ARCH:X86&SCRATCH:NVME`.
- `SLURM_SCRATCH` exists only when the allocated node has local scratch. Request `SCRATCH:NVME` or `SCRATCH:SSD` when the job depends on local scratch.

## Support

- Scientific Compute helpdesk: `sc-helpdesk@hpi.de`
- AISC technical helpdesk: `aisc-helpdesk@hpi.de`
- AISC organizational support: `ki-servicezentrum@hpi.de`
