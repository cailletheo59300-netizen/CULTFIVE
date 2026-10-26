-- Duels entre amis (D-114) : le chrono devient un choix à part (« Format Arène » : 7 questions, 25 s ; « Format libre » :
-- nombre de questions, chrono oui/non, domaines, difficulté) et un défi que personne n'a commencé peut être supprimé.
-- Les anciennes apps (sans p_seconds) gardent la règle d'avant : 25 s pour 7 questions, sans chrono sinon.

-- Modifie une fonction existante sur place : chaque remplacement doit trouver son texte.
create or replace function pg_temp.patch(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $$
declare v_def text := pg_get_functiondef(p_fn); v_new text; i int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    v_new := replace(v_def, p_pairs[2 * i - 1], p_pairs[2 * i]);
    if v_new = v_def then raise exception 'patch % : texte % introuvable', p_fn, i; end if;
    v_def := v_new;
  end loop;
  execute v_def;
end $$;

-- _duel_new prend le chrono : -1 = règle d'avant (25 s pour 7 questions), 0 = sans chrono, sinon les secondes.
-- La nouvelle version (7 paramètres) remplace l'ancienne (6), retirée juste après.
select pg_temp.patch('public._duel_new(uuid, uuid, int, text[], text, uuid)', array[
  'p_rematch_of uuid)', 'p_rematch_of uuid, p_seconds integer DEFAULT (-1))',
  'if p_count not in (5, 7, 10, 15, 20) then raise exception ''invalid_count''; end if;',
  'if p_count not in (5, 7, 10, 15, 20) then raise exception ''invalid_count''; end if;
  if p_seconds is not null and p_seconds not in (-1, 0, 25) then raise exception ''invalid_seconds''; end if;',
  'case when p_count = 7 then 25 end)',
  'case when coalesce(p_seconds, -1) = -1 then case when p_count = 7 then 25 end when p_seconds > 0 then p_seconds end)'
]);
drop function public._duel_new(uuid, uuid, int, text[], text, uuid);
revoke execute on function public._duel_new(uuid, uuid, int, text[], text, uuid, int) from public, anon, authenticated;

-- duel_create : p_seconds (25 ou 0) ; absent (anciennes apps) = règle d'avant.
drop function public.duel_create(uuid, int, text[], text);
create or replace function public.duel_create(p_friend uuid default null, p_count int default 5, p_domains text[] default null,
                                              p_difficulty text default 'auto', p_seconds int default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  d public.duels;
begin
  if p_friend is not null and not public._are_friends(v_user, p_friend) then raise exception 'not_friends'; end if;
  d := public._duel_new(v_user, p_friend, coalesce(p_count, 5), p_domains, p_difficulty, null, coalesce(p_seconds, -1));
  return public._duel_json(d, v_user);
end $$;
revoke execute on function public.duel_create(uuid, int, text[], text, int) from public, anon;
grant execute on function public.duel_create(uuid, int, text[], text, int) to authenticated;

-- Revanche : même format, chrono compris.
select pg_temp.patch('public.duel_rematch(uuid)', array[
  'd.domains, d.difficulty, d.id);', 'd.domains, d.difficulty, d.id, coalesce(d.seconds, 0));'
]);

-- Supprimer un défi que personne n'a commencé (aucune réponse donnée, ni par moi ni par l'autre) : il disparaît des
-- deux côtés. Dès qu'une réponse est donnée, il faut le finir.
create or replace function public.duel_cancel(p_duel uuid) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_user uuid := public._require_user();
begin
  update public.duels set status = 'declined', finished_at = public._now()
  where id = p_duel and challenger_id = v_user and status in ('open', 'active') and not arena
    and not exists (select 1 from public.duel_answers where duel_id = p_duel and answered_at is not null);
  if not found then raise exception 'duel_not_found'; end if;
end $$;
revoke execute on function public.duel_cancel(uuid) from public, anon;
grant execute on function public.duel_cancel(uuid) to authenticated;
