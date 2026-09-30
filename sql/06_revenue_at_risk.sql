-- Revenue at risk: a high churn % on a small/cheap segment matters less than a
-- moderate churn % on a large/expensive one. This ranks by projected dollars,
-- not raw churn rate, using each segment's own historical churn rate applied
-- to its currently-active MRR.

WITH segment_churn_rate AS (
    SELECT
        contract,
        internet_service,
        payment_method,
        COUNT(*)                                                          AS segment_size,
        COUNT(*) FILTER (WHERE churn = 'Yes') / CAST(COUNT(*) AS DOUBLE)  AS churn_rate
    FROM customers
    GROUP BY 1, 2, 3
    HAVING COUNT(*) >= 50
),
active_segment_mrr AS (
    SELECT
        contract,
        internet_service,
        payment_method,
        COUNT(*)                       AS active_customers,
        ROUND(SUM(monthly_charges), 2) AS active_mrr
    FROM customers
    WHERE churn = 'No'
    GROUP BY 1, 2, 3
)
SELECT
    s.contract,
    s.internet_service,
    s.payment_method,
    a.active_customers,
    a.active_mrr,
    ROUND(100.0 * s.churn_rate, 1)                          AS historical_churn_rate_pct,
    ROUND(a.active_mrr * s.churn_rate, 2)                   AS projected_mrr_at_risk,
    ROUND(a.active_mrr * s.churn_rate * 12, 2)              AS projected_annual_revenue_at_risk
FROM segment_churn_rate s
JOIN active_segment_mrr a
    ON s.contract = a.contract
   AND s.internet_service = a.internet_service
   AND s.payment_method = a.payment_method
ORDER BY projected_annual_revenue_at_risk DESC
LIMIT 15;

-- Historical LTV proxy for churned customers, by contract type
-- (tenure_months * monthly_charges as a simple realized-lifetime-value stand-in)
SELECT
    contract,
    COUNT(*)                                              AS churned_customers,
    ROUND(AVG(tenure * monthly_charges), 2)               AS avg_realized_ltv,
    ROUND(AVG(tenure), 1)                                 AS avg_tenure_months
FROM customers
WHERE churn = 'Yes'
GROUP BY 1
ORDER BY avg_realized_ltv ASC;
