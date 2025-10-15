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

const courseSelect = `
      id, code, status, duration_minutes, certificate_valid_months,
      course_i18n:course_i18n(locale, title, summary),
      modules:modules(id, type, position, duration_seconds,
        module_i18n:module_i18n(locale, title, body_md, video_url, simulation_json),
        quiz:quizzes(id, passing_score,
          questions:quiz_questions(id, body, type, explanation,
            options:quiz_options(id, body, is_correct)
          )
        )
      )
    `;

type FetchCoursesOptions = {
  id?: string;
  skipStatusFilter?: boolean;
};

const normaliseCourse = (course: any, locale: string) => ({
  id: course.id,
  code: course.code,
  durationMinutes: course.duration_minutes,
  certificateValidMonths: course.certificate_valid_months,
  title:
    course.course_i18n?.find((item: any) => item.locale === locale)?.title ??
    course.course_i18n?.[0]?.title,
  summary:
    course.course_i18n?.find((item: any) => item.locale === locale)?.summary ??
    course.course_i18n?.[0]?.summary,
  modules: (course.modules ?? [])
    .sort((a: any, b: any) => (a.position ?? 0) - (b.position ?? 0))
    .map((module: any) => ({
      id: module.id,
      type: module.type,
      position: module.position,
      durationSeconds: module.duration_seconds,
      title:
        module.module_i18n?.find((item: any) => item.locale === locale)?.title ??
        module.module_i18n?.[0]?.title,
      body: module.module_i18n?.find((item: any) => item.locale === locale)?.body_md ??
        module.module_i18n?.[0]?.body_md,
      videoUrl: module.module_i18n?.find((item: any) => item.locale === locale)?.video_url ??
        module.module_i18n?.[0]?.video_url,
      simulation: module.module_i18n?.find((item: any) => item.locale === locale)?.simulation_json ??
        module.module_i18n?.[0]?.simulation_json,
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
});

const fetchCourses = async (locale: string, options: FetchCoursesOptions = {}) => {
  let query = supabase.from("courses").select(courseSelect).order("code");

  if (!options.skipStatusFilter) {
    query = query.eq("status", "published");
  }

  if (options.id) {
    query = query.eq("id", options.id);
  }

  const { data, error } = await query;
  if (error) {
    throw error;
  }

  return (data ?? []).map((course: any) => normaliseCourse(course, locale));
};

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
  try {
    const courses = await fetchCourses(locale);
    return jsonResponse({ courses });
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: message }, 400);
  }
});

