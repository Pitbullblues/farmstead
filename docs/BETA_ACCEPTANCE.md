# Family beta acceptance

Completed locally:
- [x] TypeScript and Vite production build.
- [x] PostgreSQL migration and function execution in PGlite.
- [x] Uninvited and anonymous users cannot read farm data.
- [x] Members cannot grant themselves owner access or write tables directly.
- [x] Owner can invite/revoke; an invited verified account joins the correct farm.
- [x] Member removal blocks subsequent reads and writes.
- [x] New feed logs/chore completions use authenticated identity.
- [x] Existing attribution cannot be changed through normal save.
- [x] Stale revision cannot overwrite another phone's update.
- [x] Negative feed stock is rejected.
- [x] Login page visually inspected.

Pending on actual hosted services / two Android phones:
- [ ] Source pushed to the user's GitHub repository.
- [ ] Migration applied to qefvkdqfxnsbovmqdyxw.
- [ ] Vercel deployed with environment variables.
- [ ] Auth URL configuration and custom SMTP configured.
- [ ] Owner registration and confirmation email work.
- [ ] Password reset email and reset page work.
- [ ] Current backup imported and animal/housing totals verified.
- [ ] Mom invited, registered, verified, and signed in.
- [ ] Feed logged on one phone appears on the other within 15 seconds.
- [ ] Chore completion appears with the correct person's name.
- [ ] Both phones close/reopen and retain their sessions and records.
- [ ] Both phones install the home-screen app.
- [ ] Offline edits show a clear failure and do not claim to save.
- [ ] Two simultaneous edits fail safely rather than overwrite.

Rollback: keep the original ChatGPT-hosted app and exported backup until the independent version passes the above. Restoring code on Vercel does not reverse database migrations; apply forward fixes. Do not run the initial migration again on an already initialized database.
