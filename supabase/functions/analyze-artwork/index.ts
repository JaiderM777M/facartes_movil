import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const MODELS = ["gemini-3.5-flash", "gemini-3.5-flash-lite", "gemini-flash-latest"];
const CATEGORIES = ["Pintura", "Escultura", "Arte digital", "Dibujo", "Fotografía", "Otro"];
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT =
  "Eres un curador de arte. Analiza esta obra y responde en español. " +
  "Devuelve: tags (5 a 6 etiquetas cortas de 1 o 2 palabras: técnica, tema, estilo, elementos), " +
  "category (una de la lista permitida) y description (2 a 3 frases objetivas que describan lo que se ve). " +
  "No inventes el autor ni el título.";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { image, mime } = await req.json();
    if (!image) return json({ error: "Falta la imagen" }, 400);
    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) return json({ error: "Falta GEMINI_API_KEY" }, 500);

    const body = {
      contents: [{ parts: [{ text: PROMPT }, { inline_data: { mime_type: mime || "image/jpeg", data: image } }] }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            tags: { type: "ARRAY", items: { type: "STRING" } },
            category: { type: "STRING", enum: CATEGORIES },
            description: { type: "STRING" },
          },
          required: ["tags", "category", "description"],
        },
      },
    };

    const errs: string[] = [];
    for (const model of MODELS) {
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify(body),
      });
      if (r.ok) {
        const data = await r.json();
        const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
        return json(JSON.parse(text));
      }
      errs.push(`${model}: ${r.status} ${(await r.text()).slice(0, 150)}`);
    }
    return json({ error: `Gemini no respondió: ${errs.join(" | ")}` }, 502);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(o: unknown, status = 200) {
  return new Response(JSON.stringify(o), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}