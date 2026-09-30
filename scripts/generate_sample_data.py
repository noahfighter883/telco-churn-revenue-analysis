#!/usr/bin/env python3
"""Generates a small synthetic fixture with the same schema as the real
Telco Customer Churn CSV, for CI -- the real Kaggle data isn't committed to
this repo (see data/README.md), so the pipeline needs something to run
against on every push. Not meant to reproduce real statistics, just to
exercise every column and code path the SQL pipeline touches, including a
tenure=0 / blank TotalCharges row for the data quality check.

Deterministic (fixed seed) so the fixture doesn't change between runs unless
this script changes.
"""
import csv
import random

random.seed(42)

CONTRACTS = ["Month-to-month", "One year", "Two year"]
INTERNET_SERVICES = ["DSL", "Fiber optic", "No"]
PAYMENT_METHODS = ["Electronic check", "Mailed check", "Bank transfer (automatic)", "Credit card (automatic)"]
YES_NO = ["Yes", "No"]

_customer_num = 1000


def make_row(contract, internet, payment, churn_bias=0.0):
    global _customer_num
    _customer_num += 1

    tenure = random.choice([0, 1, 2, 3, 5, 8, 12, 18, 24, 30, 36, 48, 60, 72])
    monthly_charges = round(random.uniform(18.0, 120.0), 2)
    total_charges = "" if tenure == 0 else round(monthly_charges * tenure + random.uniform(-5, 5), 2)
    churn = "Yes" if random.random() < (0.15 + churn_bias) else "No"
    has_internet = internet != "No"

    def service_field():
        return random.choice(YES_NO) if has_internet else "No internet service"

    return {
        "customerID": f"{_customer_num}-SAMPL",
        "gender": random.choice(["Male", "Female"]),
        "SeniorCitizen": random.choice([0, 1]),
        "Partner": random.choice(YES_NO),
        "Dependents": random.choice(YES_NO),
        "tenure": tenure,
        "PhoneService": random.choice(YES_NO),
        "MultipleLines": random.choice(["Yes", "No", "No phone service"]),
        "InternetService": internet,
        "OnlineSecurity": service_field(),
        "OnlineBackup": service_field(),
        "DeviceProtection": service_field(),
        "TechSupport": service_field(),
        "StreamingTV": service_field(),
        "StreamingMovies": service_field(),
        "Contract": contract,
        "PaperlessBilling": random.choice(YES_NO),
        "PaymentMethod": payment,
        "MonthlyCharges": monthly_charges,
        "TotalCharges": total_charges,
        "Churn": churn,
    }


def main():
    rows = []

    # A deliberately large block in one segment so it clears the >=50
    # HAVING threshold used in segment_drivers/revenue_at_risk/roi_scenario --
    # otherwise those queries would return empty results against a tiny
    # fixture and CI wouldn't actually exercise that code path.
    for _ in range(60):
        rows.append(make_row("Month-to-month", "Fiber optic", "Electronic check", churn_bias=0.35))

    # Everything else spread across random combinations
    for _ in range(240):
        rows.append(make_row(
            random.choice(CONTRACTS),
            random.choice(INTERNET_SERVICES),
            random.choice(PAYMENT_METHODS),
        ))

    random.shuffle(rows)

    out_path = "data/sample/sample_telco_churn.csv"
    with open(out_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {out_path}")


if __name__ == "__main__":
    main()
