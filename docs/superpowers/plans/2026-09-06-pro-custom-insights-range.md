# Pro Custom Insights Range Implementation Plan

**Goal:** Add a Pro-gated custom date range to Insights so members can review arbitrary dates without changing the free day/week/month/quarter/year overview.

**Architecture:** Keep range state in `RootShellView`, where transactions, summary, distributions, category drill-down, and period title already share one calculated `DateInterval`. Add a small pure `InsightsCustomRangePolicy` in App UI to normalize inverted dates and include the complete end day. `InsightsView` owns the date-picker sheet and consults the existing `MembershipFeatureGate` before presenting it.

**Constraints:**

- Do not alter the existing free time dimensions or their navigation behavior.
- Use `.openAdvancedInsights`; the view must not inspect product IDs or a raw Pro flag.
- A custom range changes only the in-memory view filter and never mutates transactions or settings.
- Add all new copy in `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Keep the feature out of the V1 commercial benefits catalogue until the broader advanced-insights release criteria are met.

## Tasks

1. Add a failing pure-policy test for normalizing reversed dates and including the final calendar day.
2. Add `InsightsCustomRange` and `InsightsCustomRangePolicy`.
3. Extend the Insights period selector with a custom-range choice. Free users open the existing contextual paywall; Pro users receive a start/end date editor.
4. Apply the selected range in `RootShellView` to all Insights calculations and drill-down results; choosing a standard dimension clears the temporary custom range.
5. Add four-language copy and update `P0B-05`/Pro evidence only if warranted.
6. Verify focused tests, complete `swift test`, String Catalog JSON, `git diff --check`, and Debug iOS Simulator build before requesting commit confirmation.
