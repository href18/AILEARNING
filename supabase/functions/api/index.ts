// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Missing Supabase environment variables");
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { persistSession: false },
});

type Json = Record<string, any> | Json[] | string | number | boolean | null;

type Handler = (req: Request, params: URLSearchParams, body?: any) => Promise<Response>;

const jsonResponse = (body: Json, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const withErrorBoundary = (handler: Handler): Handler => {
  return async (req, params, body) => {
    try {
      return await handler(req, params, body);
    } catch (error) {
      console.error("Edge function error", error);
      return jsonResponse({ error: "internal_error", message: String(error) }, 500);
    }
  };
};

const requireMethod = (req: Request, allowed: string[]) => {
  if (!allowed.includes(req.method)) {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  return null;
};

const getLocale = (req: Request) => {
  const header = req.headers.get("accept-language");
  if (!header) return "nb";
  const preferred = header.split(",")[0]?.split("-")[0];
  return preferred === "en" ? "en" : "nb";
};

const listCourses: Handler = withErrorBoundary(async (req) => {
  const methodGuard = requireMethod(req, ["GET", "POST"]);
  if (methodGuard) return methodGuard;

  const locale = getLocale(req);

  const { data, error } = await supabase
    .from("courses")
    .select(`
      id, code, status, duration_minutes, certificate_valid_months,
      course_i18n:course_i18n!inner(locale, title, summary),
      modules:modules(id, type, position, duration_seconds,
        module_i18n:module_i18n(locale, title, body_md, video_url, simulation_json),
        quiz:quizzes(id, passing_score,
          questions:quiz_questions(id, body, type, explanation,
            options:quiz_options(id, body, is_correct)
          )
        )
      )
    `)
    .eq("status", "published")
    .order("code");

  if (error) {
    console.error(error);
    return jsonResponse({ error: error.message }, 400);
  }

  const formatted = data?.map((course: any) => ({
    id: course.id,
    code: course.code,
    durationMinutes: course.duration_minutes,
    certificateValidMonths: course.certificate_valid_months,
    title: course.course_i18n?.[0]?.title,
    summary: course.course_i18n?.[0]?.summary,
    modules: course.modules
      ?.sort((a: any, b: any) => a.position - b.position)
      .map((module: any) => ({
        id: module.id,
        type: module.type,
        position: module.position,
        durationSeconds: module.duration_seconds,
        title: module.module_i18n?.[0]?.title,
        body: module.module_i18n?.[0]?.body_md,
        videoUrl: module.module_i18n?.[0]?.video_url,
        simulation: module.module_i18n?.[0]?.simulation_json,
        quiz: module.quiz
          ? {
              id: module.quiz.id,
              passingScore: module.quiz.passing_score,
              questions: module.quiz.questions?.map((q: any) => ({
                id: q.id,
                body: q.body,
                type: q.type,
                explanation: q.explanation,
                options: q.options?.map((opt: any) => ({
                  id: opt.id,
                  body: opt.body,
                  isCorrect: opt.is_correct,
                })),
              })),
            }
          : null,
      })),
  }));

  return jsonResponse({ courses: formatted ?? [] });
});

const submitQuiz: Handler = withErrorBoundary(async (req, params, body) => {
  const methodGuard = requireMethod(req, ["POST"]);
  if (methodGuard) return methodGuard;

  const moduleId = body?.module_id ?? params.get("module_id");
  if (!moduleId) {
    return jsonResponse({ error: "missing_module_id" }, 400);
  }

  const answers = body?.answers as Record<string, string[]>;

  const { data: quizData, error } = await supabase
    .from("quizzes")
    .select(`id, passing_score, module_id,
      questions:quiz_questions(id, type, explanation,
        options:quiz_options(id, is_correct))
    `)
    .eq("module_id", moduleId)
    .maybeSingle();

  if (error || !quizData) {
    return jsonResponse({ error: error?.message ?? "quiz_not_found" }, 404);
  }

  let score = 0;
  const questionCount = quizData.questions?.length ?? 0;
  const details: any[] = [];

  for (const question of quizData.questions ?? []) {
    const given = new Set(answers?.[question.id] ?? []);
    const correctOptions = (question.options ?? []).filter((o: any) => o.is_correct);
    const correctSet = new Set(correctOptions.map((o: any) => o.id));

    const isCorrect = given.size === correctSet.size && [...given].every((id) => correctSet.has(id));
    if (isCorrect) {
      score += 1;
    }

    details.push({
      questionId: question.id,
      isCorrect,
      explanation: question.explanation,
      correctOptionIds: [...correctSet],
    });
  }

  const scorePercent = questionCount === 0 ? 0 : Math.round((score / questionCount) * 100);
  const passed = scorePercent >= quizData.passing_score;

  return jsonResponse({
    score: scorePercent,
    passed,
    details,
  });
});

const routes: Record<string, Handler> = {
  "GET /courses": listCourses,
  "POST /courses": listCourses,
  "POST /quiz": submitQuiz,
};

serve(async (req) => {
  const url = new URL(req.url);
  const bodyText = req.method !== "GET" ? await req.text() : undefined;
  let parsedBody: any;
  if (bodyText) {
    try {
      parsedBody = JSON.parse(bodyText);
    } catch {
      parsedBody = bodyText;
    }
  }

  const hintedPath = req.headers.get("x-edge-path") ?? (typeof parsedBody === "object" && parsedBody?.path) ?? url.pathname;
  const normalisedPath = hintedPath.replace(/\/$/, "") || "/";
  const key = `${req.method} ${normalisedPath}`;

  const handler = routes[key];
  if (!handler) {
    return jsonResponse({ error: "not_found", path: normalisedPath }, 404);
  }
  return handler(req, url.searchParams, parsedBody);
});
