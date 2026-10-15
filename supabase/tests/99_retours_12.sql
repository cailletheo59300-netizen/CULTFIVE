-- Retours 1.2 (0057) : tickets plafonnés à 5, questions carte hors du 5 du jour et plus difficiles.

-- 1. Tickets : 5 au plus, le surplus en neurones (30 chacun).
do $$
declare u uuid := tst.new_user(); r jsonb; s0 int;
begin
  perform tst.login(u);
  perform public.album_overview();
  perform tst.ok((select tickets from public.user_album where user_id = u) = 3, '3 tickets de bienvenue');
  s0 := (select seeds from public.profiles where id = u);
  update public.user_album set tickets = tickets + 1 where user_id = u;
  perform tst.ok((select tickets from public.user_album where user_id = u) = 4
                 and (select seeds from public.profiles where id = u) = s0, 'sous 5 : rien ne change');
  update public.user_album set tickets = tickets + 3 where user_id = u;
  perform tst.ok((select tickets from public.user_album where user_id = u) = 5, 'plafond : 5 tickets');
  perform tst.ok((select seeds from public.profiles where id = u) = s0 + 60, '2 tickets en trop = 60 neurones');
  perform tst.ok((select count(*) from public.ledger where user_id = u and reason = 'ticket_overflow' and amount = 60) = 1,
                 'journal : ticket_overflow');
  update public.user_album set tickets = tickets + 1 where user_id = u;
  perform tst.ok((select seeds from public.profiles where id = u) = s0 + 90, 'encore un : +30');
  -- Une pochette ouverte libère une place.
  r := public.album_open_pack('history', 'ticket');
  perform tst.ok((select tickets from public.user_album where user_id = u) = 4, 'pochette ouverte : 4 tickets');
end $$;

-- 2. 5 du jour sans question carte, sur 30 jours ; plus souvent 2 nouveaux types.
do $$
declare d date; v_two int := 0;
begin
  for k in 0 .. 29 loop
    d := date '2027-05-01' + k;
    perform public._generate_daily_set(d);
    perform tst.ok(not exists (
      select 1 from public.daily_set_items i
      join public.questions q on q.id = i.question_id
      left join public.questions f on f.id = i.fallback_question_id
      where i.daily_date = d and (q.type = 'map_pick' or f.type = 'map_pick')), d || ' : pas de question carte');
    if (select count(*) from public.daily_set_items i join public.questions q on q.id = i.question_id
        where i.daily_date = d and not public._is_classic(q.type)) = 2 then v_two := v_two + 1; end if;
  end loop;
  perform tst.ok(v_two >= 10, format('2 nouveaux types plus souvent (%s jours sur 30)', v_two));
end $$;

-- 3. Questions carte plus difficiles.
do $$
begin
  perform tst.ok((select avg(difficulty_effective) from public.questions where type = 'map_pick') >= 65,
                 'questions carte : difficiles');
end $$;

-- 4. Défis : chaque défi dit où aller.
do $$
declare u uuid := tst.new_user(); o jsonb;
begin
  perform tst.login(u);
  o := public.quests_overview();
  perform tst.ok(not exists (select 1 from jsonb_array_elements(o -> 'day' -> 'quests' || o -> 'week' -> 'quests') e
                             where e ->> 'goal' is null), 'défis : un but pour chacun');
  perform tst.ok((o -> 'day' -> 'quests' -> 0 ->> 'goal') = 'daily', 'premier défi du jour : le 5 du jour');
  perform tst.ok(not exists (select 1 from jsonb_array_elements(o -> 'day' -> 'quests') e
                             where e ->> 'goal' = 'domain' and e ->> 'param' is null), 'domaine : précisé');
  o := public.season_overview();
  perform tst.ok(jsonb_array_length(o -> 'missions') = 12
                 and not exists (select 1 from jsonb_array_elements(o -> 'missions') e where e ->> 'goal' is null),
                 'missions : un but pour chacune');
end $$;