const createCourse: Handler = withErrorBoundary(async (req, params, body) => {
  const methodGuard = requireMethod(req, ["POST"]);
  if (methodGuard) return methodGuard;

  if (typeof body !== "object" || body === null) {
    return jsonResponse({ error: "invalid_payload" }, 400);
  }

  const locale = body.locale ?? getLocale(req);
  const createdBy = body.created_by;
  const coursePayload = body.course;

  if (!createdBy) {
    return jsonResponse({ error: "missing_creator" }, 400);
  }

  if (!coursePayload?.code) {
    return jsonResponse({ error: "missing_course_code" }, 400);
  }

  const { data: newCourse, error: insertError } = await supabase
    .from("courses")
    .insert({
      code: coursePayload.code,
      status: coursePayload.status ?? "draft",
      duration_minutes: coursePayload.durationMinutes ?? coursePayload.duration_minutes ?? null,
      certificate_valid_months:
        coursePayload.certificateValidMonths ?? coursePayload.certificate_valid_months ?? 12,
      created_by: createdBy,
    })
    .select("id")
    .single();

  if (insertError || !newCourse?.id) {
    const message = insertError?.message ?? "course_insert_failed";
    return jsonResponse({ error: message }, 400);
  }

  const courseId = newCourse.id as string;

  const translations = Array.isArray(coursePayload.translations) ? coursePayload.translations : [];
  for (const translation of translations) {
    const { error } = await supabase.from("course_i18n").upsert({
      course_id: courseId,
      locale: translation.locale ?? locale,
      title: translation.title ?? coursePayload.code,
      summary: translation.summary ?? "",
    });
    if (error) {
      throw error;
    }
  }

  const modules = Array.isArray(coursePayload.modules) ? coursePayload.modules : [];
  for (let index = 0; index < modules.length; index++) {
    const modulePayload = modules[index];
    const { data: moduleRow, error: moduleError } = await supabase
      .from("modules")
      .insert({
        course_id: courseId,
        type: modulePayload.type ?? "article",
        position: modulePayload.position ?? index + 1,
        duration_seconds: modulePayload.durationSeconds ?? modulePayload.duration_seconds ?? null,
      })
      .select("id")
      .single();

    if (moduleError || !moduleRow?.id) {
      throw moduleError ?? new Error("module_insert_failed");
    }

    const moduleId = moduleRow.id as string;
    const moduleTranslations = Array.isArray(modulePayload.translations)
      ? modulePayload.translations
      : [];

    for (const translation of moduleTranslations) {
      const { error } = await supabase.from("module_i18n").upsert({
        module_id: moduleId,
        locale: translation.locale ?? locale,
        title: translation.title ?? modulePayload.type ?? "Module",
        body_md: translation.body ?? translation.body_md ?? null,
        video_url: translation.videoUrl ?? translation.video_url ?? null,
        simulation_json: translation.simulation ?? translation.simulation_json ?? null,
      });
      if (error) {
        throw error;
      }
    }

    if (modulePayload.quiz) {
      const quizPayload = modulePayload.quiz;
      const { data: quizRow, error: quizError } = await supabase
        .from("quizzes")
        .insert({
          module_id: moduleId,
          passing_score: quizPayload.passingScore ?? quizPayload.passing_score ?? 80,
          shuffle: quizPayload.shuffle ?? true,
        })
        .select("id")
        .single();

      if (quizError || !quizRow?.id) {
        throw quizError ?? new Error("quiz_insert_failed");
      }

      const quizId = quizRow.id as string;
      const questions = Array.isArray(quizPayload.questions) ? quizPayload.questions : [];
      for (const question of questions) {
        const { data: questionRow, error: questionError } = await supabase
          .from("quiz_questions")
          .insert({
            quiz_id: quizId,
            body: question.body ?? "",
            type: question.type ?? "single",
            explanation: question.explanation ?? null,
          })
          .select("id")
          .single();

        if (questionError || !questionRow?.id) {
          throw questionError ?? new Error("question_insert_failed");
        }

        const questionId = questionRow.id as string;
        const options = Array.isArray(question.options) ? question.options : [];
        for (const option of options) {
          const { error } = await supabase.from("quiz_options").insert({
            question_id: questionId,
            body: option.body ?? "",
            is_correct: option.isCorrect ?? option.is_correct ?? false,
          });
          if (error) {
            throw error;
          }
        }
      }
    }
  }

  await supabase.from("audit_logs").insert({
    org_id: coursePayload.org_id ?? null,
    actor: createdBy,
    action: "course_created",
    subject: courseId,
    meta: { code: coursePayload.code },
  });

  const createdCourses = await fetchCourses(locale, { id: courseId, skipStatusFilter: true });
  const course = createdCourses[0];

  if (!course) {
    return jsonResponse({ error: "course_fetch_failed" }, 500);
  }

  return jsonResponse({ course }, 201);
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

const listMyAssignments: Handler = withErrorBoundary(async (req, params, body) => {
  const methodGuard = requireMethod(req, ["GET", "POST"]);
  if (methodGuard) return methodGuard;

  const locale = (typeof body === "object" && body?.locale) || params.get("locale") || getLocale(req);
  const userId =
    (typeof body === "object" && body?.user_id) || params.get("user_id") || req.headers.get("x-user-id");

  if (!userId) {
    return jsonResponse({ error: "missing_user_id" }, 400);
  }

  const { data, error } = await supabase
    .from("assignments")
    .select(`
      id, status, due_at, created_at,
      course:courses!assignments_course_id_fkey(
        id, code,
        course_i18n:course_i18n!inner(locale, title),
        modules:modules(id)
      ),
      progress:progress(id, module_id, completed_at, score, attempts, last_position_seconds),
      certificate:certificates(id, issued_at, expires_at, certificate_url)
    `)
    .eq("assigned_to", userId)
    .order("due_at", { ascending: true, nullsFirst: false })
    .order("created_at", { ascending: false });

  if (error) {
    console.error(error);
    return jsonResponse({ error: error.message }, 400);
  }

  const formatted = (data ?? []).map((assignment: any) => {
    const modulesTotal = assignment.course?.modules?.length ?? 0;
    const progressEntries = assignment.progress ?? [];
    const modulesCompleted = progressEntries.filter((entry: any) => entry.completed_at).length;
    const percent = modulesTotal === 0 ? 0 : Math.round((modulesCompleted / modulesTotal) * 100);

    let latestTimestamp = assignment.created_at ? Date.parse(assignment.created_at) : undefined;
    let latestIso = assignment.created_at ?? null;
    for (const entry of progressEntries) {
      if (entry.completed_at) {
        const time = Date.parse(entry.completed_at);
        if (!Number.isNaN(time) && (latestTimestamp === undefined || time > latestTimestamp)) {
          latestTimestamp = time;
          latestIso = entry.completed_at;
        }
      }
    }

    const courseTranslation = assignment.course?.course_i18n?.find((item: any) => item.locale === locale)
      ?? assignment.course?.course_i18n?.[0];

    return {
      id: assignment.id,
      status: assignment.status,
      dueAt: assignment.due_at,
      createdAt: assignment.created_at,
      course: {
        id: assignment.course?.id,
        code: assignment.course?.code,
        title: courseTranslation?.title,
      },
      progress: {
        modulesTotal,
        modulesCompleted,
        percent,
        lastActivityAt: latestIso,
      },
      certificate: assignment.certificate
        ? {
            id: assignment.certificate.id,
            issuedAt: assignment.certificate.issued_at,
            expiresAt: assignment.certificate.expires_at,
            url: assignment.certificate.certificate_url,
          }
        : null,
    };
  });

  return jsonResponse({ assignments: formatted });
});

const routes: Record<string, Handler> = {
  "GET /courses": listCourses,
  "POST /courses": listCourses,
  "POST /admin/courses": createCourse,
  "POST /quiz": submitQuiz,
  "GET /me/assignments": listMyAssignments,
  "POST /me/assignments": listMyAssignments,
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
