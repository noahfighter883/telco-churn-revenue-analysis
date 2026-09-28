# Findings: Churn & Revenue-at-Risk

## Question

Which customer segments are churning fastest, and how much Monthly Recurring Revenue is at risk if nothing changes?

## Headline numbers

- Overall churn rate: **26.5%** (1,869 of 7,043 customers) — [sql/02_churn_overview.sql](../sql/02_churn_overview.sql)
- Current MRR (active customers): **$316,986**
- MRR already lost to churned customers: **$139,131** (**30.5%** of total MRR — churned customers skew slightly toward higher monthly bills than the base as a whole)

## Finding

**The single highest-risk segment is Month-to-month contract + Fiber optic internet + Electronic check payment: 1,307 customers, a 60.4% churn rate, and $330,812 in projected annual revenue at risk** ([sql/04_revenue_at_risk.sql](../sql/04_revenue_at_risk.sql)). That's not just the highest churn rate of any segment with at least 50 customers — it's also the highest dollar exposure, by a wide margin: the next-largest segment (month-to-month + fiber + bank transfer) carries $86,376/year at risk, less than a third as much. Here the two rankings agree, but a few rows down they diverge in a way worth flagging: the One year + Fiber optic + Electronic check segment churns at a comparatively modest 26.0%, yet still lands in the top 7 by dollar exposure ($44,607/year), purely because fiber optic customers carry a higher monthly bill. A segment doesn't need the highest churn rate to be worth acting on if the price point is high enough.

Three variables independently correlate with churn, and they stack:
- **Contract type** is the strongest single driver — month-to-month churns at 42.7% vs. 11.3% (one year) and 2.8% (two year).
- **Internet service** matters almost as much — fiber optic churns at 41.9% vs. 19.0% for DSL, despite fiber being the premium product. That's counterintuitive enough to be worth investigating as a product/pricing issue, not just a "loyalty" one.
- **Payment method** shows the same pattern independent of the other two — electronic check churns at 45.3%, roughly 2.5–3x every automatic payment method (15–17%). Since this holds across contract types, it looks less like a proxy for commitment level and more like friction in the payment experience itself.

Churn is also heavily front-loaded by tenure: customers in their first 3 months churn at 56.2%, dropping to 39.1% (4–12 months), 28.7% (13–24 months), and 14.0% (25+ months). This is a distinct problem from the contract/payment story above — it points to an onboarding or early-engagement gap, not a pricing or billing one.

One more asymmetry worth naming: when a two-year contract customer does churn (rare — only 48 in this dataset), they'd built an average of $5,442 in realized lifetime value over 61 months, compared to $1,164 over 14 months for a churned month-to-month customer. Two-year churn is rare, but each loss is worth roughly 4.7x more than a typical month-to-month loss.

## Recommendation

1. **Prioritize retention outreach to the month-to-month + fiber optic + electronic check segment first.** It's the top segment on both churn rate and dollar exposure, so there's no tradeoff to weigh — this is unambiguously where a retention budget should go first, at $330,812/year in exposure.
2. **Treat electronic check as its own workstream, separate from contract upsells.** Since it correlates with elevated churn across every contract tier, a targeted push to migrate electronic-check customers to autopay (credit card or bank transfer) could reduce churn on its own, independent of any contract-length conversation — worth testing as a lower-cost intervention before assuming every fix requires a contract upgrade.
3. **Build a first-90-day engagement program.** The 56.2% churn rate in months 0–3 is a different problem from the contract/payment story and won't be solved by the same lever — this needs an onboarding fix, not a pricing or billing one.
4. **Don't ignore two-year churners just because the volume is low.** At ~4.7x the LTV of a typical month-to-month loss, even a handful of retained two-year customers can be worth a disproportionate amount — worth a lightweight "flag and personally reach out" process for this small but high-value group.

## Caveats

- This is IBM's demo Telco dataset — a single snapshot, not a longitudinal panel, so "churn" here means "ever churned," not "churned in a specific period." The revenue-at-risk figures are a projection based on each segment's historical churn rate, not a forecast from time-series data.
- Correlation, not causation: month-to-month contracts, fiber optic, and electronic check may all partly proxy for the same underlying customer type (e.g., more price-sensitive, less "locked in") rather than each independently causing churn. The fact that all three show elevated churn together doesn't prove three separate fixes are needed — some of the effect could be overlapping.
- The fiber optic churn result in particular deserves a service-quality check before assuming it's a payment/contract story — a premium product churning at 2x the DSL rate could equally point to a fiber-specific product or support issue not captured in this dataset.
- `TotalCharges` has 11 blank values, all customers with `tenure = 0` (brand-new signups) — handled as NULL in [sql/01_load_sources.sql](../sql/01_load_sources.sql). This doesn't affect the churn-rate or MRR figures above, but those 11 rows are excluded from the LTV-proxy calculation.
- The LTV proxy (`tenure × monthly_charges`) is a simple stand-in, not a true margin-based lifetime value — it ignores acquisition cost and any cost-to-serve differences between segments.
