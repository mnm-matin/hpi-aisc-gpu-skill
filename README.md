# hpi-aisc-gpu skill

A VS Code / Copilot **agent skill** for working safely on the HPI Scientific Compute and AI Service Center (AISC) SLURM cluster. It teaches the agent the non-negotiable rules (no installs on the login node, VPN, partition / account flags, ARM-vs-X86 quirks, monitoring patterns) and points it at compact reference docs for VPN setup, Hugging Face auth, and lightweight experiment tracking.

The skill activates automatically whenever the agent's task mentions `ssh hpi-cluster`, `sbatch`, H100s, AISC, etc.

## Install

The skill is consumed by an agent that scans `~/.agents/skills/`. Install = clone this repo somewhere stable and symlink it into that folder.

```bash
git clone https://github.com/mnm-matin/hpi-aisc-gpu-skill.git ~/code/hpi-aisc-gpu-skill
mkdir -p ~/.agents/skills
ln -s ~/code/hpi-aisc-gpu-skill ~/.agents/skills/hpi-aisc-gpu
```

Or use the helper:

```bash
git clone https://github.com/mnm-matin/hpi-aisc-gpu-skill.git ~/code/hpi-aisc-gpu-skill
~/code/hpi-aisc-gpu-skill/install.sh
```

The directory name under `~/.agents/skills/` **must be `hpi-aisc-gpu`** (it has to match the `name:` field in `SKILL.md`).

## Update

```bash
cd ~/code/hpi-aisc-gpu-skill && git pull
```

Or:

```bash
~/code/hpi-aisc-gpu-skill/install.sh --update
```

## Per-user prerequisites (not shipped by the skill)

The skill is intentionally generic. Each user must set these up themselves before its workflows apply — see [`references/vpn-setup.md`](references/vpn-setup.md):

1. HPI VPN configured (OpenVPN / Tunnelblick) with your `.ovpn` and credentials.
2. `~/.ssh/config` with a `Host hpi-cluster` block (your username, key, `KexAlgorithms curve25519-sha256`).
3. `uv` installed at `$HOME/.local/bin/uv` on the cluster (one-time, via `srun`).

No usernames, paths, keys or VPN configs live in this repo.

## Layout

```
SKILL.md                    Top-level skill description + non-negotiable rules
assets/
  slurm_uv_h100_job.sh      Starter sbatch script for a uv-managed H100 job
references/
  vpn-setup.md              VPN, SSH config, KEX fix
  hpi-cluster-workflow.md   Commands, partitions, monitoring, pitfalls
  huggingface-auth.md       HF auth + cache conventions on the cluster
  experiment-tracking.md    Minimal metadata / metrics / artifacts schema
```

## Contributing

PRs welcome. Keep `SKILL.md` short — heavy detail belongs in `references/`. Don't put any user-specific values (usernames, IPs, paths under `/sc/home/<you>`) into the skill itself.
