CREATE EXTENSION IF NOT EXISTS pg_graphql;
CREATE EXTENSION IF NOT EXISTS ulid;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgtap;
CREATE ROLE authenticator noinherit login;
CREATE ROLE anonymous noinherit nologin;
CREATE ROLE webuser noinherit nologin;
CREATE ROLE authenticator noinherit nologin;
CREATE ROLE auth nologin;
CREATE ROLE api nologin;

grant anonymous,
    webuser to authenticator;

alter default privileges revoke execute on functions
from public;

alter default privileges for role auth,
api revoke execute on functions
from public;

-- APP SECTION GOES HERE ---

CREATE schema authorization auth;
set role auth;
CREATE table auth.sessions (
    token text not null primary key default encode(gen_random_bytes(32), 'base64'),
    user_id integer not null references app.users,
    created timestamptz not null default clock_timestamp(),
    expires timestamptz not null default clock_timestamp() + '15min'::interval,
    check (expires > created)
);
comment on table auth.sessions is 'User sessions, both active and expired ones.';
comment on column auth.sessions.expires is 'Time on which the session expires.';

create view auth.active_sessions as
select token,
    user_id,
    created,
    expires
from auth.sessions
where expires > clock_timestamp() with local check option;
comment on view auth.active_sessions is 'View of the currently active sessions';
create index on auth.sessions(expires);

create function auth.clean_sessions() returns void language sql security definer as $$
delete from auth.sessions
where expires < clock_timestamp() - '1day'::interval;
$$;
comment on function auth.clean_sessions is 'Cleans up sessions that have expired longer than a day ago.';

create function auth.login(email text, password text) returns text language sql security definer as $$
insert into auth.active_sessions(user_id)
select user_id
from app.users
where email = login.email
    and password = crypt(login.password, password)
returning token;
$$;
comment on function auth.login is 'Returns the token for a newly created session or null on failure.';
grant execute on function auth.login to anonymous,
    api;

create function auth.refresh_session(session_token text) returns void language sql security definer as $$
update auth.sessions
set expires = default
where token = session_token
    and expires > clock_timestamp() $$;
comment on function auth.refresh_session is 'Extend the expiration time of the given session.';


grant execute on function auth.refresh_session to webuser;

create function auth.logout(token text) returns void language sql security definer as $$
update auth.sessions
set expires = clock_timestamp()
where token = logout.token $$;
comment on function auth.logout is 'Expire the given session.';
grant execute on function auth.logout to webuser;

create function auth.session_user_id(session_token text) returns integer language sql security definer as $$
select user_id
from auth.active_sessions
where token = session_token;
$$;
comment on function auth.session_user_id is 'Returns the id of the user currently authenticated, given a session token';

grant execute on function auth.session_user_id to anonymous;

create function auth.authenticate() returns void language plpgsql as $$
declare session_token text;
session_user_id int;
begin
select current_setting('request.cookie.session_token', true) into session_token;
select auth.session_user_id(session_token) into session_user_id;
if session_user_id is not null then
set local role to webuser;
perform set_config('auth.user_id', session_user_id::text, true);
else
set local role to anonymous;
perform set_config('auth.user_id', '', true);
end if;
end;
$$;
comment on function auth.authenticate is 'Sets the role and user_id based on the session token given as a cookie.';
grant execute on function auth.authenticate to anonymous;

grant usage on schema auth to api,
    anonymous,
    webuser;

reset role;

\ echo 'Creating the api schema...' create schema authorization api;
comment on schema api is 'Schema that defines an API suitable to be exposed through PostgREST';

set role api;

create view api.users as
select user_id,
    name
from app.users;

grant select,
    update(name) on api.users to webuser;


create type api.user as (
    user_id bigint,
    name text,
    email citext
);
create function api.current_user() returns api.user language sql security definer as $$
select user_id,
    name,
    email
from app.users
where user_id = app.current_user_id();
$$;
comment on function api.current_user is 'Information about the currently authenticated user';
grant execute on function api.current_user to webuser;

create function api.login(email text, password text) returns void language plpgsql as $$
declare session_token text;
begin
select auth.login(email, password) into session_token;
if session_token is null then raise insufficient_privilege using detail = 'invalid credentials';
end if;
perform set_config(
    'response.headers',
    '[{"Set-Cookie": "session_token=' || session_token || '; Path=/; Max-Age=600; HttpOnly"}]',
    true
);
end;
$$;
comment on function api.login is 'Creates a new session given valid credentials.';
grant execute on function api.login to anonymous;