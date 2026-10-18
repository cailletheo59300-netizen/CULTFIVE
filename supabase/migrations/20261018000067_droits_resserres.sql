-- Sécurité (D-070) : droits resserrés, par précaution (la protection des lignes bloquait déjà tout).
-- 1. Duels, réponses de duel et signalements ne passent que par les fonctions du serveur : aucun droit direct sur
--    ces tables. Quêtes : lecture des siennes seulement (règle existante), plus d'écriture directe.
revoke all on public.duels, public.duel_answers, public.question_reports from anon, authenticated;
revoke all on public.user_quests from anon;
revoke insert, update, delete, truncate, references, trigger on public.user_quests from authenticated;

-- 2. Fonctions internes : plus exécutables sans connexion (le droit venait de PUBLIC). Un joueur connecté, invité
--    compris, garde le droit : des fonctions appelées avec ses droits en ont besoin (_require_user → _is_banned).
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proname like '\_%'
             and has_function_privilege('anon', p.oid, 'execute') loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;
