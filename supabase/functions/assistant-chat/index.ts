import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const MODELS = ["gemini-3.5-flash", "gemini-3.5-flash-lite", "gemini-flash-latest"];
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { messages } = await req.json();
    if (!Array.isArray(messages) || messages.length === 0) return json({ error: "Faltan mensajes" }, 400);

    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) return json({ error: "Falta GEMINI_API_KEY" }, 500);

    // Cliente con la sesión del usuario: aplica las mismas reglas de seguridad (RLS).
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { data: arts, error } = await sb
      .from("artworks")
      .select("id,title,description,category,technique,year,tags,profiles!artworks_user_id_fkey(name)")
      .order("created_at", { ascending: false })
      .limit(80);
    if (error) return json({ error: error.message }, 500);

    const ids = new Set((arts ?? []).map((a: any) => a.id));
    const catalog = (arts ?? [])
      .map((a: any) =>
        `- id:${a.id} | "${a.title}" | ${a.category} | ${a.technique ?? "s/d"} | ${a.year ?? "s/d"} | ` +
        `etiquetas: ${(a.tags ?? []).join(", ")} | autor: ${a.profiles?.name ?? "s/d"} | ${a.description ?? ""}`)
      .join("\n");

    const system =
      "Eres el asistente de FACARTES Móvil, una galería de arte universitaria. Responde en español, " +
      "breve (máximo 4 frases). Si el usuario pide ver, buscar o recomendar obras, elige de 1 a 4 ids " +
      "EXACTOS del catálogo que mejor coincidan y devuélvelos en artwork_ids. Si ninguna coincide, dilo " +
      "y deja artwork_ids vacío. Nunca inventes obras ni ids. Las preguntas generales de arte " +
      "(técnicas, estilos) respóndelas con conocimiento general y artwork_ids vacío.\n\nCATÁLOGO:\n" +
      (catalog || "(vacío)");

    const contents = messages.slice(-10).map((m: any) => ({
      role: m.role === "model" ? "model" : "user",
      parts: [{ text: String(m.text ?? "").slice(0, 1000) }],
    }));

    const body = {
      systemInstruction: { parts: [{ text: system }] },
      contents,
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            text: { type: "STRING" },
            artwork_ids: { type: "ARRAY", items: { type: "STRING" } },
          },
          required: ["text", "artwork_ids"],
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
        const out = JSON.parse(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}");
        out.artwork_ids = (out.artwork_ids ?? []).filter((id: string) => ids.has(id));
        return json(out);
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