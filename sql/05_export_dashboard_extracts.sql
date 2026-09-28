-- Export final aggregates to data/processed/ as CSVs for the Tableau dashboard.
-- Run this last, after 01-04 have been run against the same DuckDB file.

COPY (
    SELECT
        COUNT(*)                                                            AS total_customers,
        COUNT(*) FILTER (WHERE churn = 'Yes')                               AS churned_customers,
        ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1)  AS churn_rate_pct,
        ROUND(SUM(monthly_charges) FILTER (WHERE churn = 'No'), 2)          AS current_mrr,
        ROUND(SUM(monthly_charges) FILTER (WHERE churn = 'Yes'), 2)         AS mrr_lost_to_churn
    FROM customers
) TO 'data/processed/overview_kpis.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT
        CASE
            WHEN tenure <= 3  THEN '0-3 months'
            WHEN tenure <= 12 THEN '4-12 months'
            WHEN tenure <= 24 THEN '13-24 months'
            ELSE '25+ months'
        END AS tenure_bucket,
        COUNT(*)                              AS customers,
        COUNT(*) FILTER (WHERE churn = 'Yes') AS churned,
        ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct,
        MIN(tenure) AS sort_key
    FROM customers
    GROUP BY 1
) TO 'data/processed/churn_by_tenure_bucket.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT contract, COUNT(*) AS customers,
           ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
    FROM customers GROUP BY 1
) TO 'data/processed/churn_by_contract.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT internet_service, COUNT(*) AS customers,
           ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
    FROM customers GROUP BY 1
) TO 'data/processed/churn_by_internet_service.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT payment_method, COUNT(*) AS customers,
           ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
    FROM customers GROUP BY 1
) TO 'data/processed/churn_by_payment_method.csv' (HEADER, DELIMITER ',');

COPY (
    WITH segment_churn_rate AS (
        SELECT contract, internet_service, payment_method,
               COUNT(*) AS segment_size,
               COUNT(*) FILTER (WHERE churn = 'Yes') / CAST(COUNT(*) AS DOUBLE) AS churn_rate
        FROM customers
        GROUP BY 1, 2, 3
        HAVING COUNT(*) >= 50
    ),
    active_segment_mrr AS (
        SELECT contract, internet_service, payment_method,
               COUNT(*) AS active_customers,
               ROUND(SUM(monthly_charges), 2) AS active_mrr
        FROM customers
        WHERE churn = 'No'
        GROUP BY 1, 2, 3
    )
    SELECT
        s.contract, s.internet_service, s.payment_method,
        a.active_customers, a.active_mrr,
        ROUND(100.0 * s.churn_rate, 1) AS historical_churn_rate_pct,
        ROUND(a.active_mrr * s.churn_rate, 2) AS projected_mrr_at_risk,
        ROUND(a.active_mrr * s.churn_rate * 12, 2) AS projected_annual_revenue_at_risk
    FROM segment_churn_rate s
    JOIN active_segment_mrr a USING (contract, internet_service, payment_method)
    ORDER BY projected_annual_revenue_at_risk DESC
) TO 'data/processed/revenue_at_risk_by_segment.csv' (HEADER, DELIMITER ',');

SELECT 'export complete' AS status;
