# Data

## Download

1. Get the dataset from Kaggle: [Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn)
2. Download `WA_Fn-UseC_-Telco-Customer-Churn.csv` and place it into `data/raw/` (this folder), so the path is:

```
data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv
```

`data/raw/` is gitignored — the file isn't ours to redistribute.

## Columns you'll use most

- `customerID` — unique customer key
- `tenure` — months as a customer
- `Contract` — Month-to-month / One year / Two year
- `InternetService`, `PaymentMethod`, and the various service add-on flags
- `MonthlyCharges`, `TotalCharges` — used to derive MRR and a lifetime-value proxy
- `Churn` — Yes/No, the target

## Processed

`data/processed/` holds the small, aggregated CSVs produced by `sql/05_export_dashboard_extracts.sql`. These ARE committed — they're small (a few KB, segment-level summaries) and are what the Tableau dashboard reads from.
