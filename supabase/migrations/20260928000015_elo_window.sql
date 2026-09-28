-- Brainlix — 0015 Questions choisies par écart de cote (≈ 65 % de réussite en partie classée)
-- On ne vise plus un pourcentage : chaque question est tirée dans une fenêtre de cote autour de celle du joueur.
-- Écart = cote de la question − cote du joueur ; chances de réussite = 1 / (1 + 10^(écart / 400)).
-- Classé : 50 % « un peu en dessous » (−250 à −75), 30 % « à ton niveau » (−100 à +25),
--          15 % « accessibles » (−400 à −250), 5 % « au-dessus » (+25 à +175). Réussite mesurée ≈ 65 % (simulation).
-- Défi :   60 % « à ton niveau et au-dessus » (−50 à +100), 25 % « au-dessus » (+100 à +250), 15 % (−150 à −50). ≈ 45 %.
-- Plus d'exploration aléatoire : les questions peu calibrées se calibrent en étant servies dans leur fenêtre.

-- Chances de réussite pour un écart de cote donné.
create or replace function public._p_of_gap(p_gap real) returns real
language sql immutable as $$ select (1 / (1 + power(10, p_gap / 400.0)))::real $$;

-- Garde la même interface (lo/hi en probabilité) : _select_questions convertit en difficulté.
-- lo = chances pour l'écart le plus haut (question la plus dure de la fenêtre), hi = pour l'écart le plus bas.
create or replace function public._band_bounds(p_mode text, out lo real, out hi real, out explore bool)
language plpgsql volatile as $$
declare
  r double precision := random();
  g_lo real; g_hi real;
begin
  explore := false;
  if p_mode = 'challenge' then
    if r < 0.60 then g_lo := -50; g_hi := 100;
    elsif r < 0.85 then g_lo := 100; g_hi := 250;
    else g_lo := -150; g_hi := -50; end if;
  else
    if r < 0.50 then g_lo := -250; g_hi := -75;
    elsif r < 0.80 then g_lo := -100; g_hi := 25;
    elsif r < 0.95 then g_lo := -400; g_hi := -250;
    else g_lo := 25; g_hi := 175; end if;
  end if;
  lo := public._p_of_gap(g_hi);
  hi := public._p_of_gap(g_lo);
end $$;
