-- Boutique de Léon, vitrine du jour, formes débloquées par l'arbre, nouveaux emplacements.
do $$
declare
  u uuid := tst.new_user();
  o jsonb; s jsonb; r jsonb; v_featured text; v_other text; seeds0 int;
begin
  perform tst.clock('2027-04-12 10:00:00+02');
  perform tst.login(u);

  -- Formes : Bébé dès le départ, les autres avec l'arbre.
  o := public.progression_overview();
  perform tst.ok(o ->> 'best_form' = 'form_baby', 'Bébé au départ');
  update public.profiles set tree_points = 650 where id = u;
  perform tst.ok(public.progression_overview() ->> 'best_form' = 'form_young', 'Jeune plant : Jeune');
  update public.profiles set tree_points = 9000 where id = u;
  perform tst.ok(public.progression_overview() ->> 'best_form' = 'form_sage', 'en fleurs : Sage');
  -- Revenir à une ancienne forme.
  perform tst.ok(public.leon_equip('form', 'form_baby') ->> 'form' = 'form_baby', 'forme choisie');
  perform tst.throws('select public.leon_equip(''form'', ''skin_mint'')', 'item_not_owned');

  -- Vitrine : 3 objets de boutique, stable dans la journée, premier à −30 %.
  s := public.shop_overview();
  perform tst.ok(jsonb_array_length(s -> 'featured') = 3, '3 objets en vitrine');
  perform tst.ok(public.shop_overview() -> 'featured' = s -> 'featured', 'vitrine stable dans la journée');
  perform tst.ok((s -> 'featured' -> 0 ->> 'price')::int < (s -> 'featured' -> 0 ->> 'original')::int, 'premier objet en promo');
  perform tst.ok((s -> 'featured' -> 1 ->> 'price')::int = (s -> 'featured' -> 1 ->> 'original')::int, 'les autres au prix normal');
  perform tst.ok(not exists (select 1 from jsonb_array_elements(s -> 'featured') f join public.items i on i.id = f ->> 'id'
                             where i.rarity <> 'shop'), 'jamais d''objet de coffre ou de fruit en vitrine');

  -- Achat : graines insuffisantes, puis achat au prix promo, jamais deux fois.
  v_featured := s -> 'featured' -> 0 ->> 'id';
  perform tst.throws(format('select public.shop_buy(%L)', v_featured), 'insufficient_seeds');
  perform public._grant(u, 'seeds', 5000, 'test', null, 'test:shop');
  select seeds into seeds0 from public.profiles where id = u;
  r := public.shop_buy(v_featured);
  perform tst.ok((r ->> 'bought')::bool and (r ->> 'price')::int = (s -> 'featured' -> 0 ->> 'price')::int, 'acheté au prix du jour');
  perform tst.ok((select seeds from public.profiles where id = u) = seeds0 - (r ->> 'price')::int, 'graines débitées');
  r := public.shop_buy(v_featured);
  perform tst.ok(not (r ->> 'bought')::bool and (select seeds from public.profiles where id = u) = seeds0 - (s -> 'featured' -> 0 ->> 'price')::int,
                 'déjà possédé : jamais repayé');
  -- Objet des coffres : pas à vendre.
  perform tst.throws('select public.shop_buy(''beret'')', 'item_not_for_sale');
  perform tst.throws('select public.shop_buy(''skin_gold'')', 'item_not_for_sale');
  -- Nouveaux emplacements.
  select id into v_other from public.items where rarity = 'shop' and slot = 'pattern' and id <> v_featured limit 1;
  perform public.shop_buy(v_other);
  perform tst.ok(public.leon_equip('pattern', v_other) ->> 'pattern' = v_other, 'motif porté');
  perform public.shop_buy('bubbles');
  perform tst.ok(public.leon_equip('effect', 'bubbles') ->> 'effect' = 'bubbles', 'effet porté');
  perform tst.ok((select (i ->> 'price')::int from jsonb_array_elements(public.progression_overview() -> 'items') i where i ->> 'id' = 'wings') = 1200,
                 'prix dans la garde-robe');

  -- Sécurité.
  perform tst.ok(not has_function_privilege('authenticated', 'public._shop_price(uuid, text)', 'execute'), 'prix : fonction interne');
  perform tst.ok(has_function_privilege('authenticated', 'public.shop_buy(text)', 'execute'), 'achat ouvert aux connectés');
  perform tst.ok(not has_function_privilege('anon', 'public.shop_buy(text)', 'execute'), 'achat fermé aux anonymes');
end $$;

-- Onboarding : exactement 3 questions, une par catégorie de la banque dédiée, dans l'ordre.
do $$
declare u uuid := tst.new_user(); p jsonb;
begin
  perform tst.login(u);
  p := public.onboarding_pack();
  perform tst.ok(jsonb_array_length(p -> 'questions') = 3, '3 questions, pas 5');
  perform tst.ok((select array_agg(substr(q.external_key, 1, 4) order by t.n)
                  from jsonb_array_elements(p -> 'questions') with ordinality t(e, n)
                  join public.questions q on q.id = (t.e ->> 'id')::uuid) = array['onb1', 'onb2', 'onb3'],
                 'une question qui surprend, une énigme, un « le savais-tu ? »');
end $$;
