import { serve } from "https://deno.land/std@0.199.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.5";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, serviceKey, {
  auth: { persistSession: false },
});

export const schedule = { cron: "* * * * *" };

async function signPayload(secret: string, payload: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  const bytes = new Uint8Array(signature);
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
}

serve(async (_req) => {
  const { data: events, error } = await supabase
    .from("webhook_events")
    .select("id, event_type, payload, attempts, created_at")
    .is("delivered_at", null)
    .lt("attempts", 10)
    .order("created_at", { ascending: true })
    .limit(50);

  if (error) {
    console.error("Failed to fetch events", error);
    return new Response(JSON.stringify({ success: false, error: error.message }), { status: 500 });
  }

  if (!events || events.length === 0) {
    return new Response(JSON.stringify({ success: true, processed: 0 }), { status: 200 });
  }

  let processed = 0;
  for (const event of events) {
    const payloadBody = {
      id: event.id,
      type: event.event_type,
      data: event.payload,
      created_at: event.created_at,
    };
    const body = JSON.stringify(payloadBody);

    const { data: endpoints, error: endpointError } = await supabase
      .from("webhook_endpoints")
      .select("id, url, secret")
      .eq("is_active", true)
      .contains("event_types", [event.event_type]);

    if (endpointError) {
      console.error("Failed to fetch endpoints", endpointError);
      await supabase
        .from("webhook_events")
        .update({ attempts: event.attempts + 1, last_error: endpointError.message })
        .eq("id", event.id);
      continue;
    }

    let allDelivered = true;
    let lastError: string | null = null;

    for (const endpoint of endpoints ?? []) {
      try {
        const signature = await signPayload(endpoint.secret, body);
        const response = await fetch(endpoint.url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Webhook-Signature": signature,
            "Idempotency-Key": event.id,
          },
          body,
        });

        if (!response.ok) {
          allDelivered = false;
          lastError = `HTTP ${response.status}`;
          console.error(`Delivery failed for endpoint ${endpoint.id}`, response.statusText);
        }
      } catch (err) {
        allDelivered = false;
        lastError = err instanceof Error ? err.message : String(err);
        console.error(`Error delivering webhook to ${endpoint.id}`, err);
      }
    }

    if (allDelivered && (endpoints?.length ?? 0) > 0) {
      await supabase
        .from("webhook_events")
        .update({ delivered_at: new Date().toISOString(), attempts: event.attempts })
        .eq("id", event.id);
    } else {
      await supabase
        .from("webhook_events")
        .update({ attempts: event.attempts + 1, last_error: lastError ?? "no endpoints" })
        .eq("id", event.id);
    }

    processed += 1;
  }

  return new Response(JSON.stringify({ success: true, processed }), { status: 200 });
});
