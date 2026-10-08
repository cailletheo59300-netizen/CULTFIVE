-- 0038 : nouveaux types de réponses (5 du jour et, avec parcimonie, parties classées).
-- Seules les valeurs d'énumération sont ajoutées ici : une nouvelle valeur ne peut servir qu'une fois validée,
-- d'où une migration à part (fonctions dans 0039).
alter type public.question_type add value if not exists 'counter';       -- compteur (nombre, marge annoncée ou exact)
alter type public.question_type add value if not exists 'timeline';      -- frise (année, marge)
alter type public.question_type add value if not exists 'gauge';         -- jauge de pourcentage (marge)
alter type public.question_type add value if not exists 'proportion';    -- étirer à la vraie taille (marge relative)
alter type public.question_type add value if not exists 'letters';       -- lettres mélangées
alter type public.question_type add value if not exists 'word_order';    -- mots dans l'ordre
alter type public.question_type add value if not exists 'image_choice';  -- choix d'images (drapeaux, tableaux)
