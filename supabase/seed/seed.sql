-- Seed data for marketplace
insert into profiles (id, display_name, role)
values
    ('00000000-0000-0000-0000-000000000001', 'Alice Creator', 'creator')
    on conflict (id) do update set display_name = excluded.display_name,
                                   role = excluded.role;

insert into profiles (id, display_name, role)
values
    ('00000000-0000-0000-0000-000000000002', 'Bob Student', 'student')
    on conflict (id) do update set display_name = excluded.display_name,
                                   role = excluded.role;

insert into courses (id, creator_id, title, slug, description, price_cents, currency, is_published)
values
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'AI Fundamentals', 'ai-fundamentals', 'Introductory AI course', 9900, 'usd', true)
    on conflict (id) do update set title = excluded.title,
                                   slug = excluded.slug,
                                   description = excluded.description,
                                   price_cents = excluded.price_cents,
                                   currency = excluded.currency,
                                   is_published = excluded.is_published;

insert into modules (id, course_id, title, order_index, required, passing_score)
values
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Introduction', 1, true, 60),
    ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Applied Labs', 2, true, 70)
    on conflict (id) do update set title = excluded.title,
                                   order_index = excluded.order_index,
                                   required = excluded.required,
                                   passing_score = excluded.passing_score;

insert into lessons (id, module_id, title, order_index, content_url, quiz_json)
values
    ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Welcome', 1, 'https://example.com/welcome.md', '{"questions":[{"q":"What is AI?","options":["Robotics","Intelligence"],"answer":1}]}'::jsonb),
    ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'History', 2, 'https://example.com/history.mp4', null),
    ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'Project Setup', 1, 'https://example.com/setup.pdf', null)
    on conflict (id) do update set title = excluded.title,
                                   order_index = excluded.order_index,
                                   content_url = excluded.content_url,
                                   quiz_json = excluded.quiz_json;

insert into webhook_endpoints (id, owner_id, url, description, secret)
values
    ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'https://example.com/webhooks', 'Example listener', encode(gen_random_bytes(32), 'hex'))
    on conflict (id) do nothing;
