-- Load the raw Telco churn CSV as a view. read_csv_auto infers types/headers.
-- Note: TotalCharges has a handful of blank strings (customers with tenure = 0,
-- i.e. brand-new signups). Depending on how many blanks are in the sniffed
-- sample, read_csv_auto infers this column as either VARCHAR (blanks force a
-- string column, e.g. the real Kaggle file) or DOUBLE with NULLs already in
-- place (e.g. the small CI fixture, where it happens to sniff as numeric).
-- Casting to VARCHAR first before trimming makes the cleanup below work
-- either way instead of assuming one specific inferred type.

CREATE OR REPLACE VIEW customers_raw AS
    SELECT * FROM read_csv_auto('data/raw/WA_Fn-UseC_-Telco-Customer-Churn.csv');

-- typed, cleaned base view everything else builds on
CREATE OR REPLACE VIEW customers AS
    SELECT
        "customerID"        AS customer_id,
        gender,
        "SeniorCitizen"      AS senior_citizen,
        "Partner"            AS has_partner,
        "Dependents"         AS has_dependents,
        tenure,
        "PhoneService"       AS phone_service,
        "MultipleLines"      AS multiple_lines,
        "InternetService"    AS internet_service,
        "OnlineSecurity"     AS online_security,
        "OnlineBackup"       AS online_backup,
        "DeviceProtection"   AS device_protection,
        "TechSupport"        AS tech_support,
        "StreamingTV"        AS streaming_tv,
        "StreamingMovies"    AS streaming_movies,
        "Contract"           AS contract,
        "PaperlessBilling"   AS paperless_billing,
        "PaymentMethod"      AS payment_method,
        "MonthlyCharges"     AS monthly_charges,
        TRY_CAST(NULLIF(TRIM(CAST("TotalCharges" AS VARCHAR)), '') AS DOUBLE) AS total_charges,
        "Churn"              AS churn
    FROM customers_raw;

-- sanity check
SELECT
    COUNT(*)                                   AS total_customers,
    COUNT(*) FILTER (WHERE churn = 'Yes')       AS churned_customers,
    COUNT(*) FILTER (WHERE total_charges IS NULL) AS rows_with_blank_total_charges
FROM customers;
