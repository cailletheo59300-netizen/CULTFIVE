-- ─────────────────────────────────────────── 0045 · Une carte commune en fin de partie classée (D-043)
-- Au plus une carte par partie : une commune pas encore possédée, tirée parmi les cartes des notions trouvées pendant la partie.
-- Jamais deux fois pour la même partie (même si l'app renvoie la fin de partie).

create table public.album_game_cards (
  session_id  uuid primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  card_id     text references public.album_cards(id) on delete set null,
  created_at  timestamptz not null default now()
);
alter table public.album_game_cards enable row level security;
revoke all on public.album_game_cards from public, anon, authenticated;

create or replace function public._album_game_card(p_user uuid, p_session uuid) returns jsonb
language plpgsql as $$
declare
  v_card text;
  v_done public.album_game_cards;
begin
  select * into v_done from public.album_game_cards where session_id = p_session;
  if found then
    return case when v_done.card_id is null then null
                else jsonb_build_object('card', v_done.card_id, 'rarity', 'common', 'outcome', 'new') end;
  end if;
  perform public._album_row(p_user);
  select c.id into v_card
  from public.question_attempts qa
  join public.album_card_concepts k on k.concept_id = qa.concept_id
  join public.album_cards c on c.id = k.card_id and c.rarity = 'common'
  where qa.user_id = p_user and qa.session_id = p_session and qa.is_correct
    and not exists (select 1 from public.user_cards uc where uc.user_id = p_user and uc.slot = 0 and uc.card_id = c.id)
  order by random() limit 1;
  insert into public.album_game_cards (session_id, user_id, card_id) values (p_session, p_user, v_card);
  if v_card is null then return null; end if;
  return public._album_receive(p_user, 0::smallint, v_card, 'game_card:' || p_session);
end $$;

-- Fin de partie : en plus des trophées par leur nom (0022), la carte gagnée (partie classée seulement).
create or replace function public.play_submit(p_session uuid, p_attempts jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v jsonb := public._play_submit_rated(p_session, p_attempts);
  v_card jsonb;
begin
  v := jsonb_set(v, '{achievements}', coalesce((
    select jsonb_agg(a.name order by a.sort) from public.achievements a
    where a.id in (select jsonb_array_elements_text(v -> 'achievements'))), '[]'::jsonb));
  if exists (select 1 from public.play_sessions where id = p_session and user_id = auth.uid() and ranked) then
    v_card := public._album_game_card(auth.uid(), p_session);
  end if;
  return v || jsonb_build_object('album_card', v_card);
end $$;

revoke execute on function public._album_game_card(uuid, uuid) from public, anon, authenticated;
alter function public._album_game_card(uuid, uuid) set search_path = public, pg_temp;
revoke execute on function public.play_submit(uuid, jsonb) from public, anon;
grant execute on function public.play_submit(uuid, jsonb) to authenticated;
