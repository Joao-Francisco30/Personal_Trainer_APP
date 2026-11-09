# PT App

A personal app for a personal trainer to create workout and eating regimens for clients. Clients will get a phone app (iPhone and Android) to see their plans, answer questions, and send measurements, photos and videos.

**Status:** PT dashboard in progress. Client mobile app comes later.

## Stack

- **Database, login, file storage:** Supabase (PostgreSQL with row-level security)
- **PT dashboard:** one plain HTML/JavaScript file (`index.html`), no build step
- **Client app (planned):** Expo (React Native)

## Project structure

```
index.html              PT dashboard
database/
  001_schema.sql        tables, security rules, storage bucket
  002_templates.sql     plan templates and plan copying
```

## Setup

1. Create a free project at [supabase.com](https://supabase.com).
2. In **Authentication > Users**, add the PT's login (email and password).
3. In **SQL Editor**, run `database/001_schema.sql` (replace `PT_EMAIL_HERE` with the PT's email first), then `database/002_templates.sql`.
4. In `index.html`, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` at the top of the script. Both are in **Project Settings > API**. Use the anon (publishable) key only. Never use the `service_role` key.

## Run locally

There is nothing to install. Use any of these from the project folder:

```bash
# Option 1: just open the file
start index.html          # Windows
open index.html           # macOS

# Option 2: serve it locally (Python)
python -m http.server 8000
# then open http://localhost:8000

# Option 3: serve it locally (Node, no install needed)
npx serve .
```

Sign in with the PT account created in step 2.

## Deploy

Host the folder on any static host (GitHub Pages, Netlify, Cloudflare Pages). For GitHub Pages: **Settings > Pages > Deploy from branch `main`**.

## Adding a database change

Never edit an old SQL file. Add a new numbered one (`003_...sql`), run it in the SQL Editor, and commit it.

## Roadmap

- [x] Database schema and security rules
- [x] PT login
- [x] Client list and profiles
- [x] Measurements
- [x] Photo and video gallery
- [x] FAQ and video links editor
- [x] Exercise library
- [x] Workout plan builder
- [x] Workout templates and assigning to clients
- [x] Meal plan builder and templates
- [ ] Questions and check-ins
- [ ] Progress charts
- [ ] Messages
- [ ] Client mobile app
