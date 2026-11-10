begin;
create table public.et_owner_allowlist(email text primary key);
create table public.et_profiles(id uuid primary key references auth.users(id) on delete cascade,name text not null check(length(name) between 1 and 80));
create table public.et_farms(id uuid primary key default gen_random_uuid(), owner_id uuid not null unique references auth.users(id), data jsonb not null, revision bigint not null default 0);
create table public.et_members(farm_id uuid references public.et_farms(id) on delete cascade,user_id uuid references auth.users(id) on delete cascade,role text not null check(role in ('owner','member')),primary key(farm_id,user_id));
create table public.et_invites(farm_id uuid references public.et_farms(id) on delete cascade,email text not null,expires_at timestamptz not null default now()+interval '14 days',primary key(farm_id,email));
alter table public.et_owner_allowlist enable row level security;
alter table public.et_profiles enable row level security;
alter table public.et_farms enable row level security;
alter table public.et_members enable row level security;
alter table public.et_invites enable row level security;
revoke all on public.et_owner_allowlist,public.et_profiles,public.et_farms,public.et_members,public.et_invites from anon,authenticated;

create function public.et_is_member(f uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.et_members where farm_id=f and user_id=auth.uid()); $$;
create function public.et_is_owner(f uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.et_farms where id=f and owner_id=auth.uid()); $$;
create policy farm_read on public.et_farms for select to authenticated using(public.et_is_member(id));
grant select on public.et_farms to authenticated;

create function public.et_bootstrap(p_name text default 'Farm member') returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); e text; f uuid; member_data jsonb; invite_data jsonb;
begin
 if u is null then raise exception 'Sign in required'; end if;
 select lower(email) into e from auth.users where id=u and email_confirmed_at is not null;
 if e is null then raise exception 'Verify your email before opening the farm'; end if;
 insert into public.et_profiles(id,name) values(u,left(coalesce(nullif(trim(p_name),''),'Farm member'),80)) on conflict(id) do nothing;
 if exists(select 1 from public.et_owner_allowlist where email=e) then
  insert into public.et_farms(owner_id,data) values(u,'{"settings":{"name":"My family farm","location":"Set your location","climate":"humid","channel":"","members":"Owner"},"animals":[],"feeds":[],"chores":[],"logs":[]}'::jsonb) on conflict(owner_id) do nothing;
  select id into f from public.et_farms where owner_id=u;
  insert into public.et_members values(f,u,'owner') on conflict do nothing;
 end if;
 insert into public.et_members(farm_id,user_id,role) select farm_id,u,'member' from public.et_invites where email=e and expires_at>now() on conflict do nothing;
 delete from public.et_invites where email=e and expires_at>now();
 select farm_id into f from public.et_members where user_id=u order by role desc limit 1;
 if f is null then return jsonb_build_object('farm',null,'name',(select name from public.et_profiles where id=u)); end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.user_id,'name',p.name,'role',m.role)),'[]'::jsonb) into member_data from public.et_members m join public.et_profiles p on p.id=m.user_id where m.farm_id=f;
 select coalesce(jsonb_agg(jsonb_build_object('email',email,'expires',expires_at)),'[]'::jsonb) into invite_data from public.et_invites where farm_id=f and public.et_is_owner(f);
 return jsonb_build_object('farm',f,'name',(select name from public.et_profiles where id=u),'role',case when public.et_is_owner(f) then 'owner' else 'member' end,'members',member_data,'invites',invite_data);
end $$;

