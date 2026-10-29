-- Objets avant la partie (D-119) : stock de départ, Boisson, Bouclier, Pari, Survie (bouclier, sablier), packs.
create or replace function pg_temp.ranked_game(p_good bool, p_items text[] default null) returns jsonb language plpgsql as $$
declare pack jsonb; sid uuid; atts jsonb := '[]'::jsonb; x jsonb;
begin
  pack := public.play_pack('training', 'history', null, 10, true, null);
  sid := (pack ->> 'session_id')::uuid;
  if p_items is not null then perform public.play_boost(sid, p_items); end if;
  for x in select * from jsonb_array_elements(pack -> 'questions') loop
    atts := atts || jsonb_build_object('client_attempt_id', gen_random_uuid(), 'question_id', x ->> 'id',
              'given', case when p_good then tst.correct_given((x ->> 'id')::uuid) else tst.wrong_given() end,
              'response_ms', 4000);
  end loop;
  return public.play_submit(sid, atts) || jsonb_build_object('session_id', sid, 'attempts', atts);
end $$;

do $$
declare
  u uuid := tst.new_user();
  o jsonb; r jsonb; pack jsonb; sid uuid; run uuid; q jsonb; a jsonb; i int;
begin
  perform tst.clock('2026-11-10 10:00:00+01');
  perform tst.login(u);
  update public.profiles set created_at = public._now() - interval '2 days' where id = u;

  -- Un de chaque au départ, une seule fois.
  o := public.boutique_overview();
  perform tst.ok(o -> 'items' = '{"energy": 1, "shield": 1, "bet": 1, "lifeline": 1, "hourglass": 1}'::jsonb, 'un objet de chaque au départ');
  o := public.boutique_overview();
  perform tst.ok((o -> 'items' ->> 'energy')::int = 1, 'donnés une seule fois');
  perform tst.ok(o ->> 'welcome_until' is not null, 'offre de bienvenue visible les 7 premiers jours');

  -- Placement terminé pour que l'Elo bouge normalement.
  for i in 1 .. 3 loop perform pg_temp.ranked_game(true); end loop;

  -- Boisson énergisante : l'Elo gagné compte double.
  r := pg_temp.ranked_game(true, array['energy']);
  perform tst.ok(r -> 'boosts' -> 'items' = '["energy"]'::jsonb and (r -> 'boosts' ->> 'elo_extra')::int > 0,
                 format('boisson : gain doublé (+%s en plus)', r -> 'boosts' ->> 'elo_extra'));
  perform tst.ok((r -> 'ratings' -> 0 ->> 'cote_after')::int > (r -> 'ratings' -> 0 ->> 'cote_before')::int, 'bilan : Elo monté');
  perform tst.ok((public.boutique_overview() -> 'items' ->> 'energy')::int = 0, 'boisson retirée du stock');
  -- Renvoi de la file hors ligne : rien n'est rejoué.
  r := public.play_submit((r ->> 'session_id')::uuid, r -> 'attempts');
  perform tst.ok((r -> 'boosts' ->> 'elo_extra') is null, 'renvoi : objets pas rejoués');

  -- Plus de boisson : refus.
  pack := public.play_pack('training', 'history', null, 10, true, null);
  perform tst.throws(format('select public.play_boost(%L, array[''energy''])', pack ->> 'session_id'), 'no_item');
  perform tst.throws(format('select public.play_boost(%L, array[''bet'', ''shield''])', pack ->> 'session_id'), 'bet_alone');
  perform tst.throws(format('select public.play_boost(%L, array[''lifeline''])', pack ->> 'session_id'), 'invalid_item');

  -- Bouclier d'Elo : partie ratée, pas de perte.
  r := pg_temp.ranked_game(false, array['shield']);
  perform tst.ok((r -> 'ratings' -> 0 ->> 'cote_after')::int >= (r -> 'ratings' -> 0 ->> 'cote_before')::int, 'bouclier : aucune perte');

  -- Pari ×3 : réussi, gain triplé ; raté, perte doublée.
  r := pg_temp.ranked_game(true, array['bet']);
  perform tst.ok((r -> 'boosts' ->> 'bet_won')::bool and (r -> 'boosts' ->> 'elo_extra')::int > 0, 'pari gagné : gain triplé');
  perform public._give_item(u, 'bet', 1);
  r := pg_temp.ranked_game(false, array['bet']);
  perform tst.ok(not (r -> 'boosts' ->> 'bet_won')::bool and (r -> 'boosts' ->> 'elo_extra')::int <= 0, 'pari perdu : perte doublée');

  -- Entraînement libre : pas d'objet.
  pack := public.play_pack('training', 'history', null, 10, false, null);
  perform tst.throws(format('select public.play_boost(%L, array[''shield''])', pack ->> 'session_id'), 'not_ranked');

  -- Survie : sablier (+10 s) et bouclier (une erreur pardonnée).
  r := public.survival_start(null);
  run := (r ->> 'run_id')::uuid;
  r := public.survival_boost(run, array['lifeline', 'hourglass']);
  perform tst.ok((r ->> 'seconds')::int = 30, 'sablier : 30 s par question');
  q := public.survival_question(run, 1);
  perform tst.ok((q ->> 'seconds')::int = 30, 'question : 30 s');
  a := public.survival_answer(run, 1, tst.wrong_given(), 4000);
  perform tst.ok(not (a ->> 'finished')::bool and (a ->> 'lifeline_used')::bool, 'bouclier : la Survie continue');
  q := public.survival_question(run, 2);
  a := public.survival_answer(run, 2, tst.correct_given((q ->> 'id')::uuid), 4000);
  perform tst.ok((a ->> 'is_correct')::bool and not (a ->> 'finished')::bool, 'bonne réponse après le bouclier');
  q := public.survival_question(run, 3);
  a := public.survival_answer(run, 3, tst.wrong_given(), 4000);
  perform tst.ok((a ->> 'finished')::bool, 'deuxième erreur : fin');
  perform tst.ok((public.survival_result(run) ->> 'score')::int = 1, 'score : les bonnes réponses seulement');
  perform tst.throws(format('select public.survival_boost(%L, array[''hourglass''])', run), 'already_started');

  -- Packs : objets et heures sans pub, cumulées.
  r := public.iap_record(u, 'tx-objets-essai', 'tx-objets-essai', 'app.brainlix.pack.essai', 'Production', public._now());
  o := public.boutique_overview();
  perform tst.ok((o -> 'items' ->> 'hourglass')::int = 1 and (o ->> 'no_ads')::bool, 'pack Essai : 1 de chaque + 1 h sans pub');
  perform public.iap_record(u, 'tx-objets-essai', 'tx-objets-essai', 'app.brainlix.pack.essai', 'Production', public._now());
  perform tst.ok((public.boutique_overview() -> 'items' ->> 'hourglass')::int = 1, 'renvoi : livré une seule fois');
  perform public.iap_record(u, 'tx-objets-big', 'tx-objets-big', 'app.brainlix.pack.big', 'Production', public._now());
  o := public.boutique_overview();
  perform tst.ok((o -> 'items' ->> 'hourglass')::int = 4, 'Big Pack : 3 de plus');
  perform public.iap_record(u, 'tx-objets-joueur', 'tx-objets-joueur', 'app.brainlix.pack.joueur', 'Production', public._now());
  o := public.boutique_overview();
  perform tst.ok((o -> 'items' ->> 'hourglass')::int = 5 and (o -> 'items' ->> 'shield')::int >= 6, 'Pack Joueur : 2 boucliers d''Elo, 1 sablier');
  perform tst.ok((o ->> 'no_ads_until')::timestamptz > public._now() + interval '24 hours', 'heures sans pub cumulées');
  perform public.iap_record(u, 'tx-objets-welcome', 'tx-objets-welcome', 'app.brainlix.bienvenue', 'Production', public._now());
  o := public.boutique_overview();
  perform tst.ok(o ->> 'welcome_until' is null, 'bienvenue : plus proposée une fois prise');
  perform tst.ok((o ->> 'no_ads_until')::timestamptz > public._now() + interval '7 days', 'bienvenue : 7 jours sans pub');
end $$;
