-- 006_plan_requests.sql
-- Tabella richieste piano: il cliente richiede un abbonamento,
-- l'owner lo verifica (pagamento fuori app) e lo attiva.

create table public.plan_requests (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.users(id)   on delete cascade,
  plan_id     uuid        not null references public.plans(id)   on delete cascade,
  studio_id   uuid        not null references public.studios(id) on delete cascade,
  status      text        not null default 'pending'
                          check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  created_at  timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table public.plan_requests enable row level security;

-- Lettura: il cliente vede le proprie richieste; l'owner vede quelle del suo studio
create policy "read_plan_requests"
  on public.plan_requests for select
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.user_studio_roles usr
      where usr.user_id   = auth.uid()
        and usr.studio_id = plan_requests.studio_id
        and usr.role in ('gym_owner', 'admin')
    )
  );

-- Inserimento: solo il client può aprire una richiesta per sé stesso
create policy "client_insert_plan_request"
  on public.plan_requests for insert
  with check (auth.uid() = user_id);

-- Aggiornamento: il client può ritirare la propria richiesta pending;
-- l'owner può approvare o rifiutare le richieste del suo studio
create policy "update_plan_request"
  on public.plan_requests for update
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.user_studio_roles usr
      where usr.user_id   = auth.uid()
        and usr.studio_id = plan_requests.studio_id
        and usr.role in ('gym_owner', 'admin')
    )
  );
