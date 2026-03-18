# HPI Cluster Workflow

## Access

- `ssh hpi-cluster` uses the local SSH alias and lands on the HPI Scientific Compute login node `lx01`.
- The cluster is behind a VPN. Always confirm the tunnel is up before SSH.
- Official docs:
  - SCI docs: `https://docs.sc.hpi.de/`
  - AISC docs: `https://aisc.hpi.de/doc/`
  - VPN docs: `https://docs.sc.hpi.de/VPN/`
  - SLURM basics: `https://docs.sc.hpi.de/cluster/SLURM/Basics/`

## Per-user prerequisites

Before using this workflow, each user needs:

1. **VPN config** — the `.ovpn` file from HPI (typically `SC_User.ovpn`). For automated auth, create a `vpn-auth.txt` alongside it with your HPI username (line 1) and password (line 2), and add `auth-user-pass vpn-auth.txt` to the `.ovpn` if not already present. Keep both files in one directory.
2. **SSH config** — an entry in `~/.ssh/config`:
   ```
   Host hpi-cluster
       HostName hpc.sci.hpi.de
       User <your-hpi-username>
       IdentityFile ~/.ssh/<your-key>
       IdentitiesOnly yes
       KexAlgorithms curve25519-sha256
   ```
3. **`uv` on the cluster** — install once via `srun` into `$HOME/.local/bin/uv`.

## Connecting the VPN

Check if already running:

```bash
pgrep -af openvpn
```

### Option A: Tunnelblick (macOS GUI)

Install your `.ovpn` as a Tunnelblick profile (`.tblk`). Connect via the menu bar icon, or programmatically:

```bash
osascript -e 'tell application "Tunnelblick" to connect "<profile-name>"'
```

### Option B: CLI OpenVPN — macOS (agent-friendly)

On macOS, `sudo` in a non-interactive terminal (VS Code, AI agents) cannot prompt for a password. Use `osascript` to trigger the native macOS password dialog:

```bash
osascript -e 'do shell script "openvpn --config /path/to/your.ovpn --cd /path/to/ovpn-dir --daemon --log /tmp/openvpn-hpi.log" with administrator privileges'
```

### Option C: CLI OpenVPN — Linux

```bash
sudo openvpn --config /path/to/your.ovpn --cd /path/to/ovpn-dir --daemon --log /tmp/openvpn-hpi.log
```

Key details:
- `--cd` must point to the directory containing both the `.ovpn` and `vpn-auth.txt` (the config references `vpn-auth.txt` by relative path).
- `--daemon` backgrounds the process after connection.
- `--log /tmp/openvpn-hpi.log` writes logs (root-owned; read with `sudo cat` or osascript).

> **Split-tunnel tip**: The default HPI `.ovpn` routes *all* traffic through the VPN. If you only need cluster access, add these two lines to your `.ovpn`:
> ```
> pull-filter ignore "redirect-gateway"
> route 10.130.0.0 255.255.0.0
> ```
> This sends only `10.130.0.0/16` through the tunnel and leaves the rest of your internet untouched.

### Verify connectivity

```bash
ssh -o ConnectTimeout=5 hpi-cluster hostname
```

Expected output: `lx01`.

> **SSH KEX fix**: OpenSSH ≥ 9.x defaults to `sntrup761x25519` (post-quantum) key exchange. Its packets exceed the VPN tunnel MTU, causing SSH to hang at "expecting SSH2_MSG_KEX_ECDH_REPLY". Add `KexAlgorithms curve25519-sha256` to the `hpi-cluster` block in `~/.ssh/config`.

### Disconnect

**macOS:**
```bash
osascript -e 'do shell script "killall openvpn" with administrator privileges'
```
Or disconnect from the Tunnelblick menu bar.

**Linux:**
```bash
sudo killall openvpn
```

## Login node safety

Treat `lx01` as admin-only.

Allowed there:

- `sbatch`, `squeue`, `sacct`, `scancel`, `scontrol`
- `rsync`, `scp`
- `tail`, `less`
- small `ls`, `du`, `rm`

Never do this on `lx01`:

- `uv venv`, `uv pip install`, `pip install`
- `uv run -m ...` for training, evaluation, embedding generation, or plotting
- model inference, `torch`, `transformers`, or other heavy Python work
- large downloads or dataset preparation
- VS Code remote server, Jupyter, or JetBrains remote sessions

If the user needs an interactive compute shell, use `srun --pty ...`, not the login node.

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
- At this site, never allocate more than 8 H100s.
- If the job depends on x86 wheels or compiled extensions, include `#SBATCH --constraint=ARCH:X86`.
- Use `#SBATCH --gres=gpu:h100:N` when the workload specifically needs H100s.

## Job script pattern

Use these defaults unless the project has stronger requirements:

```bash
#SBATCH --account=aisc
#SBATCH --partition=aisc-batch
#SBATCH --constraint=ARCH:X86
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gres=gpu:h100:1
#SBATCH --time=04:00:00
```

Operational pattern:

- `set -euo pipefail`
- guard on `SLURM_JOB_ID`
- explicit repo root env var such as `PROJECT_REPO_ROOT`
- workdir under `${SLURM_TMPDIR:-/tmp}`
- copy `uv` from `$HOME/.local/bin/uv`
- `uv venv --no-project`
- install only the packages the job needs
- keep caches under `$HOME` when downloads are expensive

## Common pitfalls

- Quote remote commands so local shell expansion does not happen by accident.
- `sbatch --export=...` splits values on commas. Prefer positional args or set complex env vars inside the script.
- SLURM runs a copied spool version of the script, so `${BASH_SOURCE[0]}` is not a reliable repo locator.
- Mixed architecture scheduling can surface obscure build failures. If in doubt, pin `ARCH:X86`.

## Support

- Scientific Compute helpdesk: `sc-helpdesk@hpi.de`
- AISC technical helpdesk: `aisc-helpdesk@hpi.de`
- AISC organizational support: `ki-servicezentrum@hpi.de`
- SCI Slack: `#sc-announce` and `#sc-discuss`