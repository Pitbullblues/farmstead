import {PGlite} from '@electric-sql/pglite';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;grant usage on schema auth to authenticated;grant execute on function auth.uid() to authenticated;`);
await db.exec(readFileSync('supabase/migrations/001_family_beta.sql','utf8'));
await db.exec(readFileSync('supabase/002_owner_setup.sql','utf8'));
const owner='00000000-0000-4000-8000-000000000001',mom='00000000-0000-4000-8000-000000000002',stranger='00000000-0000-4000-8000-000000000003';
await db.query('insert into auth.users values ($1,$2,now()),($3,$4,now()),($5,$6,now())',[owner,'owner@example.com',mom,'mom@example.test',stranger,'stranger@example.test']);
async function as(u){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[u||'']);await db.exec(u?'set role authenticated':'set role anon')}
async function call(sql,params=[]){return (await db.query(sql,params)).rows[0]?.r}
async function denied(sql,params=[]){await assert.rejects(db.query(sql,params));}
await as(owner);const info=await call("select public.et_bootstrap('Owner') r");assert.equal(info.role,'owner');const f=info.farm;
const initial=await call('select data r from public.et_farms where id=$1',[f]);
await as(stranger);assert.equal((await call("select public.et_bootstrap('Stranger') r")).farm,null);assert.equal((await db.query('select * from public.et_farms')).rows.length,0);await denied('select public.et_save($1,0,$2)',[f,initial]);await denied('select public.et_invite($1,$2)',[f,'bad@example.test']);
await as(null);await denied('select public.et_bootstrap()');await denied('select * from public.et_farms');
await as(owner);await db.query('select public.et_invite($1,$2)',[f,'MOM@example.test']);
await as(mom);const mi=await call("select public.et_bootstrap('Mom') r");assert.equal(mi.farm,f);assert.equal(mi.role,'member');await denied('select public.et_invite($1,$2)',[f,'stranger@example.test']);await denied('update public.et_farms set revision=99 where id=$1',[f]);await denied('insert into public.et_members values($1,$2,$3)',[f,stranger,'owner']);
let state=structuredClone(initial);state.feeds=[{id:'feed',name:'Pellets',stock:50,daily:5,threshold:10}];state.logs=[];state.chores=[{id:'water',title:'Water',done:false}];
await as(owner);let saved=await call('select public.et_save($1,0,$2) r',[f,state]);
const stale=structuredClone(saved.data);saved.data.feeds[0].stock=45;saved.data.logs=[{id:'log',feed:'feed',amount:5,action:'used',by:'Imposter',at:'fake'}];saved=await call('select public.et_save($1,1,$2) r',[f,saved.data]);assert.equal(saved.data.logs[0].by,'Owner');assert.equal(saved.revision,2);
await as(mom);await denied('select public.et_save($1,1,$2)',[f,stale]);saved.data.chores[0].done=true;saved.data.logs[0].by='Imposter';saved=await call('select public.et_save($1,2,$2) r',[f,saved.data]);assert.equal(saved.data.logs[0].by,'Owner');assert.equal(saved.data.chores[0].completedBy,'Mom');
let invalid=structuredClone(saved.data);invalid.feeds[0].stock=-5;await denied('select public.et_save($1,3,$2)',[f,invalid]);
await db.query("select public.et_set_name('Mother')");assert.equal((await call("select public.et_bootstrap('Mom') r")).name,'Mother');
await as(owner);await denied('select public.et_remove_member($1,$2)',[f,owner]);await db.query('select public.et_remove_member($1,$2)',[f,mom]);await as(mom);assert.equal((await db.query('select * from public.et_farms')).rows.length,0);await denied('select public.et_save($1,3,$2)',[f,saved.data]);
await as(owner);await db.query('select public.et_invite($1,$2)',[f,'stranger@example.test']);await db.query('select public.et_revoke_invite($1,$2)',[f,'stranger@example.test']);await as(stranger);assert.equal((await call("select public.et_bootstrap('Stranger') r")).farm,null);
console.log('PASS: owner-only setup, verified-email membership, invitation claim/revoke, RLS isolation, anonymous denial, role escalation denial, direct-write denial, two-user attribution, conflict protection, invalid stock rejection, removal immediately revokes data access.');
await db.close();
