# Incident Response Runbook

This runbook describes how to detect, triage, and recover from incidents in the
observability stack. All commands are run from the repository root.

## 1. Detection

Incidents are surfaced by:

- Grafana alerts (Alerting -> Alert rules) and Prometheus alert rules.
- The health verification script: `make verify`.
- Container health status: `docker compose ps`.

| Alert | Likely meaning | First action |
| --- | --- | --- |
| `HighErrorRate` | App returning 5xx above threshold | Section 3.1 |
| `HighRequestLatency` | p95 latency > 500ms | Section 3.2 |
| `InstanceDown` | A scrape target is unreachable | Section 3.3 |
| `ContainerHighMemory` | A container is consuming excessive memory | Section 3.4 |

## 2. Triage (first 5 minutes)

```bash
make ps                     # container + health status
docker compose logs --tail=100 app
make verify                 # re-run health/endpoint checks
```

Determine blast radius: is it one service (e.g. `app`) or the whole stack?
Check Grafana (http://localhost:3000) dashboards for request/error/latency
trends and Loki logs filtered by `level="ERROR"`.

## 3. Response by scenario

### 3.1 High error rate
1. Inspect recent error logs: `docker compose logs --tail=200 app | grep ERROR`.
2. If a recent deploy caused it, roll back: `make rollback`.
3. If external/dependency related, verify downstream services and restart the
   affected container: `docker compose restart app`.

### 3.2 High latency
1. Check container resource usage in the cAdvisor metrics / Grafana.
2. Restart the app if it is degraded: `docker compose restart app`.
3. If load-related, scale gunicorn workers (edit `app/Dockerfile` `--workers`).

### 3.3 Instance down
1. Identify the target: `curl -s localhost:9090/api/v1/targets`.
2. Restart the affected service: `docker compose restart <service>`.
3. If it will not start, inspect logs and recreate: `docker compose up -d --force-recreate <service>`.

### 3.4 High container memory
1. Identify the container from the alert label.
2. Restart it: `docker compose restart <service>`.
3. Investigate for leaks in Grafana memory trends before re-enabling load.

## 4. Recovery & rollback

- Roll back the app to the previous image tag: `make rollback`
  (uses `.deploy/previous_tag` recorded by `scripts/deploy.sh`).
- Full stack restart: `make restart`.
- Last resort (DESTROYS volumes/data): `make clean && make up`.

After recovery, always confirm with `make verify`.

## 5. Post-incident

- Record what happened, the impact window, root cause, and fix.
- File follow-up issues for permanent fixes (alerts, tests, capacity).
- If the error budget (see [SLO.md](SLO.md)) was breached, pause feature work
  per the error budget policy.
