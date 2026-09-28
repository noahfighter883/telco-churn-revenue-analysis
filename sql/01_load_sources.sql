-- Load the raw Telco churn CSV as a view. read_csv_auto infers types/headers.
-- Note: TotalCharges has a handful of blank strings (customers with tenure = 0,
-- i.e. brand-new signups) which read_csv_auto will coerce to NULL — that's fine,
-- we handle it explicitly in 02_churn_overview.sql.

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
        TRY_CAST(NULLIF(TRIM("TotalCharges"), '') AS DOUBLE) AS total_charges,
        "Churn"              AS churn
    FROM customers_raw;

-- sanity check
SELECT
    COUNT(*)                                   AS total_customers,
    COUNT(*) FILTER (WHERE churn = 'Yes')       AS churned_customers,
    COUNT(*) FILTER (WHERE total_charges IS NULL) AS rows_with_blank_total_charges
FROM customers;
