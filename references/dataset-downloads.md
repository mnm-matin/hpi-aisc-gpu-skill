# Dataset Downloads and Large Transfers

Use this reference before writing or submitting any job that downloads datasets, crawls URL lists, uses torrents, or moves large artifacts into or out of the HPI Scientific Compute cluster.

## Official policy anchors

- Terms of Usage: `https://docs.sc.hpi.de/Terms-of-Usage/`
- AI Usage Guidelines: `https://docs.sc.hpi.de/AI-Usage-Guidelines/`
- Data Transfer: `https://docs.sc.hpi.de/cluster/Storage/Data-Transfer/`
- Storage Overview: `https://docs.sc.hpi.de/cluster/Storage/Overview/`
- Quotas / Limits: `https://docs.sc.hpi.de/cluster/Storage/Quotas/`
- Scratch Space: `https://docs.sc.hpi.de/cluster/Storage/Scratch-Space/`
- Partitions: `https://docs.sc.hpi.de/cluster/Resources/Partitions/`
- Login Nodes: `https://docs.sc.hpi.de/cluster/Resources/Login-Nodes/`
- Run Nodes: `https://docs.sc.hpi.de/cluster/Resources/Run-Nodes/`
- Slurm Basics: `https://docs.sc.hpi.de/cluster/SLURM/Basics/`
- Slurm Customizations: `https://docs.sc.hpi.de/cluster/SLURM/Customization/`
- Scheduling and Priorities: `https://docs.sc.hpi.de/cluster/SLURM/Scheduling-and-Priorities/`
- AISC overview: `https://docs.sc.hpi.de/aisc/`
- AISC computing resources: `https://docs.sc.hpi.de/aisc/Using-Our-Computing-Resources/`

HPI's Data Transfer page says the cluster shares a 10 Gbit/s internet uplink with all users and the HPI campus network. It explicitly asks users to contact `sc-helpdesk@hpi.de` before moving large amounts of data and warns that downloads which flood the network can be killed as Terms-of-Usage violations.

## Non-negotiable rules

- Contact `sc-helpdesk@hpi.de` before large transfers, full web crawls, or multi-terabyte dataset ingestion.
- Never download datasets on login nodes. Use a compute node via Slurm for small approved downloads.
- Do not use Run Nodes for heavy downloading or preprocessing. They are for lightweight helpers, VS Code server, file management, and job submission.
- Do not submit many parallel downloader jobs or huge job arrays without explicit approval.
- Do not run high-concurrency URL-list crawlers from the cluster. This includes `img2dataset` over datasets like GRIT at aggressive process/thread counts.
- Do not use torrent-style or UDP-heavy transfer tools on the cluster unless the admins have approved the method.
- Use project storage for durable datasets, not `$HOME`. Home directories have a 200 GB quota.
- Use `/sc/scratch` only for temporary active data, and use `$SLURM_SCRATCH`/`$TMP` only for per-job local scratch that can be deleted at job end.

## Why URL-list datasets are risky

Datasets such as GRIT provide metadata with many image URLs. The metadata itself is manageable; the risky part is making millions of outbound HTTP requests from HPI infrastructure. That can:

- saturate the shared cluster uplink,
- exhaust connection tracking tables,
- trigger abuse reports from contacted sites,
- contact compromised or blocklisted IPs embedded in old web-crawl metadata,
- trigger abuse or security alerts because of high-volume automated traffic,
- violate the Terms of Usage fair-use and intended-use requirements.

For GRIT-like datasets, treat full image materialization as a web crawl, not as a normal dataset download.

## Safe workflow for GRIT-like datasets

1. Read the source dataset license and terms. Confirm the project is allowed to use and store the data.
2. Estimate total bytes, number of URLs, domains, expected request rate, storage target, and runtime.
3. Ask `sc-helpdesk@hpi.de` whether the planned transfer method is acceptable.
4. Run a tiny pilot first, such as one shard or at most a few thousand URLs.
5. Keep pilot concurrency low, for example one process and 2-4 threads. Increase only after measuring throughput and getting approval.
6. Log request counts, bytes, failures, domains, and effective requests per second.
7. Use resumable sharded output. Never restart a failed large crawl from zero if it will repeat the same traffic.
8. Validate output shards before deleting partial state.
9. Clean up raw data that is no longer needed after processing.

Avoid patterns like this for full-scale GRIT downloads on the cluster:

```bash
img2dataset \
  --processes_count 8 \
  --thread_count 64 \
  ...
```

That can create hundreds of concurrent outbound fetches from one job before retries and library-level parallelism are considered.

## Intermediate machine pattern

For datasets made of many external URLs, prefer using an intermediate machine outside HPI, such as a dedicated Oracle VPS, only for the public-internet crawling stage. The cluster should receive already-materialized archives or WebDataset shards, not perform the millions of external URL fetches itself.

Recommended pattern:

1. On the intermediate machine, download/crawl with conservative global concurrency and rate limits.
2. Block private, local, multicast, and otherwise suspicious IP ranges before fetching.
3. Record dataset provenance: source metadata version, command, concurrency, user agent, start/end time, bytes, domains, failed URLs, and filtering rules.
4. Package results into large, resumable shard files such as `.tar`, `.tar.zst`, or WebDataset shards.
5. Transfer from the intermediate machine to HPI as a controlled file transfer, not as many source-site HTTP requests.
6. Pull the staged archives from a compute-node Slurm job with low connection counts, or coordinate another import method with `sc-helpdesk@hpi.de`.

Do not assume an HPI Cloud VM solves this automatically. HPI docs say VMs cannot SSH into the cluster; external scheduling from a VM uses the Slurm REST API and has JWT security implications. HPI Cloud VMs are useful only when the admins agree they are the right fit for the transfer or service.

## Transfer commands to prefer

For small approved HTTP downloads on compute nodes, use a resumable tool with low concurrency:

```bash
aria2c --continue=true --max-connection-per-server=2 --split=2 --min-split-size=64M \
  --dir "$TARGET_DIR" "$URL"
```

For a staged intermediate machine, prefer a small number of durable streams:

```bash
rsync -az --partial --info=progress2 intermediate:/data/grit-shards/ /sc/projects/<project>/datasets/grit/
```

Run transfer commands from a compute node allocation, not a login node, when the transfer is non-trivial.

## Storage checklist

- Run `projects` on the cluster to find project shares.
- Keep durable datasets under `/sc/projects/<project>/...` when available.
- Keep `$HOME` for code, small configs, logs, credentials, and small caches only.
- If training repeatedly reads a dataset and the node has local scratch, copy active shards to `$SLURM_SCRATCH` at job start and copy results back before job end.
- If data is larger than local scratch or shared across jobs, use `/sc/scratch` only as temporary active storage and clean it promptly.

## Review checklist before submitting a dataset job

- Does the job use the correct `--account` from `saccount`?
- Does it run on a compute partition, not login or Run Nodes?
- Is the requested time realistic and within the partition cap?
- Is concurrency explicitly capped?
- Is the output resumable and sharded?
- Are logs sufficient to show progress and throughput?
- Is storage targeted to project or scratch, not home?
- Has helpdesk been contacted for large internet transfers?
- For URL-list datasets, has an intermediate-machine plan been considered or used?
- Are credentials, API tokens, SSH keys, and private URLs kept out of scripts and logs?
