# BulletGO itinerary extract API

Cloudflare Worker at `POST /v1/itinerary/extract`.

The iOS app never holds the model API key. Set `OPENAI_API_KEY` as a Worker secret and pin `OPENAI_MODEL` to `gpt-5.4-nano-2026-03-17` until eval says otherwise.

```bash
npx wrangler secret put OPENAI_API_KEY
npx wrangler deploy
```

Then set `BULLETGO_ITINERARY_EXTRACT_URL` in the Xcode scheme to `https://<worker>/v1/itinerary/extract`.

Requests must stay under 4,000 characters. Responses are `store: false`. Logs must not include the raw itinerary text.
