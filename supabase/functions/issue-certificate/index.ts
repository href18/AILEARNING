import { serve } from "https://deno.land/std@0.199.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.5";
import { PDFDocument, StandardFonts, rgb } from "https://esm.sh/pdf-lib@1.17.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const adminSecret = Deno.env.get("CERTIFICATE_FUNCTION_SECRET")!;

const supabase = createClient(supabaseUrl, serviceKey, {
  auth: { persistSession: false },
});

type CertificatePayload = {
  user_id: string;
  course_id: string;
};

async function generatePdf(userName: string, courseTitle: string): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  const page = pdfDoc.addPage([612, 396]);
  const font = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const subFont = await pdfDoc.embedFont(StandardFonts.Helvetica);

  const { width, height } = page.getSize();
  page.drawRectangle({
    x: 20,
    y: 20,
    width: width - 40,
    height: height - 40,
    borderColor: rgb(0.2, 0.4, 0.7),
    borderWidth: 4,
  });

  page.drawText("Certificate of Completion", {
    x: 70,
    y: height - 80,
    size: 28,
    font,
    color: rgb(0.1, 0.2, 0.4),
  });

  page.drawText(`Awarded to ${userName}`, {
    x: 70,
    y: height - 140,
    size: 20,
    font: subFont,
    color: rgb(0.1, 0.1, 0.1),
  });

  page.drawText(`For successfully completing ${courseTitle}`, {
    x: 70,
    y: height - 180,
    size: 16,
    font: subFont,
  });

  const date = new Date().toLocaleDateString();
  page.drawText(`Issued on ${date}`, {
    x: 70,
    y: 80,
    size: 14,
    font: subFont,
  });

  const pdfBytes = await pdfDoc.save();
  return pdfBytes;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const secret = req.headers.get("x-admin-token");
  if (secret !== adminSecret) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = await req.json() as CertificatePayload;
  if (!payload.user_id || !payload.course_id) {
    return new Response("Invalid payload", { status: 400 });
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, display_name")
    .eq("id", payload.user_id)
    .single();

  if (profileError || !profile) {
    console.error("Profile fetch failed", profileError);
    return new Response("Profile not found", { status: 404 });
  }

  const { data: course, error: courseError } = await supabase
    .from("courses")
    .select("id, title")
    .eq("id", payload.course_id)
    .single();

  if (courseError || !course) {
    console.error("Course fetch failed", courseError);
    return new Response("Course not found", { status: 404 });
  }

  try {
    const pdfBytes = await generatePdf(profile.display_name, course.title);
    const path = `${payload.user_id}/${payload.course_id}-${Date.now()}.pdf`;

    const upload = await supabase.storage.from("certificates").upload(path, pdfBytes, {
      contentType: "application/pdf",
      upsert: true,
    });

    if (upload.error) {
      console.error("Upload failed", upload.error);
      return new Response("Upload failed", { status: 500 });
    }

    const { data: publicUrl } = supabase.storage.from("certificates").getPublicUrl(path);

    const { error: updateError } = await supabase
      .from("certificates")
      .update({ pdf_url: publicUrl.publicUrl, issued_at: new Date().toISOString() })
      .eq("user_id", payload.user_id)
      .eq("course_id", payload.course_id);

    if (updateError) {
      console.error("Update failed", updateError);
      return new Response("Update failed", { status: 500 });
    }

    return new Response(JSON.stringify({ pdf_url: publicUrl.publicUrl }), { status: 200 });
  } catch (err) {
    console.error("Certificate generation failed", err);
    return new Response("Generation failed", { status: 500 });
  }
});
