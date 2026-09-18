# Personalized early-commit confidence

Synced from TigerClaw main on 2026-09-18.

The Lua sentence engine now separates model confidence from personalized early-commit confidence:

- `base_share`: pure model confidence; authoritative for strong evidence, truncated-strong and boundary closure.
- `share`: base confidence plus bounded personalization; used only for ordinary multi-generation evidence.

Supplement phrases add `min(0.75, supplement_score * 0.05)` to early-commit log confidence. Learning keeps the existing 9-based ranking curve and derives maturity from its equivalent accumulated weight, giving approximately `0 -> 0.5 -> 1.0` across the first, second and third stable observations. Learning contribution is capped at 0.75 and total personalization at 0.80.

The first correction changes ranking but adds no early confidence. Later explicit acceptance of the learned top candidate reinforces it; automatic early commit does not self-reinforce. Fully mature preferences stop adding redundant records until decay lowers their score. Learning plus beam truncation is still blocked from automatic commit, and empty-code commit remains model-only.

Thresholds match TigerClaw: ordinary `0.99`, strong `0.999`, boundary closure/empty-code strong `0.99999`, three ordinary generations or two strong generations, and retain three raw keys. Truncated evidence is retained and can only commit through model-only strong evidence.
