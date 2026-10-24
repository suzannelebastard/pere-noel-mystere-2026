# Project notes

- This is a static French-language site with two pages: `index.html` and `tirage.html`.
- Keep the browser code dependency-free; Supabase is accessed through its REST API.
- `supabase.sql` defines the database policies and atomic draw/confirmation functions.
- Never put a Supabase `service_role` key in `config.js`; only the public anon key belongs there.
- Verify browser scripts with `node --check app.js` and serve locally with Python's HTTP server.