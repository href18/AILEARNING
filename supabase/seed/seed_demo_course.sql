insert into public.users (id, email, full_name, preferred_locale) values
  ('11111111-1111-1111-1111-111111111111', 'admin@example.com', 'Ingrid Admin', 'nb'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'participant@example.com', 'Ola Deltaker', 'nb')
  on conflict (id) do nothing;

insert into public.orgs (id, name, billing_plan) values
  ('22222222-2222-2222-2222-222222222222', 'Demo HMS AS', 'per_seat')
  on conflict (id) do nothing;

insert into public.org_members (org_id, user_id, role)
values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'admin'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'participant')
on conflict (org_id, user_id) do nothing;

insert into public.courses (id, code, status, duration_minutes, certificate_valid_months, created_by)
values ('33333333-3333-3333-3333-333333333333', 'FSE-101', 'published', 45, 24, '11111111-1111-1111-1111-111111111111')
on conflict (id) do nothing;

insert into public.course_i18n (course_id, locale, title, summary) values
  ('33333333-3333-3333-3333-333333333333', 'nb', 'FSE Grunnkurs', 'Grunnleggende sikkerhetsopplæring for arbeid nær elektriske anlegg.'),
  ('33333333-3333-3333-3333-333333333333', 'en', 'FSE Safety Basics', 'Mandatory electrical safety awareness training for contractors.')
on conflict (course_id, locale) do update set title = excluded.title, summary = excluded.summary;

