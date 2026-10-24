# Père Noël mystère

Trois pages statiques : dépôt anonyme d’une musique (ou son URL), tirage individuel, puis révélation collective une musique à la fois. La limite est de 2 048 caractères. Une musique provisoire reste réservable pendant 15 minutes; le bouton de relance la libère et en réserve une autre. La validation transfère la musique vers l’archive, la retire des musiques disponibles et empêche un second tirage confirmé depuis le même navigateur.

## Configuration

1. Créez un projet Supabase et exécutez le contenu de `supabase.sql` dans l’éditeur SQL.
2. Dans `config.js`, remplacez `YOUR_PROJECT` par l’identifiant du projet et `YOUR_SUPABASE_ANON_KEY` par sa clé publique `anon`.
3. N’utilisez jamais la clé `service_role` dans le navigateur.
4. Pour un test local, lancez `python -m http.server 8000` depuis ce dossier puis ouvrez `http://localhost:8000`.

Le tirage reste verrouillé par défaut, y compris si quelqu’un connaît directement son URL. Après avoir vérifié que tous les collègues ont déposé leur musique, fermez les participations et ouvrez le tirage dans l’éditeur SQL Supabase avec `update public.draw_settings set submissions_open = false, is_open = true where id = 1;`. Une fois les tirages individuels terminés, fermez le tirage et ouvrez les révélations avec `update public.draw_settings set is_open = false, reveal_open = true where id = 1;`. L’API refuse toute révélation tant que `is_open` vaut `true`.

La page dédiée se trouve à `revelation.html`. Chaque clic y révèle et marque une musique de l’archive; aucune musique révélée ne sera proposée de nouveau. Les musiques archivées restent consultables dans `public.drawn_keywords`.

La limite d’un tirage confirmé repose sur un identifiant conservé dans le navigateur et en base. Sans compte ni code d’accès, elle ne peut pas identifier une personne qui change de navigateur ou efface ses données. Le projet Supabase et le site doivent être partagés avec l’équipe pour utiliser la même liste.