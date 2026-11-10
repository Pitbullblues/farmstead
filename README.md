# Eggselent Timers — family beta 0.1.0-beta.1

Independent Android-installable web app for My family farm. React + Vite frontend; Supabase email/password authentication and private shared PostgreSQL data. No ChatGPT dependency at runtime.

## Status

Source package ready for GitHub/Vercel. Not deployed to Vercel and not applied to the hosted Supabase project yet. Database authorization tests run against real PostgreSQL semantics in PGlite; the production build passes. Login layout inspected in a browser. Actual email delivery, hosted Supabase authentication, cross-phone operation, and Android installation still require release verification.

## 1. Put the code in GitHub

Repository: https://github.com/Pitbullblues/farmstead

Upload the **contents of this repository folder** into the repository root, so `package.json`, `index.html`, `src/`, `public/`, and `supabase/` are at the top level. Do not upload a ZIP as the repository's only file. Do not upload `node_modules`, `dist`, `.env.local`, or the private-backup folder shipped alongside this code.

Alternatively, from this folder with GitHub authenticated:

```sh
git init -b main
git add .
git commit -m "Add Eggselent Timers independent family beta"
git remote add origin https://github.com/Pitbullblues/farmstead.git
git push -u origin main
```

Do not force-push if the repository has since received other work. Integrate with its existing branch instead.

## 2. Create the database

Project: https://supabase.com/dashboard/project/qefvkdqfxnsbovmqdyxw

Open SQL Editor. Run these files in order, once:

1. `supabase/migrations/001_family_beta.sql`
2. `supabase/002_owner_setup.sql`

The owner setup authorizes `owner@example.com` to create the first farm after email verification. It does not create an Auth user or password. All others need an in-app family invitation.

The migration owns new `et_*` tables and functions. It does not modify unrelated tables. Keep migration files immutable after applying them; append new numbered migrations for future upgrades.

## 3. Import into Vercel

Import `Pitbullblues/farmstead`. Framework: **Vite**. Root: repository root. Build: `npm run build`. Output: `dist`. Node: 22 or later. Add these environment variables for Production and Preview:

| Variable | Value |
|---|---|
| `VITE_SUPABASE_URL` | `https://qefvkdqfxnsbovmqdyxw.supabase.co` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Copy the publishable value from `.env.example` |

These values identify the client and are included in the browser build. Database protection comes from RLS and authenticated RPC permission checks. Never put a service-role key, database password, SMTP credential, or Supabase management token in a `VITE_` variable.

Deploy. Then record the exact HTTPS production URL.

## 4. Configure sign-in email and URLs

In Supabase Authentication URL Configuration, set Site URL to the deployed production origin, and allow that exact URL as a redirect URL. Add localhost only for development if needed. Use stable production URLs for family invitations and reset links.

Enable email/password sign-in and keep email confirmation enabled. Configure custom SMTP for verification and password-reset emails (for example Resend with your verified sending domain). The default Supabase email service only delivers to organization-team addresses and is not sufficient for ordinary family accounts. Do not add Mom as a database administrator just to receive emails.

In-app “Add family access” reserves an email for 14 days; it does NOT send an invitation email. Copy/share the app link yourself. Confirmation and recovery messages use Supabase's configured SMTP.

## 5. Start the family farm

1. Create your app account with `owner@example.com`, your chosen password, and display name Owner.
2. Confirm the email, then sign in. Your farm is created automatically.
3. Family & app → Import farm backup. Select the separate private `eggselent-farm-backup.json` supplied with this package. Confirm the records before retiring the old app.
4. Family & app → Add family access → enter Mom's exact email.
5. Share the production app link. She chooses Create account, verifies that same email, then signs in. She joins your existing farm automatically.
6. Each phone: open in Chrome → menu → Install app / Add to Home screen.

## Features

- Individual/group animal records, count ranges, housing, breed and age notes.
- Feed stocks, usage/restock logs, estimated days left.
- Shared chore board and server-attributed completion history.
- Owner-managed family access, invitation cancellation, member removal.
- Profile names, separate sign-ins, password reset.
- Polling every 15 seconds while open; refresh on return; open forms pause polling.
- Version checks stop stale writes from overwriting another person's changes.
- Farm backup export and import. Import replaces the shared dataset; export before overwriting.
- Android PWA manifest/icons and clear offline page. No offline writes, background notifications, or native APK.
- Twitch channel display; broadcasting still needs a camera and Twitch setup.
- Existing limited, linked poultry guidance. Not automatic weather alerts or veterinary advice.

## Local development

```sh
npm ci
cp .env.example .env.local
npm run dev
npm test
npm run build
```

The checked-in lockfile fixes exact dependency versions. Tests use an isolated PGlite database and test-only users; they never create real Supabase users or alter your hosted data.

## Release checks

See `docs/BETA_ACCEPTANCE.md`. Do not label the independent version live until these hosted checks pass.

## Technical references

- https://supabase.com/docs/guides/auth/passwords
- https://supabase.com/docs/guides/auth/auth-smtp
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/functions
- https://vercel.com/docs/frameworks/frontend/vite
- https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable
