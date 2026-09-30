# Findings: Churn & Revenue-at-Risk

## Question

Which customer segments are churning fastest, and how much Monthly Recurring Revenue is at risk if nothing changes?

## Headline numbers

- Overall churn rate: **26.5%** (1,869 of 7,043 customers) — [sql/03_churn_overview.sql](../sql/03_churn_overview.sql)
- Current MRR (active customers): **$316,986**
- MRR already lost to churned customers: **$139,131** (**30.5%** of total MRR — churned customers skew slightly toward higher monthly bills than the base as a whole)
- Data quality checks (row count, duplicate IDs, valid category values, null patterns) all pass — [sql/02_data_quality_checks.sql](../sql/02_data_quality_checks.sql)

## Finding

**The single highest-risk segment is Month-to-month contract + Fiber optic internet + Electronic check payment: 1,307 customers, a 60.4% churn rate, and $330,812 in projected annual revenue at risk** ([sql/06_revenue_at_risk.sql](../sql/06_revenue_at_risk.sql)). That's not just the highest churn rate of any segment with at least 50 customers — it's also the highest dollar exposure, by a wide margin: the next-largest segment (month-to-month + fiber + bank transfer) carries $86,376/year at risk, less than a third as much. Here the two rankings agree, but a few rows down they diverge in a way worth flagging: the One year + Fiber optic + Electronic check segment churns at a comparatively modest 26.0%, yet still lands in the top 7 by dollar exposure ($44,607/year), purely because fiber optic customers carry a higher monthly bill. A segment doesn't need the highest churn rate to be worth acting on if the price point is high enough.

