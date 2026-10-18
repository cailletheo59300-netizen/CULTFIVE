-- Vitesse (D-071) : la liste des questions protégées (séries du jour à venir) était recalculée pour chacune des
-- ~9 600 questions candidates (≈ 2 ms × 9 600). Elle est désormais calculée une fois par appel, dans les fonctions qui
-- choisissent des questions : duels (1,25 s → 0,07 s en production), ligues, révision des erreurs, partie de bienvenue.
-- Les règles de choix ne changent pas.
do $$
declare
  f record;
  v_old text;
  v_new text;
  v_done int := 0;
begin
  for f in select p.oid from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and pg_get_functiondef(p.oid) like '%<> all (public._protected_daily_questions())%' loop
    v_old := pg_get_functiondef(f.oid);
    v_new := replace(v_old, '<> all (public._protected_daily_questions())',
                     '<> all ((select public._protected_daily_questions())::uuid[])');
    execute v_new;
    v_done := v_done + 1;
  end loop;
  if v_done < 4 then raise exception '0068 : % fonctions seulement', v_done; end if;
end $$;

-- Fin de partie : les réponses d'une partie se retrouvent par sa session, sans relire tout l'historique du joueur.
create index if not exists question_attempts_session_idx on public.question_attempts (session_id);
