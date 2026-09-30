-- Turns the top revenue-at-risk segment (sql/06_revenue_at_risk.sql) into a
-- spend decision: what would a retention campaign targeting that segment
-- need to achieve to pay for itself, and what's the expected ROI at a few
-- plausible success rates?
--
-- ASSUMPTIONS (this dataset has no real campaign-cost data, so these are
-- stated placeholders -- swap in real internal cost/lift numbers if you have
-- them):
--   - $50 cost per customer targeted (a retention discount, voucher, or the
--     loaded cost of a support outreach -- whole segment is targeted, since
--     we can't know in advance which individual customers would've churned)
--   - "Effectiveness" = % of the segment's expected churners who are
--     retained because of the campaign. Shown across a 15/25/35% range
--     since we have no prior experiment to anchor a single number.
--   - 1-year horizon, using the segment's own historical churn rate as the
--     expected annual rate (same assumption flagged in 06_revenue_at_risk.sql)

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
           SUM(monthly_charges) AS active_mrr
    FROM customers
    WHERE churn = 'No'
    GROUP BY 1, 2, 3
),
top_segment AS (
    SELECT s.contract, s.internet_service, s.payment_method,
           a.active_customers, a.active_mrr, s.churn_rate,
           a.active_mrr / a.active_customers AS avg_monthly_bill
    FROM segment_churn_rate s
    JOIN active_segment_mrr a USING (contract, internet_service, payment_method)
    ORDER BY (a.active_mrr * s.churn_rate * 12) DESC
    LIMIT 1
),
assumptions AS (
    SELECT 50.0 AS cost_per_customer_targeted
),
campaign AS (
    SELECT
        t.contract, t.internet_service, t.payment_method,
        t.active_customers, t.churn_rate, t.avg_monthly_bill,
        t.active_customers * t.churn_rate AS expected_churners_per_year,
        t.active_customers * a.cost_per_customer_targeted AS campaign_cost
    FROM top_segment t CROSS JOIN assumptions a
)
-- Sensitivity table: ROI at a few plausible success rates
SELECT
    contract, internet_service, payment_method,
    active_customers,
    ROUND(100.0 * churn_rate, 1)               AS historical_churn_rate_pct,
    ROUND(expected_churners_per_year, 0)        AS expected_churners_per_year,
    ROUND(campaign_cost, 2)                     AS campaign_cost,
    eff.effectiveness_pct,
    ROUND(expected_churners_per_year * eff.effectiveness_pct / 100.0, 0) AS customers_retained,
    ROUND(expected_churners_per_year * eff.effectiveness_pct / 100.0 * avg_monthly_bill * 12, 2) AS revenue_saved_annual,
    ROUND(expected_churners_per_year * eff.effectiveness_pct / 100.0 * avg_monthly_bill * 12 - campaign_cost, 2) AS net_benefit,
    ROUND(100.0 * (expected_churners_per_year * eff.effectiveness_pct / 100.0 * avg_monthly_bill * 12 - campaign_cost) / campaign_cost, 1) AS roi_pct
FROM campaign
CROSS JOIN (SELECT 15 AS effectiveness_pct UNION ALL SELECT 25 UNION ALL SELECT 35) eff
ORDER BY effectiveness_pct;

-- Breakeven: minimum effectiveness rate needed for the campaign to pay for itself
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
           SUM(monthly_charges) AS active_mrr
    FROM customers
    WHERE churn = 'No'
    GROUP BY 1, 2, 3
),
top_segment AS (
    SELECT s.contract, s.internet_service, s.payment_method,
           a.active_customers, a.active_mrr, s.churn_rate,
           a.active_mrr / a.active_customers AS avg_monthly_bill
    FROM segment_churn_rate s
    JOIN active_segment_mrr a USING (contract, internet_service, payment_method)
    ORDER BY (a.active_mrr * s.churn_rate * 12) DESC
    LIMIT 1
),
assumptions AS (
    SELECT 50.0 AS cost_per_customer_targeted
),
campaign AS (
    SELECT
        t.contract, t.internet_service, t.payment_method,
        t.active_customers * t.churn_rate AS expected_churners_per_year,
        t.avg_monthly_bill,
        t.active_customers * a.cost_per_customer_targeted AS campaign_cost
    FROM top_segment t CROSS JOIN assumptions a
)
SELECT
    contract, internet_service, payment_method,
    ROUND(campaign_cost, 2) AS campaign_cost,
    ROUND(100.0 * campaign_cost / (expected_churners_per_year * avg_monthly_bill * 12), 1) AS breakeven_effectiveness_pct
FROM campaign;
