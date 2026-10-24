create table if not exists public.keywords (
  id bigint generated always as identity primary key,
  text text not null check (char_length(btrim(text)) between 1 and 140),
  created_at timestamptz not null default now(),
  reserved_by uuid,
  reserved_until timestamptz
);

create table if not exists public.completed_draws (
  drawer_id uuid primary key,
  completed_at timestamptz not null default now()
);

alter table public.keywords enable row level security;
alter table public.completed_draws enable row level security;

revoke all on public.keywords from anon, authenticated;
revoke all on public.completed_draws from anon, authenticated;
grant insert (text) on public.keywords to anon;

drop policy if exists "Allow anonymous keyword submissions" on public.keywords;
create policy "Allow anonymous keyword submissions"
  on public.keywords for insert to anon
  with check (char_length(btrim(text)) between 1 and 140);

create or replace function public.draw_keyword(
  p_drawer_id uuid,
  p_previous_keyword_id bigint default null
)
returns table(keyword_id bigint, keyword_text text, already_completed boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.completed_draws where drawer_id = p_drawer_id
  ) then
    return query select null::bigint, null::text, true;
    return;
  end if;

  if p_previous_keyword_id is not null then
    update public.keywords
      set reserved_by = null, reserved_until = null
      where id = p_previous_keyword_id and reserved_by = p_drawer_id;
  end if;

  update public.keywords
    set reserved_by = null, reserved_until = null
    where reserved_until <= now();

  return query
    with candidate as (
      select id
        from public.keywords
        where reserved_by is null
          and id is distinct from p_previous_keyword_id
        order by random()
        limit 1
        for update skip locked
    )
    update public.keywords as keyword
      set reserved_by = p_drawer_id,
          reserved_until = now() + interval '15 minutes'
      from candidate
      where keyword.id = candidate.id
      returning keyword.id, keyword.text, false;
end;
$$;

create or replace function public.confirm_keyword(
  p_drawer_id uuid,
  p_keyword_id bigint
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  inserted_count integer;
  deleted_count integer;
begin
  insert into public.completed_draws (drawer_id)
    values (p_drawer_id)
    on conflict (drawer_id) do nothing;
  get diagnostics inserted_count = row_count;

  if inserted_count = 0 then
    update public.keywords
      set reserved_by = null, reserved_until = null
      where reserved_by = p_drawer_id;
    return false;
  end if;

  delete from public.keywords
    where id = p_keyword_id and reserved_by = p_drawer_id;
  get diagnostics deleted_count = row_count;

  if deleted_count = 0 then
    delete from public.completed_draws where drawer_id = p_drawer_id;
    return false;
  end if;

  update public.keywords
    set reserved_by = null, reserved_until = null
    where reserved_by = p_drawer_id;

  return true;
end;
$$;

revoke all on function public.draw_keyword(uuid, bigint) from public;
revoke all on function public.confirm_keyword(uuid, bigint) from public;
grant execute on function public.draw_keyword(uuid, bigint) to anon;
grant execute on function public.confirm_keyword(uuid, bigint) to anon;