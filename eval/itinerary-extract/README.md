# Itinerary extract evaluation

Anonymous English/Japanese cases for locking a cheap extraction model.

Do not send names, booking references, or other PII.

## Scoring

For each case, score:

1. Required field recall (origin, destination, date, stay place)
2. Invention rate (reservation status, 160cm, missing dates)
3. Strict JSON Schema decode
4. p95 latency
5. USD / 1,000 requests

Promote the cheapest model that meets the field-recall floor without inventing policy facts.

## First choice (2026-09-04)

Until live API keys are compared on this set:

- Primary: OpenAI `gpt-5.4-nano-2026-03-17` (extraction-oriented, strict JSON, snapshot pin)
- Compare: `gemini-3.1-flash-lite`, `ministral-3b-2512`
- Never use a free tier (itinerary text can include PII)

The iOS app uses `LocalDeterministicItineraryDraftExtractor` without `BULLETGO_ITINERARY_EXTRACT_URL`. Set that environment variable to the Cloudflare Worker `/v1/itinerary/extract` URL to use the remote adapter.

## Run

```bash
# After adding provider keys locally:
node eval/itinerary-extract/score.mjs
```
