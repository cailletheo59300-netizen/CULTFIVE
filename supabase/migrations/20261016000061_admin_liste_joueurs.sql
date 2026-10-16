-- ─────────────────────────────────────────── 0061 · Admin : la liste des joueurs suit la règle des vrais joueurs
-- « Vrais joueurs » (par défaut) = même règle que les chiffres de l'admin (_real_player, 0060). En plus :
-- « Comptes connectés » (Apple ou e-mail) et « Tous ». Chaque ligne dit si c'est un vrai joueur.
do $$
declare v_old text; v_new text;
begin
  v_old := pg_get_functiondef('public.admin_users(text, text, int, int, text)'::regprocedure);
  v_new := replace(v_old,
    $o$and (coalesce(p_scope, 'real') = 'all' or p.onboarded_at is not null or not coalesce(u.is_anonymous, true)))$o$,
    $n$and (case coalesce(p_scope, 'real')
               when 'all' then true
               when 'connected' then not coalesce(u.is_anonymous, true)
               else public._real_player(p.id) end))$n$);
  v_new := replace(v_new, $o$coalesce(u.is_anonymous, true) as anonymous,$o$,
                          $n$coalesce(u.is_anonymous, true) as anonymous, public._real_player(p.id) as real_player,$n$);
  if (length(v_new) - length(v_old)) < 100 then raise exception '0061: admin_users inchangée'; end if;
  execute v_new;
end $$;
