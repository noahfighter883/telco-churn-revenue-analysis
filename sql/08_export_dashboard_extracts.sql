-- Export final aggregates to data/processed/ as CSVs for the Tableau dashboard.
-- Run this last, after 01-07 have been run against the same DuckDB file.

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
    ORDER BY sort_key
) TO 'data/processed/churn_by_tenure_bucket.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT contract, COUNT(*) AS customers,
           ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
    FROM customers GROUP BY 1
    ORDER BY churn_rate_pct DESC
) TO 'data/processed/churn_by_contract.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT internet_service, COUNT(*) AS customers,
           ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
    FROM customers GROUP BY 1
    ORDER BY churn_rate_pct DESC
) TO 'data/processed/churn_by_internet_service.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT payment_method, COUNT(*) AS customers,
           ROUND(100.0 * COUNT(*) FILTER (WHERE churn = 'Yes') / COUNT(*), 1) AS churn_rate_pct
    FROM customers GROUP BY 1
    ORDER BY churn_rate_pct DESC
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

COPY (
    WITH grp AS (
        SELECT CASE WHEN payment_method = 'Electronic check' THEN 'Electronic check' ELSE 'All other payment methods' END AS grp, churn
        FROM customers
    ),
    counts AS (
        SELECT grp, COUNT(*) FILTER (WHERE churn = 'Yes') AS churned, COUNT(*) FILTER (WHERE churn = 'No') AS retained, COUNT(*) AS total
        FROM grp GROUP BY grp
    ),
    totals AS (SELECT SUM(churned) AS total_churned, SUM(retained) AS total_retained, SUM(total) AS grand_total FROM counts),
    expected AS (
        SELECT c.grp, c.churned, c.retained, c.total,
               c.total * t.total_churned / t.grand_total AS expected_churned,
               c.total * t.total_retained / t.grand_total AS expected_retained
        FROM counts c CROSS JOIN totals t
    ),
    chi2_parts AS (
        SELECT POWER(churned - expected_churned, 2) / expected_churned + POWER(retained - expected_retained, 2) / expected_retained AS cell_contribution
        FROM expected
    )
    SELECT
        'Electronic check vs. all other payment methods' AS comparison,
        (SELECT total FROM counts WHERE grp = 'Electronic check') AS group_n,
        ROUND(100.0 * (SELECT churned FROM counts WHERE grp = 'Electronic check') / (SELECT total FROM counts WHERE grp = 'Electronic check'), 1) AS group_churn_rate_pct,
        ROUND(100.0 * (SELECT churned FROM counts WHERE grp = 'All other payment methods') / (SELECT total FROM counts WHERE grp = 'All other payment methods'), 1) AS comparison_group_churn_rate_pct,
        ROUND((SELECT SUM(cell_contribution) FROM chi2_parts), 2) AS chi2_statistic,
        3.841 AS critical_value_alpha_0_05,
        CASE WHEN (SELECT SUM(cell_contribution) FROM chi2_parts) > 3.841 THEN 'Significant (p < 0.05)' ELSE 'Not significant' END AS result

    UNION ALL

    SELECT * FROM (
        WITH grp AS (
            SELECT CASE WHEN internet_service = 'Fiber optic' THEN 'Fiber optic' ELSE 'All other internet service' END AS grp, churn
            FROM customers
        ),
        counts AS (
            SELECT grp, COUNT(*) FILTER (WHERE churn = 'Yes') AS churned, COUNT(*) FILTER (WHERE churn = 'No') AS retained, COUNT(*) AS total
            FROM grp GROUP BY grp
        ),
        totals AS (SELECT SUM(churned) AS total_churned, SUM(retained) AS total_retained, SUM(total) AS grand_total FROM counts),
        expected AS (
            SELECT c.grp, c.churned, c.retained, c.total,
                   c.total * t.total_churned / t.grand_total AS expected_churned,
                   c.total * t.total_retained / t.grand_total AS expected_retained
            FROM counts c CROSS JOIN totals t
        ),
        chi2_parts AS (
            SELECT POWER(churned - expected_churned, 2) / expected_churned + POWER(retained - expected_retained, 2) / expected_retained AS cell_contribution
            FROM expected
        )
        SELECT
            'Fiber optic vs. all other internet service' AS comparison,
            (SELECT total FROM counts WHERE grp = 'Fiber optic') AS group_n,
            ROUND(100.0 * (SELECT churned FROM counts WHERE grp = 'Fiber optic') / (SELECT total FROM counts WHERE grp = 'Fiber optic'), 1) AS group_churn_rate_pct,
            ROUND(100.0 * (SELECT churned FROM counts WHERE grp = 'All other internet service') / (SELECT total FROM counts WHERE grp = 'All other internet service'), 1) AS comparison_group_churn_rate_pct,
            ROUND((SELECT SUM(cell_contribution) FROM chi2_parts), 2) AS chi2_statistic,
            3.841 AS critical_value_alpha_0_05,
            CASE WHEN (SELECT SUM(cell_contribution) FROM chi2_parts) > 3.841 THEN 'Significant (p < 0.05)' ELSE 'Not significant' END AS result
    )
) TO 'data/processed/significance_checks.csv' (HEADER, DELIMITER ',');

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
    assumptions AS (SELECT 50.0 AS cost_per_customer_targeted),
    campaign AS (
        SELECT
            t.contract, t.internet_service, t.payment_method,
            t.active_customers, t.churn_rate, t.avg_monthly_bill,
            t.active_customers * t.churn_rate AS expected_churners_per_year,
            t.active_customers * a.cost_per_customer_targeted AS campaign_cost
        FROM top_segment t CROSS JOIN assumptions a
    )
    SELECT
        contract, internet_service, payment_method,
        active_customers,
        ROUND(100.0 * churn_rate, 1) AS historical_churn_rate_pct,
        ROUND(expected_churners_per_year, 0) AS expected_churners_per_year,
        ROUND(campaign_cost, 2) AS campaign_cost,
        eff.effectiveness_pct,
        ROUND(expected_churners_per_year * eff.effectiveness_pct / 100.0, 0) AS customers_retained,
        ROUND(expected_churners_per_year * eff.effectiveness_pct / 100.0 * avg_monthly_bill * 12, 2) AS revenue_saved_annual,
        ROUND(expected_churners_per_year * eff.effectiveness_pct / 100.0 * avg_monthly_bill * 12 - campaign_cost, 2) AS net_benefit,
        ROUND(100.0 * (expected_churners_per_year * eff.effectiveness_pct / 100.0 * avg_monthly_bill * 12 - campaign_cost) / campaign_cost, 1) AS roi_pct,
        ROUND(100.0 * campaign_cost / (expected_churners_per_year * avg_monthly_bill * 12), 1) AS breakeven_effectiveness_pct
    FROM campaign
    CROSS JOIN (SELECT 15 AS effectiveness_pct UNION ALL SELECT 25 UNION ALL SELECT 35) eff
    ORDER BY effectiveness_pct
) TO 'data/processed/retention_roi_scenario.csv' (HEADER, DELIMITER ',');

SELECT 'export complete' AS status;
