# Lightweight Experiment Tracking

Use this reference when a cluster run should be reproducible and inspectable without requiring Weights & Biases or MLflow.

## Recommended default

Prefer local file-based tracking stored inside the relevant experiment folder. Keep the schema simple and append-only.

Suggested layout:

```text
<experiment-dir>/runs/
  <run_id>/
    metadata.json
    config.json
    metrics.jsonl
    artifacts/
```

The run directory should live with the experiment, not in a shared global location.

## `metadata.json` schema

Write one structured metadata file per run. Suggested schema:

```json
{
  "run_id": "clip_adapter_20260318_101530_ab12cd34",
  "experiment_name": "clip_adapter",
  "status": "running",
  "start_time": "2026-03-18T10:15:30Z",
  "end_time": null,
  "git_commit": "abc1234",
  "git_dirty": false,
  "tags": {
    "dataset": "coco",
    "model": "clip-vit-b32"
  },
  "job": {
    "slurm_job_id": "1769819",
    "partition": "aisc-batch",
    "node_list": "gx17v1",
    "num_nodes": "1",
    "gpus_per_node": "1",
    "stdout": "/path/to/stdout.log",
    "stderr": "/path/to/stderr.log"
  },
  "env": {
    "hostname": "gx17v1",
    "world_size": "1",
    "node_rank": "0"
  }
}
```

Minimum fields worth recording:

- run id
- experiment name
- start and end time
- final status (`running`, `completed`, `failed`, `cancelled`)
- git commit and dirty state
- SLURM job id, partition, node info, and real stdout/stderr paths

## `config.json`

Store the resolved config that actually produced the run, not just a pointer to a YAML file. The goal is that the run can be understood later without reconstructing implicit defaults.

Typical contents:

- hyperparameters
- dataset or split names
- model identifier
- loss configuration
- optimizer and scheduler settings
- seed

## `metrics.jsonl` schema

Append one JSON object per log event:

```json
{"timestamp":"2026-03-18T10:16:10Z","step":100,"train/loss":1.23,"lr":0.0001}
{"timestamp":"2026-03-18T10:17:10Z","step":200,"train/loss":1.11,"val/recall@10":0.42}
```

Guidelines:

- Use one JSON object per line.
- Keep metric keys flat and stable.
- Include `step` or `epoch` whenever meaningful.
- Append only; do not rewrite history mid-run.

## `artifacts/`

Use `artifacts/` for outputs worth revisiting:

- plots
- reports
- confusion matrices
- retrieval examples
- small checkpoints or symlinks to large checkpoints

Avoid duplicating very large model files unless the project explicitly needs archival copies.

## Operational pattern

1. Create the run directory before training starts.
2. Write `metadata.json` and `config.json` immediately.
3. Append metrics to `metrics.jsonl` during training or evaluation.
4. Copy plots and other outputs into `artifacts/`.
5. Update `metadata.json` with final status and `end_time` on exit.

## SLURM fields worth capturing

At minimum, record these if they exist:

- `SLURM_JOB_ID`
- `SLURM_JOB_PARTITION`
- `SLURM_JOB_NUM_NODES`
- `SLURM_GPUS_PER_NODE`
- `SLURM_JOB_NODELIST`
- `HOSTNAME`
- real stdout/stderr paths from `scontrol show job`

## Optional external tracking

Weights & Biases or MLflow can be added later if the project already uses them. They should be optional layers on top of the local schema above, not replacements for basic run metadata.