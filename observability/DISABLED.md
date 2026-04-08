# Observability Stack — TEMPORARILY DISABLED

The LGTM observability stack (Loki, Grafana Agent, Mimir, Tempo) has been 
**intentionally disabled** for this environment and removed from the cluster 
as of 2026-04-08.

## Reason

The current stack (Bitnami Helm chart with Mimir 3-zone ingesters, distributed 
Loki, Tempo) is too resource-intensive for the single-node homelab use-case.

## Status

- **Grafana dashboard** — Remains deployed in `platform-services`; only the 
  backend datasources (Loki, Mimir, Tempo) are offline.
- **Mimir** — Namespace `observability` deleted. Do NOT re-apply without a new 
  design.
- **Loki** — Same as above.
- **Tempo** — Same as above.

## DO NOT re-deploy by running `kubectl apply -k` on any overlay that references 
the `k3slab/ansible/manifests` or the old observability Helm values.

## Next Steps (future sprint)

- [ ] Design a lightweight replacement using Grafana Alloy + single-binary Loki
- [ ] Consider VictoriaMetrics instead of Mimir for metrics
- [ ] Evaluate resource budgets before deploying
