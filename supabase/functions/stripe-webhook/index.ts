import { serve } from "https://deno.land/std@0.199.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@12.16.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.5";

type PurchaseStatus = "paid" | "refunded" | "failed" | "requires_payment";

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const supabase = createClient(supabaseUrl, serviceKey, {
  auth: { persistSession: false },
});

async function updatePurchase(
  userId: string,
  courseId: string,
  status: PurchaseStatus,
  amountCents?: number | null,
  currency?: string | null,
  paymentIntent?: string | null,
) {
  const payload: Record<string, unknown> = {
    user_id: userId,
    course_id: courseId,
    status,
  };
  if (amountCents !== undefined && amountCents !== null) {
    payload.amount_cents = amountCents;
  }
  if (currency) {
    payload.currency = currency;
  }
  if (paymentIntent) {
    payload.stripe_payment_intent = paymentIntent;
  }

  const { error } = await supabase
    .from("purchases")
    .upsert(payload, { onConflict: "user_id,course_id" });

  if (error) {
    console.error("Failed to upsert purchase", error);
    throw error;
  }
}

serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return new Response("Missing signature", { status: 400 });
  }

  const rawBody = await req.text();
  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
  } catch (err) {
    console.error("Stripe signature verification failed", err);
    return new Response("Invalid signature", { status: 400 });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId = session.metadata?.user_id;
        const courseId = session.metadata?.course_id;

        if (!userId || !courseId) {
          console.error("Missing metadata", session.metadata);
          break;
        }

        const amount = session.amount_total ?? session.amount_subtotal ?? 0;
        const currency = session.currency ?? "usd";
        const paymentIntent = typeof session.payment_intent === "string"
          ? session.payment_intent
          : session.payment_intent?.id;

        await updatePurchase(userId, courseId, "paid", amount, currency, paymentIntent ?? undefined);

        const { error } = await supabase.rpc("enroll_in_course", {
          course_id: courseId,
          p_user_id: userId,
        });
        if (error) {
          console.error("Failed to enroll after payment", error);
        }
        break;
      }
      case "charge.refunded": {
        const charge = event.data.object as Stripe.Charge;
        const paymentIntent = typeof charge.payment_intent === "string"
          ? charge.payment_intent
          : charge.payment_intent?.id;
        const userId = charge.metadata?.user_id;
        const courseId = charge.metadata?.course_id;

        if (userId && courseId) {
          await updatePurchase(userId, courseId, "refunded", charge.amount_refunded ?? charge.amount, charge.currency, paymentIntent ?? undefined);
        }
        break;
      }
      case "payment_intent.payment_failed": {
        const intent = event.data.object as Stripe.PaymentIntent;
        const userId = intent.metadata?.user_id;
        const courseId = intent.metadata?.course_id;
        if (userId && courseId) {
          await updatePurchase(userId, courseId, "failed", intent.amount ?? undefined, intent.currency ?? undefined, intent.id);
        }
        break;
      }
      default:
        // ignore
        break;
    }
  } catch (err) {
    console.error("Error handling webhook", err);
    return new Response("Webhook error", { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), { status: 200 });
});
