alter table plan_requests
  add column if not exists course_id uuid references courses(id) on delete set null;
