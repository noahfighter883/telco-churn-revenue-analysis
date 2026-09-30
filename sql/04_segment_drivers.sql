-- Which segments churn fastest? Minimum segment size (50) keeps small, noisy
-- combinations from dominating the ranking.

-- By contract type
SELECT
    contract,
    COUNT(*)                              AS customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
FROM customers
GROUP BY 1
ORDER BY churn_rate_pct DESC;

-- By internet service type
SELECT
    internet_service,
    COUNT(*)                              AS customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
FROM customers
GROUP BY 1
ORDER BY churn_rate_pct DESC;

-- By payment method
SELECT
    payment_method,
    COUNT(*)                              AS customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
FROM customers
GROUP BY 1
ORDER BY churn_rate_pct DESC;

-- Combined segment: contract x internet service x payment method
-- (the level of detail a retention team would actually target)
SELECT
    contract,
    internet_service,
    payment_method,
    COUNT(*)                              AS customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
FROM customers
GROUP BY 1, 2, 3
HAVING COUNT(*) >= 50
ORDER BY churn_rate_pct DESC
LIMIT 15;
