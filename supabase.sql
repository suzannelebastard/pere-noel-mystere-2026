create table if not exists public.keywords (
  id bigint generated always as identity primary key,
  text text not null check (char_length(btrim(text)) between 1 and 2048),
  created_at timestamptz not null default now(),
  reserved_by uuid,
  reserved_until timestamptz
);

alter table public.keywords drop constraint if exists keywords_text_check;
alter table public.keywords
  add constraint keywords_text_check check (char_length(btrim(text)) between 1 and 2048);

create table if not exists public.completed_draws (
  drawer_id uuid primary key,
  completed_at timestamptz not null default now()
);

create table if not exists public.drawn_keywords (
  id bigint primary key,
  text text not null check (char_length(btrim(text)) between 1 and 2048),
  created_at timestamptz not null,
  drawn_at timestamptz not null default now(),
  revealed_at timestamptz
);

create table if not exists public.draw_settings (
  id integer primary key check (id = 1),
  is_open boolean not null default false,
  submissions_open boolean not null default true,
  reveal_open boolean not null default false
);

alter table public.draw_settings
  add column if not exists submissions_open boolean not null default true;
alter table public.draw_settings
  add column if not exists reveal_open boolean not null default false;

insert into public.draw_settings (id, is_open)
  values (1, false)
  on conflict (id) do nothing;

alter table public.keywords enable row level security;
alter table public.completed_draws enable row level security;
alter table public.drawn_keywords enable row level security;
alter table public.draw_settings enable row level security;

revoke all on public.keywords from anon, authenticated;
revoke all on public.completed_draws from anon, authenticated;
revoke all on public.drawn_keywords from anon, authenticated;
revoke all on public.draw_settings from anon, authenticated;
grant insert (text) on public.keywords to anon;

create or replace function public.draw_is_open()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select is_open from public.draw_settings where id = 1), false);
$$;

create or replace function public.submissions_are_open()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select submissions_open from public.draw_settings where id = 1), false);
$$;

create or replace function public.reveal_is_open()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select reveal_open and not is_open from public.draw_settings where id = 1), false);
$$;

create or replace function public.reveal_next_music()
returns table(music_id bigint, music_text text, remaining_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  selected_id bigint;
  selected_text text;
begin
  if not public.reveal_is_open() then
    return;
  end if;

  select id into selected_id
    from public.drawn_keywords
    where revealed_at is null
    order by random()
    limit 1
    for update skip locked;

  if selected_id is null then
    return;
  end if;

  update public.drawn_keywords
    set revealed_at = now()
    where id = selected_id and revealed_at is null
    returning text into selected_text;

  if not found then
    return;
  end if;

  return query
    select selected_id, selected_text, count(*)
      from public.drawn_keywords
      where revealed_at is null;
end;
$$;

drop policy if exists "Allow anonymous keyword submissions" on public.keywords;
create policy "Allow anonymous keyword submissions"
  on public.keywords for insert to anon
  with check (
    char_length(btrim(text)) between 1 and 2048
    and public.submissions_are_open()
  );

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
  if not public.draw_is_open() then
    return;
  end if;

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
  archived_count integer;
  deleted_count integer;
begin
  if not public.draw_is_open() then
    return false;
  end if;

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

  insert into public.drawn_keywords (id, text, created_at)
    select id, text, created_at
      from public.keywords
      where id = p_keyword_id and reserved_by = p_drawer_id
    on conflict (id) do nothing;
  get diagnostics archived_count = row_count;

  if archived_count = 0 then
    delete from public.completed_draws where drawer_id = p_drawer_id;
    return false;
  end if;

  delete from public.keywords
    where id = p_keyword_id and reserved_by = p_drawer_id;
  get diagnostics deleted_count = row_count;

  if deleted_count = 0 then
    delete from public.drawn_keywords where id = p_keyword_id;
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
revoke all on function public.draw_is_open() from public;
revoke all on function public.submissions_are_open() from public;
revoke all on function public.reveal_is_open() from public;
revoke all on function public.reveal_next_music() from public;
grant execute on function public.draw_keyword(uuid, bigint) to anon;
grant execute on function public.confirm_keyword(uuid, bigint) to anon;
grant execute on function public.draw_is_open() to anon;
grant execute on function public.submissions_are_open() to anon;
grant execute on function public.reveal_is_open() to anon;
grant execute on function public.reveal_next_music() to anon;