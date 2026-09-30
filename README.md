# Churn & Revenue-at-Risk Analysis — Telco Subscription Data

**Business question:** Which customer segments are churning fastest, and how much Monthly Recurring Revenue (MRR) is at risk if we don't intervene?

## Why this question

Churn is the single biggest lever in a subscription business — losing a customer doesn't just cost one month's revenue, it costs their whole remaining lifetime value. This project doesn't stop at "churn rate is X%." It segments churn by contract type, services, and billing method, then translates the highest-risk segments into **dollar amounts** a retention team could actually prioritize against.

## Data

[Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn) (Kaggle, IBM sample dataset — ~7,043 customers, one table). See [data/README.md](data/README.md) for download instructions — the raw CSV is not committed to this repo.

## Approach

1. **`sql/01_load_sources.sql`** — load the raw CSV into DuckDB as a view
2. **`sql/02_churn_overview.sql`** — overall churn rate, current MRR, MRR already lost to churned customers
3. **`sql/03_segment_drivers.sql`** — churn rate by contract type, internet service, payment method, and tenure bucket (with a minimum segment size to avoid noisy small-N segments)
4. **`sql/04_revenue_at_risk.sql`** — quantify MRR at risk in the highest-churn active segments, annualized, ranked by dollar exposure (not just churn %)
5. **`sql/05_export_dashboard_extracts.sql`** — export final aggregates to `data/processed/` for the dashboard

Run all of it with:

```bash
./scripts/run_analysis.sh
```

## Dashboard

**Tableau Public:** [Telco Churn & Revenue at Risk](https://public.tableau.com/app/profile/noah.fighter/viz/TelcoChurnRevenueatRisk/Dashboard1)

**HTML version:** [Churn Revenue Risk](https://claude.ai/artifact/GKzGFjvjCnXpR52oUMoPGf)

See [dashboard/README.md](dashboard/README.md) for what it shows and how it was built.

## Findings

Full memo (question → finding → recommendation → caveats): **[analysis/findings.md](analysis/findings.md)**

## Tools

DuckDB (SQL engine, no server setup needed), Tableau Public (dashboard).

## Repo structure

```
data/
  README.md          how to get the raw data
  raw/                gitignored — put the downloaded CSV here
  processed/          small aggregated CSVs, safe to commit, feed the dashboard
sql/                  numbered analysis queries, run in order
scripts/
  run_analysis.sh     runs the SQL files in sequence against a local DuckDB file
analysis/
  findings.md         the write-up: question, finding, recommendation, caveats
dashboard/
  README.md           dashboard description + Tableau Public link
```
