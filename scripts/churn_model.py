#!/usr/bin/env python3
"""
Multivariate logistic regression on the segment variables already explored
in SQL (sql/04_segment_drivers.sql, sql/05_significance_checks.sql), aimed
at a specific open question from analysis/findings.md's caveats: are
contract type, internet service, and payment method each still
independently associated with churn once you control for all of them (and
tenure, monthly charges, senior citizen status) at the same time -- or does
some of the univariate signal wash out once you're not looking at one
variable in isolation?

The chi-square tests in sql/05 are univariate (one factor vs. everyone
else); this is the multivariate follow-up.

Requires: pip install -r requirements.txt
Requires analytics.duckdb to already exist -- run ./scripts/run_analysis.sh
first, which creates it and the `customers` view this script queries.
"""
import duckdb
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_score, recall_score, roc_auc_score
from sklearn.model_selection import train_test_split

con = duckdb.connect("analytics.duckdb", read_only=True)
df = con.execute("""
    SELECT
        CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END AS churn,
        contract, internet_service, payment_method,
        tenure, monthly_charges, senior_citizen
    FROM customers
""").df()
con.close()

# Reference (baseline) categories chosen to be the lowest-churn group in
# each variable, per sql/04_segment_drivers.sql -- so every coefficient
# below reads as "vs. the safest group," matching how the SQL findings are
# already framed, rather than statsmodels' default (alphabetical) baseline.
df["contract"] = pd.Categorical(df["contract"], categories=["Two year", "One year", "Month-to-month"])
df["internet_service"] = pd.Categorical(df["internet_service"], categories=["DSL", "No", "Fiber optic"])
df["payment_method"] = pd.Categorical(df["payment_method"], categories=[
    "Credit card (automatic)", "Bank transfer (automatic)", "Mailed check", "Electronic check",
])

# --- Part 1: inference -- which factors survive controlling for the others? ---
formula = "churn ~ C(contract) + C(internet_service) + C(payment_method) + tenure + monthly_charges + senior_citizen"
model = smf.logit(formula, data=df).fit(disp=False)

coef_table = pd.DataFrame({
    "variable": model.params.index,
    "coefficient": model.params.values,
    "odds_ratio": np.exp(model.params.values),
    "p_value": model.pvalues.values,
}).iloc[1:]  # drop the intercept row
coef_table["significant_at_0_05"] = coef_table["p_value"] < 0.05
coef_table = coef_table.sort_values("p_value").reset_index(drop=True)
coef_table.round(4).to_csv("data/processed/model_coefficients.csv", index=False)

print("=" * 70)
print("MULTIVARIATE LOGISTIC REGRESSION -- controlling for all factors at once")
print("=" * 70)
print(model.summary())
print()
print(coef_table.round(4).to_string(index=False))

# --- Part 2: does it actually predict anything, on data it hasn't seen? ---
# Secondary to the inference above -- the point of this script is "which
# factors matter, controlling for the others," not "build the best possible
# predictor." A plain holdout split is enough to sanity-check the model
# isn't just overfitting the categories it was handed.
X = pd.get_dummies(
    df[["contract", "internet_service", "payment_method", "tenure", "monthly_charges", "senior_citizen"]],
    drop_first=True,
)
y = df["churn"]
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=42, stratify=y)

clf = LogisticRegression(max_iter=1000)
clf.fit(X_train, y_train)
y_pred = clf.predict(X_test)
y_proba = clf.predict_proba(X_test)[:, 1]

print()
print("=" * 70)
print("HOLDOUT TEST SET PERFORMANCE (25% held out, not used to fit the model)")
print("=" * 70)
print(f"Accuracy:  {accuracy_score(y_test, y_pred):.3f}")
print(f"Precision: {precision_score(y_test, y_pred):.3f}")
print(f"Recall:    {recall_score(y_test, y_pred):.3f}")
print(f"ROC-AUC:   {roc_auc_score(y_test, y_proba):.3f}")
print()
print("Baseline (always predict majority class 'No churn'):")
majority_baseline = (y_test == 0).mean()
print(f"Accuracy:  {majority_baseline:.3f}")
