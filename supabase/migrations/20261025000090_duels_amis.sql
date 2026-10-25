-- Duels entre amis (D-112) : format 7 questions à 25 s (comme l'Arène, sans points de la semaine),
-- chrono vérifié par le serveur, « Revanche ? » après une défaite, historique de tous les duels entre amis.
-- Les anciens formats (5, 10, 15, 20, sans chrono) restent possibles dans « Plus de réglages ».

alter table public.duels add column if not exists seconds int check (seconds between 10 and 60);

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

-- 7 questions : 25 s par question. Une revanche garde le format (même nombre de questions).
select pg_temp.patch('public._duel_new(uuid, uuid, int, text[], text, uuid)', array[
  'if p_count not in (5, 10, 15, 20) then', 'if p_count not in (5, 7, 10, 15, 20) then',
  'domains, difficulty, rematch_of)', 'domains, difficulty, rematch_of, seconds)',
  'coalesce(p_difficulty, ''auto''), p_rematch_of)', 'coalesce(p_difficulty, ''auto''), p_rematch_of,
          case when p_count = 7 then 25 end)'
]);

select pg_temp.patch('public.duel_question(uuid, int)', array[
  '''total'', cardinality(d.question_ids))', '''total'', cardinality(d.question_ids), ''seconds'', d.seconds)'
]);

-- Chrono : au-delà du temps + 3 s de marge (réseau), la réponse compte fausse.
select pg_temp.patch('public.duel_answer(uuid, int, jsonb, int)', array[
  'v_server_ms int; v_counted int;', 'v_server_ms int; v_counted int; v_late bool := false;',
  'v_counted := least(greatest(v_counted, 300), 120000);',
  'v_late := d.seconds is not null and v_server_ms > (d.seconds + 3) * 1000;
  v_counted := least(greatest(v_counted, 300), coalesce(d.seconds * 1000, 120000));',
  '_record_attempt(v_user, q.id, p_given,', '_record_attempt(v_user, q.id, case when v_late then null else p_given end,',
  'is_correct = (v_res ->> ''is_correct'')::bool,', 'is_correct = (v_res ->> ''is_correct'')::bool and not v_late,',
  'if (v_res ->> ''is_correct'')::bool then', 'if (v_res ->> ''is_correct'')::bool and not v_late then',
  '''is_correct'', (v_res ->> ''is_correct'')::bool, ''duplicate'', false,',
  '''is_correct'', (v_res ->> ''is_correct'')::bool and not v_late, ''late'', v_late, ''duplicate'', false,'
]);

-- Chrono, date de fin et avatar de l'adversaire pour l'historique. Score et temps de l'adversaire : seulement quand
-- les deux ont fini (avant, un joueur qui avait fini voyait le score partiel de l'autre).
select pg_temp.patch('public._duel_json(public.duels, uuid)', array[
  '''score'', case when me.answered = n or d.status = ''finished'' then them.score end,',
  '''score'', case when (me.answered = n and them.answered = n) or d.status = ''finished'' then them.score end,',
  '''total_ms'', case when me.answered = n or d.status = ''finished'' then them.total_ms end',
  '''total_ms'', case when (me.answered = n and them.answered = n) or d.status = ''finished'' then them.total_ms end',
  '''total'', n,', '''total'', n, ''seconds'', d.seconds, ''finished_at'', d.finished_at,',
  '''handle'', (select handle from public.profiles where id = v_other),',
  '''handle'', (select handle from public.profiles where id = v_other),
        ''avatar'', (select avatar from public.profiles where id = v_other),'
]);

select pg_temp.patch('public._duel_notify_end(uuid)', array[
  '|| me.score || ''–'' || them.score || ''.'',',
  '|| me.score || ''–'' || them.score || case when d.winner_id = v_other then ''. Revanche ?'' else ''.'' end,'
]);

-- Le face-à-face avec un ami ne compte que les duels entre amis (pas ceux de l'Arène).
select pg_temp.patch('public.friend_profile(uuid)', array[
  'and d.status in (''active'', ''finished'', ''expired'')', 'and d.status in (''active'', ''finished'', ''expired'') and not d.arena'
]);

-- Historique de tous les duels entre amis terminés, 30 par page (du plus récent au plus ancien),
-- avec le bilan global et les adversaires les plus fréquents en première page.
create or replace function public.duels_history(p_before timestamptz default null) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_user uuid := public._require_user();
  v_rows jsonb;
  v_last timestamptz;
  v_n int;
  v_summary jsonb;
begin
  select coalesce(jsonb_agg(public._duel_json(x, v_user) order by x.created_at desc), '[]'::jsonb), min(x.created_at), count(*)
    into v_rows, v_last, v_n
  from (select d.* from public.duels d
        where v_user in (d.challenger_id, d.opponent_id) and not d.arena and d.opponent_id is not null
          and d.status in ('finished', 'expired') and (p_before is null or d.created_at < p_before)
        order by d.created_at desc limit 30) x;

  if p_before is null then
    with f as (
      select case when v_user = d.challenger_id then d.opponent_id else d.challenger_id end as other, d.winner_id
      from public.duels d
      where v_user in (d.challenger_id, d.opponent_id) and not d.arena and d.opponent_id is not null and d.status = 'finished')
    select jsonb_build_object(
      'played', (select count(*) from f),
      'wins', (select count(*) from f where winner_id = v_user),
      'losses', (select count(*) from f where winner_id = other),
      'draws', (select count(*) from f where winner_id is null),
      'rivals', coalesce((select jsonb_agg(r order by (r ->> 'played')::int desc, r ->> 'handle')
                          from (select jsonb_build_object('id', f.other, 'handle', p.handle, 'avatar', p.avatar,
                                                          'played', count(*),
                                                          'wins', count(*) filter (where f.winner_id = v_user),
                                                          'losses', count(*) filter (where f.winner_id = f.other)) r
                                from f join public.profiles p on p.id = f.other
                                group by f.other, p.handle, p.avatar
                                order by count(*) desc, p.handle limit 3) t), '[]'::jsonb))
    into v_summary;
  end if;

  return jsonb_build_object('duels', v_rows, 'summary', v_summary,
                            'next', case when v_n = 30 then v_last end);
end $$;

revoke execute on function public.duels_history(timestamptz) from public, anon;
grant execute on function public.duels_history(timestamptz) to authenticated;
