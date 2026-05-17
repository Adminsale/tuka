# SLO Definitions — SRE E-Commerce Platform

## Service Level Indicators (SLIs)

SLIs are measured via Prometheus recording rules defined in `monitoring/prometheus/alert.rules.yml`.

| SLI | PromQL (recording rule) | Description |
|-----|------------------------|-------------|
| Availability | `job:http_availability:ratio30d` | Fraction of non-5xx responses over 30 days |
| Error Rate | `job:http_error_rate:ratio5m` | Fraction of 5xx responses over a 5-minute window |
| P95 Latency | `job:http_latency_p95:5m` | 95th-percentile response time over 5 minutes |
| P99 Latency | `job:http_latency_p99:5m` | 99th-percentile response time over 5 minutes |

---

## Service Level Objectives (SLOs)

| SLO | Target | Measurement Window | Alert |
|-----|--------|-------------------|-------|
| Availability | ≥ 99.5% | 30 rolling days | `SLOAvailabilityBreach` (critical) |
| Error Rate | < 5% | 5 minutes | `HighErrorRate` (critical) |
| P95 Latency | ≤ 500 ms | 5 minutes | `HighP95Latency` (warning) |
| P99 Latency | ≤ 1 s | 5 minutes | `HighP99Latency` (critical) |

---

## Error Budget

The **error budget** is the allowed amount of unreliability within the SLO window.

For the **Availability SLO (99.5% / 30 days)**:

| Metric | Value |
|--------|-------|
| SLO target | 99.5% |
| Allowed error fraction | 0.5% |
| Monthly error budget | **3h 39m** of downtime |
| Weekly error budget | ~51 minutes |
| Daily error budget | ~7 minutes |

Error budget remaining is tracked in Grafana via the panel:

```promql
1 - (1 - job:http_availability:ratio30d) / (1 - 0.995)
```

When this value falls below **50%** the `ErrorBudgetBurningFast` alert fires (warning).
When it reaches **0%** the `SLOAvailabilityBreach` alert fires (critical).

---

## Alert Routing

| Alert | Severity | Action |
|-------|----------|--------|
| `HighErrorRate` | critical | Page on-call immediately |
| `HighP99Latency` | critical | Page on-call immediately |
| `SLOAvailabilityBreach` | critical | Page on-call + open incident |
| `ServiceDown` | critical | Page on-call immediately |
| `HighP95Latency` | warning | Notify team channel |
| `ErrorBudgetBurningFast` | warning | Notify team channel, schedule review |

---

## SLO Review Cadence

- **Weekly**: review error budget consumption in Grafana dashboard
- **Monthly**: SLO report — was the target met? What caused deviations?
- **Quarterly**: review SLO targets — are they still realistic and meaningful?
