# hpi-aisc-gpu skill

An [Agent Skill](https://agentskills.io) for working safely on the HPI Scientific Compute and AI Service Center (AISC) SLURM cluster. Teaches the agent the non-negotiable rules (no installs on login nodes, VPN, partition / account flags, ARM-vs-X86 quirks, monitoring patterns, large-transfer safeguards) and points it at compact reference docs for VPN setup, dataset downloads, Hugging Face auth, and lightweight experiment tracking.

The skill activates automatically when the agent's task mentions `ssh hpi-cluster`, `sbatch`, H100s, AISC, etc.

Works with any agent runtime that follows the Agent Skills convention of loading skills from `~/.agents/skills/<name>/SKILL.md` (e.g. Codex, VS Code Copilot agent mode, custom Claude/Anthropic agents).

## Install

Clone the repo into your skills directory:

```bash
git clone https://github.com/mnm-matin/hpi-aisc-gpu-skill.git ~/.agents/skills/hpi-aisc-gpu
```

The directory name must be `hpi-aisc-gpu` to match the `name:` field in `SKILL.md`.

### Update

```bash
git -C ~/.agents/skills/hpi-aisc-gpu pull
```

### Uninstall

```bash
rm -rf ~/.agents/skills/hpi-aisc-gpu
```

### Claude Code

If you use Claude Code, you can also install via the plugin system:

```
/plugin marketplace add mnm-matin/hpi-aisc-gpu-skill
```

## Per-user prerequisites

The skill is intentionally generic. Each user must set these up before its workflows apply — see [references/vpn-setup.md](references/vpn-setup.md):

1. HPI VPN configured (OpenVPN / Tunnelblick) with your `.ovpn` and credentials.
2. `~/.ssh/config` with a `Host hpi-cluster` block (your username, key, `KexAlgorithms curve25519-sha256`).
3. `uv` installed at `$HOME/.local/bin/uv` on the cluster (one-time, via `srun`).

Keep usernames, local paths, keys, and VPN configs in local config only.

## Layout

```
SKILL.md                    Skill metadata + non-negotiable rules
assets/
  slurm_uv_h100_job.sh      Starter sbatch script for a uv-managed H100 job
references/
  vpn-setup.md              VPN, SSH config, MTU troubleshooting
  hpi-cluster-workflow.md   Commands, partitions, monitoring, pitfalls
  pre-submit-checklist.md   Required checklist before running cluster scripts
  dataset-downloads.md      Large transfer and GRIT-like URL-list safeguards
  huggingface-auth.md       HF auth + cache conventions on the cluster
  experiment-tracking.md    Minimal metadata / metrics / artifacts schema
```

## Developing

To work on the skill while having it active for your agent, clone it somewhere convenient and symlink it into the skills dir:

```bash
git clone git@github.com:mnm-matin/hpi-aisc-gpu-skill.git ~/code/hpi-aisc-gpu-skill
ln -s ~/code/hpi-aisc-gpu-skill ~/.agents/skills/hpi-aisc-gpu
```

PRs welcome. Keep `SKILL.md` short — heavy detail belongs in `references/`. Don't commit user-specific values (usernames, paths under `/sc/home/<you>`, VPN configs).
