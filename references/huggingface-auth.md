# Hugging Face Auth and Cache

Use this reference when a job needs gated Hugging Face models or datasets, repeated model downloads are expensive, or a containerized workflow needs non-interactive authentication.

For large Hugging Face datasets, URL-list datasets, or repeated multi-GB downloads, also read `references/dataset-downloads.md` before submitting the job.

## Recommended default

Store the token in a local file and expose it inside the job:

```bash
mkdir -p ~/.huggingface
chmod 700 ~/.huggingface
printf '%s\n' '<your-hf-token>' > ~/.huggingface/token
chmod 600 ~/.huggingface/token
```

Never commit the token, print it in logs, or hardcode it in scripts.

## Job-time environment

Inside the batch job, export the token and keep the cache on persistent storage:

```bash
export HUGGING_FACE_HUB_TOKEN="$(cat ~/.huggingface/token)"
export HF_HOME="${HF_HOME:-$HOME/.huggingface}"
export HF_HUB_CACHE="${HF_HUB_CACHE:-$HF_HOME/hub}"
mkdir -p "$HF_HOME" "$HF_HUB_CACHE"
```

Guidelines:

- Keep `HF_HOME` and `HF_HUB_CACHE` on `$HOME` or project storage when downloads are expensive.
- Prefer project storage for large caches. `$HOME` has a 200 GB quota on the HPI cluster.
- Do not keep long-lived model caches only in `$SLURM_SCRATCH`, `$TMP`, or other ephemeral scratch.
- If a job unpacks large files temporarily, use scratch for the temporary step but keep the real cache persistent.

## CLI login

Many Python workflows work with `HUGGING_FACE_HUB_TOKEN` alone. If the toolchain explicitly expects CLI login state, use:

```bash
huggingface-cli login --token "$HUGGING_FACE_HUB_TOKEN"
```

Do this inside the job or container, not on the login node.

## Container jobs

If the job runs in a container:

- Mount `~/.huggingface` into the container, or pass `HUGGING_FACE_HUB_TOKEN` in the job environment.
- Point `HF_HOME` to a mounted host path so downloads persist across jobs.
- For multi-node jobs, use one shared cache root if all nodes need the same gated model weights.

## When this is needed

Use this pattern when:

- Accessing gated models such as Llama variants.
- Downloading large checkpoints repeatedly would waste time or bandwidth.
- Running containerized jobs where auth must exist inside the container.

It is usually unnecessary for jobs that never touch Hugging Face assets.

## Optional token check

If access looks broken, validate the token against a resource you expect to access:

```bash
curl -I -H "Authorization: Bearer $(cat ~/.huggingface/token)" \
  https://huggingface.co/<org>/<model>/raw/main/config.json
```

403 usually means the token lacks permission or the account has not accepted the model's terms.