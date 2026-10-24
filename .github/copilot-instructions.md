# Project notes

- This is a static French-language site with three pages: `index.html`, `tirage.html`, and `revelation.html`.
- Keep the browser code dependency-free; Supabase is accessed through its REST API.
- `supabase.sql` defines database policies, atomic drawing/archiving, and one-time music reveal functions.
- Never put a Supabase `service_role` key in `config.js`; only the public anon key belongs there.
- Verify browser scripts with `node --check app.js` and serve locally with Python's HTTP server.