Three variables independently correlate with churn, and they stack:
- **Contract type** is the strongest single driver — month-to-month churns at 42.7% vs. 11.3% (one year) and 2.8% (two year).
- **Internet service** matters almost as much — fiber optic churns at 41.9% vs. 19.0% for DSL, despite fiber being the premium product. The multivariate model below rules out a simple pricing explanation (monthly charges isn't an independent predictor once internet type is controlled for), which points toward a product or service-quality issue specific to fiber optic, not just "it costs more."
- **Payment method** shows the same pattern independent of the other two — electronic check churns at 45.3%, roughly 2.5–3x every automatic payment method (15–17%). Since this holds across contract types, it looks less like a proxy for commitment level and more like friction in the payment experience itself.

Churn is also heavily front-loaded by tenure: customers in their first 3 months churn at 56.2%, dropping to 39.1% (4–12 months), 28.7% (13–24 months), and 14.0% (25+ months). This is a distinct problem from the contract/payment story above — it points to an onboarding or early-engagement gap, not a pricing or billing one.

One more asymmetry worth naming: when a two-year contract customer does churn (rare — only 48 in this dataset), they'd built an average of $5,442 in realized lifetime value over 61 months, compared to $1,164 over 14 months for a churned month-to-month customer. Two-year churn is rare, but each loss is worth roughly 4.7x more than a typical month-to-month loss.

## Is this real, or could it be noise?

Before recommending action on the electronic check and fiber optic findings, both were tested with a chi-square test of independence (group vs. everyone else, churned vs. retained) — [sql/05_significance_checks.sql](../sql/05_significance_checks.sql):

| Comparison | Group n | Group churn rate | Everyone else | χ² statistic | Result |
|---|---|---|---|---|---|
| Electronic check vs. all other payment methods | 2,365 | 45.3% | 17.1% | 642.0 | **Significant** (p < 0.05, critical value 3.841) |
| Fiber optic vs. all other internet service | 3,096 | 41.9% | 14.5% | 668.2 | **Significant** (p < 0.05, critical value 3.841) |

Both gaps are far past the significance threshold — this isn't sample-size noise. That said, see the caveat below on testing hypotheses we already spotted by eye in the same data.

## Does this hold up when you control for everything at once?

The chi-square tests above are univariate — each one compares a single factor against everyone else, one at a time. That leaves an open question flagged in the caveats below: contract type, internet service, and payment method could all partly be proxies for the same underlying customer, in which case testing them separately would overstate how many independent problems actually exist. [scripts/churn_model.py](../scripts/churn_model.py) answers this directly with a multivariate logistic regression — contract, internet service, payment method, tenure, monthly charges, and senior citizen status, all controlled for simultaneously (n=7,043; results in [data/processed/model_coefficients.csv](../data/processed/model_coefficients.csv)):

| Factor | Odds ratio | p-value | Significant (controlling for everything else)? |
|---|---|---|---|
| Month-to-month contract (vs. two year) | 4.76x | <0.001 | Yes |
| One year contract (vs. two year) | 2.20x | <0.001 | Yes |
| Fiber optic internet (vs. DSL) | 2.48x | <0.001 | Yes |
| No internet service (vs. DSL) | 0.46x | <0.001 | Yes (lower risk) |
| Electronic check (vs. credit card) | 1.64x | <0.001 | Yes |
| Bank transfer (vs. credit card) | 1.07x | 0.546 | **No** |
| Mailed check (vs. credit card) | 1.01x | 0.939 | **No** |
| Senior citizen | 1.41x | <0.001 | Yes |
| Tenure (per month) | 0.97x | <0.001 | Yes (protective) |
| Monthly charges (per dollar) | 1.004x | 0.176 | **No** |

Two things change the story here, not just confirm it:

1. **Contract, fiber optic, and electronic check are each independently real** — none of them wash out once you control for the other two, so the univariate findings weren't just each other in disguise. Senior citizen status also turns out to matter (1.41x), which hadn't shown up anywhere in the segment breakdowns because it was never cut that way.
2. **Two refinements to the earlier story.** First, the univariate "manual vs. automatic payment" framing was too broad — mailed check is *not* significantly different from credit card once everything else is controlled for; the effect is specific to electronic check, not manual payment in general. Second, and more important for the fiber-optic caveat below: **monthly charges itself is not a significant predictor once contract and internet type are already in the model.** That weighs against a simple "fiber optic churns more because it costs more" story — if price were the driver, it should show up as its own effect after controlling for internet type, and it doesn't. Something about fiber optic specifically (not just its price tag) is associated with churn.

As a secondary sanity check, a holdout-validated version of this same model (75/25 train/test split, never seeing the test rows during fitting) scores 79.6% accuracy and 0.840 ROC-AUC on data it hasn't seen — comfortably above the 73.5% naive baseline (always predicting "no churn"), so the pattern generalizes rather than being an artifact of this specific dataset split. Recall is a more modest 52.2%, meaning it misses close to half of actual churners if used as a hard yes/no classifier — expected for a model built for inference (which factors matter) rather than tuned for prediction (catch every churner), and not a concern for how it's used here.

## Recommendation

1. **Prioritize retention outreach to the month-to-month + fiber optic + electronic check segment first.** It's the top segment on both churn rate and dollar exposure, so there's no tradeoff to weigh — this is unambiguously where a retention budget should go first, at $330,812/year in exposure.
2. **Treat electronic check as its own workstream, separate from contract upsells.** Since it correlates with elevated churn across every contract tier, a targeted push to migrate electronic-check customers to autopay (credit card or bank transfer) could reduce churn on its own, independent of any contract-length conversation — worth testing as a lower-cost intervention before assuming every fix requires a contract upgrade.
3. **Build a first-90-day engagement program.** The 56.2% churn rate in months 0–3 is a different problem from the contract/payment story and won't be solved by the same lever — this needs an onboarding fix, not a pricing or billing one.
4. **Don't ignore two-year churners just because the volume is low.** At ~4.7x the LTV of a typical month-to-month loss, even a handful of retained two-year customers can be worth a disproportionate amount — worth a lightweight "flag and personally reach out" process for this small but high-value group.

## What would it cost to act on this?

Recommendation #1 is only actionable if it pencils out. [sql/07_retention_roi_scenario.sql](../sql/07_retention_roi_scenario.sql) models a retention campaign targeting all 518 active customers in the top segment, assuming a **$50 cost per customer targeted** (a placeholder — swap in real internal cost data) and using the segment's own historical churn rate (60.4%) to estimate ~313 expected churners/year without intervention. Campaign cost: **$25,900**.

| Campaign effectiveness | Customers retained | Revenue saved (annual) | Net benefit | ROI |
|---|---|---|---|---|
| 15% of expected churners retained | 47 | $49,622 | $23,722 | **92%** |
| 25% of expected churners retained | 78 | $82,703 | $56,803 | **219%** |
| 35% of expected churners retained | 109 | $115,784 | $89,884 | **347%** |

**Breakeven: the campaign only needs to retain 7.8% of the segment's expected churners to pay for itself.** That's a low bar relative to typical retention-offer response rates, which is the strongest argument for greenlighting this specific campaign over a more speculative one — the downside if it underperforms is small, and the upside if it hits even a modest effectiveness rate is a 2–4x return.

## Caveats

- This is IBM's demo Telco dataset — a single snapshot, not a longitudinal panel, so "churn" here means "ever churned," not "churned in a specific period." The revenue-at-risk figures are a projection based on each segment's historical churn rate, not a forecast from time-series data.
- Correlation, not causation, still applies even after the multivariate model: it confirms contract, fiber optic, and electronic check are statistically independent of *each other*, but none of this is a randomized experiment, so none of these associations are proven to be causal. A confound not in the model at all — income, household size, local competition, a customer's underlying price sensitivity — could still be driving several of these variables together.
- The significance tests (univariate chi-square and the multivariate model) both explore hypotheses already spotted by eye in the same dataset — this is a mild form of post-hoc testing, not pre-registered hypotheses tested on a held-out sample. The multivariate model and the holdout-validated accuracy above add real evidence the pattern isn't noise, but a stricter analysis would still validate on genuinely new data before treating any of this as settled.
- The fiber optic churn result deserves a service-quality check before assuming it's a payment/contract story — the multivariate model weakens the "it's just expensive" explanation (monthly charges isn't significant once internet type is controlled for) but can't distinguish between a genuine service/support issue and some other unmeasured factor specific to fiber customers.
- The logistic regression's ~80% accuracy and 0.84 ROC-AUC describe how well it fits *this* dataset — they're a sanity check that the model isn't nonsense, not a claim that it would perform this well on live, future customers, or that it should be deployed as a production scoring model as-is.
- `TotalCharges` has 11 blank values, all customers with `tenure = 0` (brand-new signups) — handled as NULL in [sql/01_load_sources.sql](../sql/01_load_sources.sql). This doesn't affect the churn-rate or MRR figures above, but those 11 rows are excluded from the LTV-proxy calculation.
- The LTV proxy (`tenure × monthly_charges`) is a simple stand-in, not a true margin-based lifetime value — it ignores acquisition cost and any cost-to-serve differences between segments.
- The ROI scenario's $50 cost-per-customer and the 15/25/35% effectiveness range are stated assumptions, not measured figures — this dataset has no real campaign-cost or response-rate data. Treat the ROI table as a sensitivity analysis showing "what would need to be true for this to pay off," not a forecast. The breakeven rate (7.8%) is the most assumption-robust number in the table, since it only depends on the cost assumption, not the effectiveness one.
