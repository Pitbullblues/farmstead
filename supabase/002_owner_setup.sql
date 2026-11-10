-- Run after the migration. This email may create the initial farm only after verification.
insert into public.et_owner_allowlist(email) values ('owner@example.com') on conflict do nothing;
