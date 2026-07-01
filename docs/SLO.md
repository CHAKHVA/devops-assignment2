# Service Level Objectives (SLOs)

These objectives define the reliability targets for the Flask application and
the supporting observability stack. They are intentionally modest and
measurable with the metrics we already collect in Prometheus.

## Service Level Indicators (SLIs)

| SLI | Definition | Prometheus source |
| --- | --- | --- |
| Availability | Fraction of successful (`status < 500`) requests | `app_requests_total{status="200"}` vs total |
| Latency | p95 request latency | `app_request_latency_seconds_bucket` |
| Target uptime | Scrape targets reporting `up` | `up` |

## Objectives

| Objective | Target (rolling 30 days) |
| --- | --- |
| Request availability | >= 99.0% of requests succeed |
| Request latency (p95) | < 500 ms |
| App instance uptime | >= 99.0% |
| Error budget | 1.0% of requests may fail per 30-day window |

## Error budget policy

- The 1% error budget is tracked via the ratio of `app_errors_total` to
  `app_requests_total`.
- If the budget is exhausted within a window, feature deployments pause and the
  team prioritizes reliability work until the budget recovers.
- `HighErrorRate` (see [prometheus/alert_rules.yml](../prometheus/alert_rules.yml))
  fires when the burn rate is high (>5 errors/min), providing early warning
  before the budget is fully consumed.

## Alerts that back these SLOs

| Alert | Protects SLO | Severity |
| --- | --- | --- |
| `HighErrorRate` | Availability / error budget | critical |
| `HighRequestLatency` | Latency | warning |
| `InstanceDown` | Uptime | critical |
| `ContainerHighMemory` | Capacity / stability | warning |

## Measuring availability (example queries)

```promql
# Availability over the last 30 days
sum(rate(app_requests_total{status="200"}[30d]))
  /
sum(rate(app_requests_total[30d]))

# p95 latency over 5m
histogram_quantile(0.95, sum(rate(app_request_latency_seconds_bucket[5m])) by (le))
```
