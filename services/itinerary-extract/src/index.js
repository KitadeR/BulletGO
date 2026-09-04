const SCHEMA = {
  name: "proposed_itinerary_draft",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["tripName", "startDate", "endDate", "items", "unresolved"],
    properties: {
      tripName: { type: ["string", "null"] },
      startDate: { type: ["string", "null"] },
      endDate: { type: ["string", "null"] },
      items: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: [
            "kind",
            "origin",
            "destination",
            "place",
            "title",
            "date",
            "time",
            "transport",
            "checkIn",
            "checkOut",
            "baggageHint",
            "sourceQuote",
            "confidence",
          ],
          properties: {
            kind: { type: "string", enum: ["leg", "stay", "activity", "tripNote", "baggageHint"] },
            origin: { type: ["string", "null"] },
            destination: { type: ["string", "null"] },
            place: { type: ["string", "null"] },
            title: { type: ["string", "null"] },
            date: { type: ["string", "null"] },
            time: { type: ["string", "null"] },
            transport: { type: ["string", "null"] },
            checkIn: { type: ["string", "null"] },
            checkOut: { type: ["string", "null"] },
            baggageHint: { type: ["string", "null"] },
            sourceQuote: { type: "string" },
            confidence: { type: "string", enum: ["low", "medium", "high"] },
          },
        },
      },
      unresolved: { type: "array", items: { type: "string" } },
    },
  },
};

const SYSTEM = `Extract only facts stated in the traveler's text into the JSON schema.
Do not invent reservation status, baggage dimensions, or missing dates.
Every item.sourceQuote must be a substring of the user text.
Use ISO dates YYYY-MM-DD when a calendar date is explicit.
If Tokyo to Osaka is not an existing known leg, propose a new leg.`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return Response.json({ ok: true });
    }
    if (request.method !== "POST" || url.pathname !== "/v1/itinerary/extract") {
      return Response.json({ error: "not_found" }, { status: 404 });
    }
    if (!env.OPENAI_API_KEY) {
      return Response.json({ error: "missing_key" }, { status: 500 });
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return Response.json({ error: "invalid_json" }, { status: 400 });
    }
    const text = String(payload.text ?? "").slice(0, 4000);
    if (!text.trim()) {
      return Response.json({ error: "empty_text" }, { status: 400 });
    }

    const body = {
      model: env.OPENAI_MODEL || "gpt-5.4-nano-2026-03-17",
      store: false,
      reasoning: { effort: "none" },
      input: [
        { role: "system", content: SYSTEM },
        {
          role: "user",
          content: `scope=${payload.scope ?? "trip"}\nknownLegs=${JSON.stringify(payload.knownLegs ?? [])}\ntext:\n${text}`,
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: SCHEMA.name,
          strict: true,
          schema: SCHEMA.schema,
        },
      },
    };

    const upstream = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });
    if (!upstream.ok) {
      return Response.json({ error: "upstream_failed" }, { status: 502 });
    }
    const result = await upstream.json();
    const outputText =
      result.output_text ??
      result.output?.flatMap((item) => item.content ?? []).find((part) => part.text)?.text;
    if (!outputText) {
      return Response.json({ error: "empty_model" }, { status: 502 });
    }
    return new Response(outputText, {
      headers: { "content-type": "application/json" },
    });
  },
};
