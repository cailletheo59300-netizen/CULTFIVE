-- Boutique (D-118) : « Sans pub pour toujours », achats enregistrés par iap_record, heures sans pub, remboursement.
do $$
declare
  u uuid := tst.new_user();
  v uuid := tst.new_user();
  r jsonb; st jsonb;
begin
  perform tst.clock('2026-11-25 10:00:00+01');
  perform tst.login(u);
  update public.profiles set created_at = public._now() - interval '10 days' where id = u;

  st := public.ad_status();
  perform tst.ok(not (st ->> 'no_ads')::bool and not (st ->> 'no_ads_forever')::bool and (st ->> 'interstitial')::bool,
                 'pubs pour un joueur sans achat');

  -- Produit inconnu refusé.
  perform tst.throws(format('select public.iap_record(%L, ''tx-?'', ''tx-?'', ''app.brainlix.jackpot'', ''Production'', now())', u),
                     'wrong_product');

  -- Achat « Sans pub pour toujours », idempotent, lié au compte.
  r := public.iap_record(u, 'tx-boutique-noads-1', 'tx-boutique-noads-1', 'app.brainlix.noads', 'Production', public._now());
  perform tst.ok((r ->> 'active')::bool and (r ->> 'recorded')::bool and r ->> 'product' = 'app.brainlix.noads', 'achat enregistré');
  r := public.iap_record(u, 'tx-boutique-noads-1', 'tx-boutique-noads-1', 'app.brainlix.noads', 'Production', public._now());
  perform tst.ok(not (r ->> 'recorded')::bool, 'achat renvoyé : une seule fois');
  r := public.iap_record(u, 'tx-boutique-noads-2', 'tx-boutique-noads-2', 'app.brainlix.noads', 'Production', public._now());
  perform tst.ok((r ->> 'active')::bool and not (r ->> 'recorded')::bool, 'déjà possédé : pas de second achat noté');
  perform tst.throws(format('select public.iap_record(%L, ''tx-boutique-noads-1'', ''tx-boutique-noads-1'', ''app.brainlix.noads'', ''Production'', now())', v),
                     'transaction_other_user');

  st := public.ad_status();
  perform tst.ok((st ->> 'no_ads')::bool and (st ->> 'no_ads_forever')::bool and not (st ->> 'pass_plus')::bool,
                 'plus de pub, sans Pass+');
  perform tst.ok(not (st ->> 'interstitial')::bool, 'plus de pub entre les parties');

  -- Bonus « pub » donnés sans vidéo.
  r := public.ad_claim('free_chest');
  perform tst.ok(r ? 'chest_id', 'coffre offert sans vidéo');
  perform tst.throws('select public.ad_can(''free_chest'')', 'ad_limit');

  -- Le Pass+ passe aussi par iap_record.
  r := public.iap_record(u, 'tx-boutique-pass', 'tx-boutique-pass', 'app.brainlix.pass', 'Production', public._now());
  perform tst.ok((r ->> 'recorded')::bool and r ->> 'product' = 'app.brainlix.pass' and (public.ad_status() ->> 'pass_plus')::bool,
                 'Pass+ par iap_record');

  -- Remboursement : plus de « sans pub pour toujours » (le Pass+ reste).
  r := public.pass_plus_revoke('tx-boutique-noads-1');
  perform tst.ok((r ->> 'revoked')::bool and not (public.ad_status() ->> 'no_ads_forever')::bool, 'remboursement retiré');
  perform public.pass_plus_revoke('tx-boutique-pass');
  perform tst.ok(not (public.ad_status() ->> 'no_ads')::bool, 'plus rien : pubs de retour');

  -- Heures sans pub (packs, bienvenue).
  update public.profiles set no_ads_until = public._now() + interval '1 hour' where id = u;
  st := public.ad_status();
  perform tst.ok((st ->> 'no_ads')::bool and not (st ->> 'interstitial')::bool and st ->> 'no_ads_until' is not null, 'une heure sans pub');
  perform tst.tick('61 minutes');
  st := public.ad_status();
  perform tst.ok(not (st ->> 'no_ads')::bool and st -> 'no_ads_until' = 'null'::jsonb, 'heure finie : pubs de retour');
end $$;
