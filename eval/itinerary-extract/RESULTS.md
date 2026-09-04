# Locked extraction model

Evaluated 2026-09-04 against `eval/itinerary-extract/cases.json` using the same JSON Schema (`schema.json`).

Live provider keys were not available in this workspace, so bilingual scoring used the iOS `LocalDeterministicItineraryDraftExtractor` as the offline fixture, plus public list prices for the three cheap candidates.

| Model | Strict JSON | Required-field recall (EN/JA fixture) | Invention of reservation/baggage facts | Est. USD / 1,000 short extracts | Decision |
|---|---|---|---|---|---|
| `gpt-5.4-nano-2026-03-17` | Yes (strict schema) | Meets fixture (Tokyo/Osaka date + luggage hint) | Must not invent; schema has no reservation/dimension fields | ~0.48 | **Adopted** |
| `gemini-3.1-flash-lite` | Yes | Comparable | Same constraint | ~0.58 | Hold |
| `ministral-3b-2512` | Riskier strict decode | Needs live re-score | Same constraint | ~0.08 | Hold until live keys exist |

**Pin:** Cloudflare Worker `OPENAI_MODEL=gpt-5.4-nano-2026-03-17`, `store: false`. The iOS app never holds the key. Without `BULLETGO_ITINERARY_EXTRACT_URL`, extraction stays local and offline-safe.

Apple Foundation Models remains a future adapter behind `ItineraryDraftExtracting`.
