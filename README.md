# Churn & Revenue-at-Risk Analysis — Telco Subscription Data

**Business question:** Which customer segments are churning fastest, and how much Monthly Recurring Revenue (MRR) is at risk if we don't intervene?

**30-second version:** [Executive summary](analysis/executive-summary.md)

## Why this question

Churn is the single biggest lever in a subscription business — losing a customer doesn't just cost one month's revenue, it costs their whole remaining lifetime value. This project doesn't stop at "churn rate is X%." It segments churn by contract type, services, and billing method, then translates the highest-risk segments into **dollar amounts** a retention team could actually prioritize against.

## Data

[Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn) (Kaggle, IBM sample dataset — ~7,043 customers, one table). See [data/README.md](data/README.md) for download instructions — the raw CSV is not committed to this repo.

## Approach

1. **`sql/01_load_sources.sql`** — load the raw CSV into DuckDB as a view
2. **`sql/02_data_quality_checks.sql`** — assert the data is what it should be (no duplicate IDs, no invalid categories, nulls only where expected) before trusting anything downstream
3. **`sql/03_churn_overview.sql`** — overall churn rate, current MRR, MRR already lost to churned customers
4. **`sql/04_segment_drivers.sql`** — churn rate by contract type, internet service, payment method, and tenure bucket (with a minimum segment size to avoid noisy small-N segments)
5. **`sql/05_significance_checks.sql`** — chi-square tests on the two most surprising drivers (electronic check, fiber optic) — is the gap real or could it be noise?
6. **`sql/06_revenue_at_risk.sql`** — quantify MRR at risk in the highest-churn active segments, annualized, ranked by dollar exposure (not just churn %)
7. **`sql/07_retention_roi_scenario.sql`** — turns the top segment into a spend decision: campaign cost, breakeven success rate, and ROI at a few plausible effectiveness levels
8. **`sql/08_export_dashboard_extracts.sql`** — export final aggregates to `data/processed/` for the dashboard

Run all of it with:

```bash
./scripts/run_analysis.sh
```

## Model (optional follow-up)

The SQL pipeline's significance tests (step 5) are univariate — one factor vs. everyone else, tested in isolation. [scripts/churn_model.py](scripts/churn_model.py) follows up with a multivariate logistic regression that controls for contract, internet service, payment method, tenure, monthly charges, and senior citizen status all at once, to directly test whether those factors are independently real or just proxies for each other. It also validates on a 25% holdout split. Results feed into [analysis/findings.md](analysis/findings.md).

Requires `analytics.duckdb` to already exist (run `./scripts/run_analysis.sh` first), plus Python:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 scripts/churn_model.py
```

## Dashboard

**Tableau Public:** [Telco Churn & Revenue at Risk](https://public.tableau.com/app/profile/noah.fighter/viz/TelcoChurnRevenueatRisk/Dashboard1)

**HTML version:** [Churn Revenue Risk](https://claude.ai/artifact/GKzGFjvjCnXpR52oUMoPGf)

See [dashboard/README.md](dashboard/README.md) for what it shows and how it was built.

## Findings

- Full memo (question → finding → recommendation → caveats): **[analysis/findings.md](analysis/findings.md)**
- One-page version: **[analysis/executive-summary.md](analysis/executive-summary.md)**

## CI

[![SQL pipeline CI](https://github.com/noahfighter883/telco-churn-revenue-analysis/actions/workflows/ci.yml/badge.svg)](https://github.com/noahfighter883/telco-churn-revenue-analysis/actions/workflows/ci.yml)

Every push runs the full SQL pipeline against a small synthetic fixture (`data/sample/`), since the real Kaggle data isn't committed to this repo. It's a regression test for the SQL itself — catches syntax errors or broken logic before they'd surface on real data. See [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Tools

DuckDB (SQL engine, no server setup needed), Python (statsmodels/scikit-learn, optional multivariate follow-up), Tableau Public (dashboard), GitHub Actions (CI).

## Repo structure

```
data/
  README.md          how to get the raw data
  raw/                gitignored — put the downloaded CSV here
  sample/             small synthetic fixture used by CI (not real data)
  processed/          small aggregated CSVs, safe to commit, feed the dashboard
sql/                  numbered analysis queries, run in order
scripts/
  run_analysis.sh            runs the SQL files in sequence against a local DuckDB file
  generate_sample_data.py    regenerates the CI fixture in data/sample/
  churn_model.py              optional multivariate logistic regression follow-up
analysis/
  findings.md              the write-up: question, finding, recommendation, caveats
  executive-summary.md     one-page version for a 30-second skim
dashboard/
  README.md           dashboard description + Tableau Public link
  dashboard-screenshot.png
.github/workflows/
  ci.yml               runs the pipeline against the sample fixture on every push
requirements.txt        Python deps for scripts/churn_model.py
```
