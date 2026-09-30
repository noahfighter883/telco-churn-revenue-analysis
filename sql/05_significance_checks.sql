-- Chi-square test of independence for the two most surprising segment
-- drivers from sql/04_segment_drivers.sql: is the churn gap for electronic
-- check, and for fiber optic, real or could it plausibly be noise?
--
-- 2x2 contingency table (group vs. everyone else) x (churned vs. retained).
-- Sample sizes here are in the hundreds to thousands, so the standard
-- (uncorrected) chi-square approximation is appropriate -- Yates' continuity
-- correction is only needed when an expected cell count is small (<5), which
-- doesn't happen with segments this large. Critical value for 1 degree of
-- freedom at alpha=0.05 is 3.841 (standard chi-square table).

-- Electronic check vs. all other payment methods
WITH grp AS (
    SELECT
        CASE WHEN payment_method = 'Electronic check' THEN 'Electronic check' ELSE 'All other payment methods' END AS grp,
        churn
    FROM customers
),
counts AS (
    SELECT grp,
        COUNT(*) FILTER (WHERE churn = 'Yes') AS churned,
        COUNT(*) FILTER (WHERE churn = 'No')  AS retained,
        COUNT(*) AS total
    FROM grp
    GROUP BY grp
),
totals AS (
    SELECT SUM(churned) AS total_churned, SUM(retained) AS total_retained, SUM(total) AS grand_total FROM counts
),
expected AS (
    SELECT
        c.grp, c.churned, c.retained, c.total,
        c.total * t.total_churned  / t.grand_total AS expected_churned,
        c.total * t.total_retained / t.grand_total AS expected_retained
    FROM counts c CROSS JOIN totals t
),
chi2_parts AS (
    SELECT
        POWER(churned  - expected_churned, 2)  / expected_churned  +
        POWER(retained - expected_retained, 2) / expected_retained AS cell_contribution
    FROM expected
)
SELECT
    'Electronic check vs. all other payment methods' AS comparison,
    (SELECT total   FROM counts WHERE grp = 'Electronic check') AS group_n,
    ROUND(100.0 * (SELECT churned FROM counts WHERE grp = 'Electronic check') / (SELECT total FROM counts WHERE grp = 'Electronic check'), 1) AS group_churn_rate_pct,
    ROUND(100.0 * (SELECT churned FROM counts WHERE grp = 'All other payment methods') / (SELECT total FROM counts WHERE grp = 'All other payment methods'), 1) AS comparison_group_churn_rate_pct,
    ROUND((SELECT SUM(cell_contribution) FROM chi2_parts), 2) AS chi2_statistic,
    3.841 AS critical_value_alpha_0_05,
    CASE WHEN (SELECT SUM(cell_contribution) FROM chi2_parts) > 3.841 THEN 'Significant (p < 0.05)' ELSE 'Not significant' END AS result;

-- Fiber optic vs. all other internet service types
WITH grp AS (
    SELECT
        CASE WHEN internet_service = 'Fiber optic' THEN 'Fiber optic' ELSE 'All other internet service' END AS grp,
        churn
    FROM customers
),
counts AS (
    SELECT grp,
        COUNT(*) FILTER (WHERE churn = 'Yes') AS churned,
        COUNT(*) FILTER (WHERE churn = 'No')  AS retained,
        COUNT(*) AS total
    FROM grp
    GROUP BY grp
),
totals AS (
    SELECT SUM(churned) AS total_churned, SUM(retained) AS total_retained, SUM(total) AS grand_total FROM counts
),
expected AS (
    SELECT
        c.grp, c.churned, c.retained, c.total,
        c.total * t.total_churned  / t.grand_total AS expected_churned,
        c.total * t.total_retained / t.grand_total AS expected_retained
    FROM counts c CROSS JOIN totals t
),
chi2_parts AS (
    SELECT
        POWER(churned  - expected_churned, 2)  / expected_churned  +
        POWER(retained - expected_retained, 2) / expected_retained AS cell_contribution
    FROM expected
)
SELECT
    'Fiber optic vs. all other internet service' AS comparison,
    (SELECT total   FROM counts WHERE grp = 'Fiber optic') AS group_n,
    ROUND(100.0 * (SELECT churned FROM counts WHERE grp = 'Fiber optic') / (SELECT total FROM counts WHERE grp = 'Fiber optic'), 1) AS group_churn_rate_pct,
    ROUND(100.0 * (SELECT churned FROM counts WHERE grp = 'All other internet service') / (SELECT total FROM counts WHERE grp = 'All other internet service'), 1) AS comparison_group_churn_rate_pct,
    ROUND((SELECT SUM(cell_contribution) FROM chi2_parts), 2) AS chi2_statistic,
    3.841 AS critical_value_alpha_0_05,
    CASE WHEN (SELECT SUM(cell_contribution) FROM chi2_parts) > 3.841 THEN 'Significant (p < 0.05)' ELSE 'Not significant' END AS result;
