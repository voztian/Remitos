-- Sólo para PostgreSQL en memoria. No ejecutar en Supabase.
create role anon;
create role authenticated;
create schema auth;
create schema storage;
create schema extensions;
create publication supabase_realtime;
create extension pgcrypto with schema extensions;
create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}',raw_app_meta_data jsonb default '{}',created_at timestamptz default now());
create table auth.identities(id uuid primary key default gen_random_uuid(),user_id uuid references auth.users(id),provider text,identity_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth,public,storage to anon,authenticated;
grant execute on function auth.uid() to anon,authenticated;
create table public.empresas(id uuid primary key default gen_random_uuid(),nombre text not null,cuit text,codigo_invitacion text,created_at timestamptz default now());
create table public.perfiles(id uuid primary key references auth.users(id),nombre text,rol text,empresa_id uuid references empresas(id),created_at timestamptz default now(),updated_at timestamptz default now());
create table public.remitos(id uuid primary key default gen_random_uuid(),empresa_id uuid references empresas(id),num text,cliente text,dir text,contacto text,tel text,chofer_nombre text,chofer_id uuid references perfiles(id),fecha date,estado text,created_by uuid,created_at timestamptz default now(),conformidad text,obs text,nota text,receptor_nombre text,receptor_dni text,firma_url text,foto_entrega_url text,foto_manual_url text,ts_firma timestamptz);
create table public.items_remito(id uuid primary key default gen_random_uuid(),remito_id uuid references remitos(id) on delete cascade,cod text,descripcion text,qty numeric,orden integer,estado text,qty_recibida numeric,nota text,foto_url text);
create table storage.buckets(id text primary key,name text,public boolean default false,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,owner_id text,metadata jsonb default '{}',user_metadata jsonb default '{}',created_at timestamptz default now(),unique(bucket_id,name));
alter table storage.objects enable row level security;
grant select,insert,update,delete on storage.objects to authenticated;
create function storage.foldername(name text) returns text[] language sql immutable as $$ select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1] $$;
insert into empresas(id,nombre,cuit,codigo_invitacion) values
 ('00000000-0000-4000-8000-000000000001','EMPRESA FICTICIA A','20123456786','ABCDEF012345'),
 ('00000000-0000-4000-8000-000000000002','EMPRESA FICTICIA B','20123456786','123456ABCDEF');
insert into auth.users(id,email,email_confirmed_at) values
 ('10000000-0000-4000-8000-000000000001','admin-a@example.invalid',now()),
 ('10000000-0000-4000-8000-000000000002','oficina-a@example.invalid',now()),
 ('10000000-0000-4000-8000-000000000003','chofer-a@example.invalid',now()),
 ('10000000-0000-4000-8000-000000000004','otro-chofer-a@example.invalid',now()),
 ('20000000-0000-4000-8000-000000000001','admin-b@example.invalid',now()),
 ('20000000-0000-4000-8000-000000000003','chofer-b@example.invalid',now());
insert into perfiles(id,nombre,rol,empresa_id) values
 ('10000000-0000-4000-8000-000000000001','Admin ficticio A','admin','00000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002','Oficina ficticia A','oficina','00000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000003','Chofer ficticio A','chofer','00000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000004','Otro chofer ficticio A','chofer','00000000-0000-4000-8000-000000000001'),
 ('20000000-0000-4000-8000-000000000001','Admin ficticio B','admin','00000000-0000-4000-8000-000000000002'),
 ('20000000-0000-4000-8000-000000000003','Chofer ficticio B','chofer','00000000-0000-4000-8000-000000000002');
