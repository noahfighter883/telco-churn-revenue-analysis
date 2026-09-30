-- Data quality assertions on the cleaned `customers` view, run right after load
-- and before any analysis. Each row is a check: expected vs. actual, PASS/FAIL.
-- These don't halt the pipeline on failure (that would need application logic
-- around the CLI), but a FAIL here should be caught by reading the output
-- before trusting anything downstream.

SELECT 'row_count_matches_expected_7043' AS check_name,
       7043 AS expected,
       COUNT(*) AS actual,
       CASE WHEN COUNT(*) = 7043 THEN 'PASS' ELSE 'FAIL' END AS result
FROM customers

UNION ALL
SELECT 'no_duplicate_customer_id',
       0,
       COUNT(*) - COUNT(DISTINCT customer_id),
       CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'PASS' ELSE 'FAIL' END
FROM customers

UNION ALL
SELECT 'churn_is_yes_or_no',
       0,
       COUNT(*) FILTER (WHERE churn NOT IN ('Yes', 'No')),
       CASE WHEN COUNT(*) FILTER (WHERE churn NOT IN ('Yes', 'No')) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM customers

UNION ALL
SELECT 'monthly_charges_non_negative_and_not_null',
       0,
       COUNT(*) FILTER (WHERE monthly_charges < 0 OR monthly_charges IS NULL),
       CASE WHEN COUNT(*) FILTER (WHERE monthly_charges < 0 OR monthly_charges IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM customers

UNION ALL
SELECT 'tenure_non_negative_and_not_null',
       0,
       COUNT(*) FILTER (WHERE tenure < 0 OR tenure IS NULL),
       CASE WHEN COUNT(*) FILTER (WHERE tenure < 0 OR tenure IS NULL) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM customers

UNION ALL
SELECT 'senior_citizen_is_0_or_1',
       0,
       COUNT(*) FILTER (WHERE senior_citizen NOT IN (0, 1)),
       CASE WHEN COUNT(*) FILTER (WHERE senior_citizen NOT IN (0, 1)) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM customers

UNION ALL
-- total_charges is expected to be NULL only for brand-new signups (tenure = 0) --
-- see sql/01_load_sources.sql. A NULL at any other tenure would be unexpected.
SELECT 'total_charges_null_only_for_new_signups',
       0,
       COUNT(*) FILTER (WHERE total_charges IS NULL AND tenure <> 0),
       CASE WHEN COUNT(*) FILTER (WHERE total_charges IS NULL AND tenure <> 0) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM customers;