create function public.et_invite(p_farm uuid,p_email text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.et_is_owner(p_farm) then raise exception 'Only the owner can invite family'; end if;
 if length(p_email)>254 or p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter a valid email'; end if;
 insert into public.et_invites(farm_id,email,expires_at) values(p_farm,lower(trim(p_email)),now()+interval '14 days') on conflict(farm_id,email) do update set expires_at=excluded.expires_at;
end $$;
create function public.et_revoke_invite(p_farm uuid,p_email text) returns void language plpgsql security definer set search_path='' as $$
begin if not public.et_is_owner(p_farm) then raise exception 'Only the owner can remove invitations'; end if;delete from public.et_invites where farm_id=p_farm and email=lower(trim(p_email));end $$;
create function public.et_remove_member(p_farm uuid,p_user uuid) returns void language plpgsql security definer set search_path='' as $$
begin if not public.et_is_owner(p_farm) then raise exception 'Only the owner can remove members';end if;if p_user=auth.uid() then raise exception 'The owner cannot be removed';end if;delete from public.et_members where farm_id=p_farm and user_id=p_user;end $$;
create function public.et_set_name(p_name text) returns void language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null then raise exception 'Sign in required';end if;if length(trim(p_name)) not between 1 and 80 then raise exception 'Name must be 1–80 characters';end if;update public.et_profiles set name=trim(p_name) where id=auth.uid();end $$;

create function public.et_save(p_farm uuid,p_revision bigint,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare old_data jsonb; rev bigint; a jsonb; old_a jsonb; arr jsonb; k text; actor text; u uuid:=auth.uid();
begin
 if not public.et_is_member(p_farm) then raise exception 'You do not have access to this farm'; end if;
 select data,revision into old_data,rev from public.et_farms where id=p_farm for update;
 if rev<>p_revision then raise exception 'FARM_CONFLICT: The farm changed on another device. Close the form, refresh, then try again.';end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>500000 then raise exception 'Invalid farm data';end if;
 if jsonb_typeof(p_data->'settings') is distinct from 'object' then raise exception 'Invalid settings';end if;
 if coalesce(p_data#>>'{settings,climate}','') not in ('humid','cold','dry','temperate') or coalesce(p_data#>>'{settings,channel}','') !~ '^[A-Za-z0-9_]{0,25}$' then raise exception 'Invalid climate or channel';end if;
 foreach k in array array['animals','feeds','chores','logs'] loop
  if jsonb_typeof(p_data->k) is distinct from 'array' or jsonb_array_length(p_data->k)>5000 then raise exception 'Invalid record list';end if;
  if (select count(*)<>count(distinct value->>'id') from jsonb_array_elements(p_data->k)) then raise exception 'Record IDs must be present and unique';end if;
  for a in select value from jsonb_array_elements(p_data->k) loop
   if length(coalesce(a->>'id','')) not between 1 and 80 then raise exception 'Invalid record ID';end if;
   if k='animals' and (coalesce((a->>'count')::numeric,0)<1 or (a->>'count')::numeric<>trunc((a->>'count')::numeric) or coalesce((a->>'countMax')::numeric,(a->>'count')::numeric)<(a->>'count')::numeric) then raise exception 'Invalid animal count';end if;
   if k='feeds' and (coalesce((a->>'stock')::numeric,-1)<0 or coalesce((a->>'daily')::numeric,-1)<0 or coalesce((a->>'threshold')::numeric,-1)<0) then raise exception 'Feed amounts must be nonnegative';end if;
   if k='logs' and (coalesce((a->>'amount')::numeric,0)<=0 or coalesce(a->>'action','') not in ('used','restocked')) then raise exception 'Invalid feed log';end if;
  end loop;
 end loop;
 select name into actor from public.et_profiles where id=u;
 arr:='[]'::jsonb;
 for a in select value from jsonb_array_elements(p_data->'logs') loop
  select value into old_a from jsonb_array_elements(old_data->'logs') where value->>'id'=a->>'id';
  arr:=arr||jsonb_build_array(coalesce(old_a,a||jsonb_build_object('by',actor,'byId',u,'at',now())));
 end loop;
 p_data:=jsonb_set(p_data,'{logs}',arr);
 arr:='[]'::jsonb;
 for a in select value from jsonb_array_elements(p_data->'chores') loop
  select value into old_a from jsonb_array_elements(old_data->'chores') where value->>'id'=a->>'id';
  if a->>'done'='true' then
   if old_a->>'done'='true' then a:=(a-'completedBy'-'completedById'-'completedAt')||jsonb_build_object('completedBy',old_a->'completedBy','completedById',old_a->'completedById','completedAt',old_a->'completedAt');
   else a:=a||jsonb_build_object('completedBy',actor,'completedById',u,'completedAt',now());end if;
  else a:=a-'completedBy'-'completedById'-'completedAt';end if;
  arr:=arr||jsonb_build_array(a);
 end loop;
 p_data:=jsonb_set(p_data,'{chores}',arr);
 update public.et_farms set data=p_data,revision=rev+1 where id=p_farm;
 return jsonb_build_object('data',p_data,'revision',rev+1);
end $$;

revoke all on function public.et_is_member(uuid),public.et_is_owner(uuid),public.et_bootstrap(text),public.et_invite(uuid,text),public.et_revoke_invite(uuid,text),public.et_remove_member(uuid,uuid),public.et_set_name(text),public.et_save(uuid,bigint,jsonb) from public,anon;
grant execute on function public.et_is_member(uuid),public.et_is_owner(uuid),public.et_bootstrap(text),public.et_invite(uuid,text),public.et_revoke_invite(uuid,text),public.et_remove_member(uuid,uuid),public.et_set_name(text),public.et_save(uuid,bigint,jsonb) to authenticated;
commit;
