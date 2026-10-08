-- 0040 : nouveaux types de réponses, lot 2. Valeurs d'énumération seules (utilisées par 0041).
alter type public.question_type add value if not exists 'number_target';  -- le compte est bon
alter type public.question_type add value if not exists 'riddle';         -- mot mystère en 3 indices
alter type public.question_type add value if not exists 'map_pin';        -- épingle sur la carte
alter type public.question_type add value if not exists 'sort';           -- tri express (paniers) et pyramide des âges (époques)
