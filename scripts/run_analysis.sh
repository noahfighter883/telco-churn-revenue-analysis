#!/usr/bin/env bash
# Runs the SQL files in order against a local DuckDB database file.
# Requires the DuckDB CLI: https://duckdb.org/docs/installation

set -euo pipefail
cd "$(dirname "$0")/.."

RAW_FILE="data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv"
if [ ! -f "$RAW_FILE" ]; then
    echo "Missing $RAW_FILE — see data/README.md for download instructions." >&2
    exit 1
fi

mkdir -p data/processed

DB_FILE="analytics.duckdb"
for f in sql/01_load_sources.sql sql/02_data_quality_checks.sql sql/03_churn_overview.sql sql/04_segment_drivers.sql sql/05_significance_checks.sql sql/06_revenue_at_risk.sql sql/07_retention_roi_scenario.sql sql/08_export_dashboard_extracts.sql; do
    echo "== running $f =="
    duckdb "$DB_FILE" < "$f"
    echo
done

echo "Done. Aggregated CSVs are in data/processed/."
