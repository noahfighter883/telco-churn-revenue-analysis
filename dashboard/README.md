# Dashboard

**Tableau Public link:** [Telco Churn & Revenue at Risk](https://public.tableau.com/app/profile/noah.fighter/viz/TelcoChurnRevenueatRisk/Dashboard1)

**HTML version:** [Churn Revenue Risk](https://claude.ai/artifact/GKzGFjvjCnXpR52oUMoPGf) — same charts and numbers, built as an interactive web page.

## What it shows

Built from the CSVs in `data/processed/` (see [sql/05_export_dashboard_extracts.sql](../sql/05_export_dashboard_extracts.sql)):

1. **KPI header** — overall churn rate, current MRR, MRR lost to churn (`overview_kpis.csv`)
2. **Churn by tenure bucket** — bar chart showing churn is highest in the first few months (`churn_by_tenure_bucket.csv`)
3. **Churn by contract / internet service / payment method** — three small breakdowns side by side, so a viewer can see which single factor correlates most with churn (`churn_by_contract.csv`, `churn_by_internet_service.csv`, `churn_by_payment_method.csv`)
4. **Revenue at risk by segment** — the main chart: combined segments ranked by projected annual revenue at risk, not raw churn rate — this is the chart that should drive the "where do we act first" conversation (`revenue_at_risk_by_segment.csv`)

## Building the Tableau Public version

Tableau Public only supports authoring in the desktop app — there's no web-based builder — so this part has to be done by hand. Install [Tableau Public Desktop](https://public.tableau.com/en-us/s/download) (free), then:

### 1. Connect the data sources

Open Tableau Public → **Connect → Text file** → select `data/processed/overview_kpis.csv`. Repeat **Data → New Data Source** for the other five CSVs. You don't need to join any of them — they're independent summary tables, each feeding a different sheet.

### 2. Sheet 1 — KPI header

New worksheet on `overview_kpis.csv` (only 1 row, 5 columns). Skip the usual shelf-building here — instead:
- Right-click each measure (`churn_rate_pct`, `current_mrr`, `mrr_lost_to_churn`) → **Format** → set a large font size, drop it onto the sheet as a standalone text/number
- Easiest approach: create 3 separate small worksheets, one per KPI, each just a big number with a text caption above it (Tableau calls this a "BAN" — Big Ass Number). Use **Analysis → Create Calculated Field** if you want to format e.g. `mrr_lost_to_churn` as currency with `"$" + STR(ROUND([mrr_lost_to_churn],0))`.

### 3. Sheet 2 — Churn by tenure bucket

Data source: `churn_by_tenure_bucket.csv`
- Drag `tenure_bucket` to **Columns**
- Drag `churn_rate_pct` to **Rows**
- Chart type: **Bar**
- Right-click the `tenure_bucket` axis → **Sort** → by field → `sort_key`, ascending (this file has a `sort_key` column exactly for this — otherwise Tableau will alphabetize the buckets, putting "0-3 months" in the wrong order)
- Add `churn_rate_pct` to **Label** so each bar shows its value

### 4. Sheets 3–5 — Churn by contract / internet service / payment method

Same pattern for each, one sheet per CSV (`churn_by_contract.csv`, `churn_by_internet_service.csv`, `churn_by_payment_method.csv`):
- Dimension (contract / internet_service / payment_method) → **Columns**
- `churn_rate_pct` → **Rows**
- Bar chart, sorted **descending** by `churn_rate_pct` (right-click axis → Sort → Field → Descending — no `sort_key` needed here since there's no inherent order)
- Add value labels

Optional polish: right-click the highest bar in each → **Annotate → Mark**, or use a calculated field to color just the top bar differently (e.g. `IF [churn_rate_pct] = {MAX([churn_rate_pct])} THEN "Highest" ELSE "Other" END`, dropped onto **Color**) to match the emphasis in the HTML version.

### 5. Sheet 6 — Revenue at risk by segment (the main chart)

Data source: `revenue_at_risk_by_segment.csv`
- Create a calculated field called `Segment` to combine the three dimensions into one label: `[contract] + " · " + [internet_service] + " · " + [payment_method]`
- Drag `Segment` to **Rows**, `projected_annual_revenue_at_risk` to **Columns**
- Chart type: **Bar** (this makes it horizontal, which reads better with long segment labels)
- Sort `Segment` by `projected_annual_revenue_at_risk`, descending
- Right-click **Rows** shelf → if there are more than ~10 segments, filter to **Top N** (10) by `projected_annual_revenue_at_risk`
- Add `projected_annual_revenue_at_risk` to **Label**, format as currency
- Highlight the top segment: calculated field `IF FIRST()=0 THEN "Top risk" ELSE "Other" END` (with the sort already applied, `FIRST()=0` is the top row) dropped onto **Color**

### 6. Assemble the dashboard

**Dashboard → New Dashboard** (bottom tabs). Drag in: the 3 KPI sheets across the top, the tenure-bucket sheet below that, the 3 segment-driver sheets side by side, and the revenue-at-risk sheet full-width at the bottom. Add a title text box at the top with the business question.

### 7. Publish

**Server → Tableau Public → Save to Tableau Public** → sign in (or create a free account) → publishes and gives you a shareable URL. Paste that URL at the top of this file and in the main [README.md](../README.md).

## Screenshot

[add a screenshot here once built, e.g. `![dashboard](dashboard-screenshot.png)`]