insert into public.modules (id, course_id, type, position, duration_seconds)
values
  ('44444444-4444-4444-4444-444444444441', '33333333-3333-3333-3333-333333333333', 'video', 1, 300),
  ('44444444-4444-4444-4444-444444444442', '33333333-3333-3333-3333-333333333333', 'article', 2, 420),
  ('44444444-4444-4444-4444-444444444443', '33333333-3333-3333-3333-333333333333', 'simulation', 3, 240),
  ('44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 'quiz', 4, 600)
on conflict (id) do nothing;

insert into public.module_i18n (module_id, locale, title, body_md, video_url, simulation_json) values
  ('44444444-4444-4444-4444-444444444441', 'nb', 'Introduksjonsvideo', null, 'https://player.vimeo.com/video/76979871?h=8272103f6e', null),
  ('44444444-4444-4444-4444-444444444441', 'en', 'Introduction Video', null, 'https://player.vimeo.com/video/76979871?h=8272103f6e', null),
  ('44444444-4444-4444-4444-444444444442', 'nb', 'Fem livsviktige prinsipper', '- Hold avstand\n- Bryt strømmen\n- Bruk godkjent verneutstyr\n- Lås og merk\n- Rapporter avvik umiddelbart.', null, null),
  ('44444444-4444-4444-4444-444444444442', 'en', 'Five lifesaving principles', '- Maintain safe distances\n- De-energise before work\n- Wear PPE\n- Lockout/tagout\n- Report incidents immediately.', null, null),
  ('44444444-4444-4444-4444-444444444443', 'nb', 'Scenario: Førstehjelp ved støt', null, null, '{"steps":[{"title":"Vurder situasjonen","description":"Sikre området og vurder egen sikkerhet."},{"title":"Varsle","description":"Ring 113 og informer om mulig strømskade."},{"title":"Førstehjelp","description":"Start hjerte-lungeredning hvis personen er bevisstløs uten pust."}]}'),
  ('44444444-4444-4444-4444-444444444443', 'en', 'Scenario: First aid after shock', null, null, '{"steps":[{"title":"Assess","description":"Ensure the area is safe."},{"title":"Alert","description":"Call emergency services."},{"title":"Aid","description":"Begin CPR if the person is unconscious."}]}'),
  ('44444444-4444-4444-4444-444444444444', 'nb', 'Quiz: FSE grunnkurs', null, null, null),
  ('44444444-4444-4444-4444-444444444444', 'en', 'Quiz: FSE fundamentals', null, null, null)
on conflict (module_id, locale) do update set title = excluded.title, body_md = excluded.body_md, video_url = excluded.video_url, simulation_json = excluded.simulation_json;

insert into public.quizzes (id, module_id, passing_score, shuffle) values
  ('55555555-5555-5555-5555-555555555551', '44444444-4444-4444-4444-444444444444', 80, true)
on conflict (id) do nothing;

insert into public.quiz_questions (id, quiz_id, body, type, explanation) values
  ('66666666-6666-6666-6666-666666666661', '55555555-5555-5555-5555-555555555551', 'What should you do before starting work on electrical equipment?', 'single', 'Always isolate the power source before beginning work.'),
  ('66666666-6666-6666-6666-666666666662', '55555555-5555-5555-5555-555555555551', 'Select the correct PPE for live work tasks.', 'multi', 'Multiple pieces of PPE may be required depending on the task.')
on conflict (id) do update set body = excluded.body, type = excluded.type, explanation = excluded.explanation;

insert into public.quiz_options (id, question_id, body, is_correct) values
  ('77777777-7777-7777-7777-777777777771', '66666666-6666-6666-6666-666666666661', 'De-energise/lockout the circuit.', true),
  ('77777777-7777-7777-7777-777777777772', '66666666-6666-6666-6666-666666666661', 'Put on gloves and hope for the best.', false),
  ('77777777-7777-7777-7777-777777777773', '66666666-6666-6666-6666-666666666662', 'Insulated gloves', true),
  ('77777777-7777-7777-7777-777777777774', '66666666-6666-6666-6666-666666666662', 'Face shield', true),
  ('77777777-7777-7777-7777-777777777775', '66666666-6666-6666-6666-666666666662', 'Flip-flops', false)
on conflict (id) do update set body = excluded.body, is_correct = excluded.is_correct;

insert into public.assignments (id, org_id, course_id, assigned_by, assigned_to, due_at, status)
values
  ('88888888-8888-8888-8888-888888888881', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', now() + interval '7 days', 'in_progress'),
  ('88888888-8888-8888-8888-888888888882', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', now() - interval '14 days', 'completed')
on conflict (id) do update set due_at = excluded.due_at, status = excluded.status;

insert into public.progress (id, assignment_id, module_id, completed_at, last_position_seconds, score, attempts)
values
  ('99999999-9999-9999-9999-999999999991', '88888888-8888-8888-8888-888888888881', '44444444-4444-4444-4444-444444444441', now() - interval '1 day', 300, 100, 1),
  ('99999999-9999-9999-9999-999999999992', '88888888-8888-8888-8888-888888888881', '44444444-4444-4444-4444-444444444442', null, 180, null, 1),
  ('99999999-9999-9999-9999-999999999993', '88888888-8888-8888-8888-888888888882', '44444444-4444-4444-4444-444444444441', now() - interval '20 days', 300, 100, 1),
  ('99999999-9999-9999-9999-999999999994', '88888888-8888-8888-8888-888888888882', '44444444-4444-4444-4444-444444444442', now() - interval '19 days', 420, 100, 1),
  ('99999999-9999-9999-9999-999999999995', '88888888-8888-8888-8888-888888888882', '44444444-4444-4444-4444-444444444443', now() - interval '18 days', 240, 100, 1),
  ('99999999-9999-9999-9999-999999999996', '88888888-8888-8888-8888-888888888882', '44444444-4444-4444-4444-444444444444', now() - interval '17 days', 600, 90, 2)
on conflict (id) do update set completed_at = excluded.completed_at, score = excluded.score, attempts = excluded.attempts;

insert into public.certificates (id, assignment_id, issued_at, expires_at, certificate_url)
values
  ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeee1', '88888888-8888-8888-8888-888888888882', now() - interval '16 days', now() + interval '8 months', 'https://example.com/certificates/fse-101.pdf')
on conflict (assignment_id) do update set certificate_url = excluded.certificate_url, expires_at = excluded.expires_at;
