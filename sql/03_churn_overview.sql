-- Headline numbers: overall churn rate, current MRR, and MRR already lost.

-- Overall churn rate
SELECT
    COUNT(*)                                       AS total_customers,
    COUNT(*) FILTER (WHERE churn = 'Yes')          AS churned_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
FROM customers;

-- Current MRR (active customers only) vs. MRR already lost to churned customers
SELECT
    ROUND(SUM(monthly_charges) FILTER (WHERE churn = 'No'), 2)  AS current_mrr,
    ROUND(SUM(monthly_charges) FILTER (WHERE churn = 'Yes'), 2) AS mrr_lost_to_churn,
    ROUND(
        100.0 * SUM(monthly_charges) FILTER (WHERE churn = 'Yes')
        / SUM(monthly_charges), 1
    ) AS pct_of_total_mrr_already_lost
FROM customers;

-- Churn rate by tenure bucket -- new customers churn very differently than long-tenured ones
SELECT
    CASE
        WHEN tenure <= 3  THEN '0-3 months'
        WHEN tenure <= 12 THEN '4-12 months'
        WHEN tenure <= 24 THEN '13-24 months'
        ELSE '25+ months'
    END AS tenure_bucket,
    COUNT(*)                                  AS customers,
    COUNT(*) FILTER (WHERE churn = 'Yes')     AS churned,
    ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
FROM customers
GROUP BY 1
ORDER BY MIN(tenure);
