-- --------------------- PG_GRAPQL Flow --------------------------
CREATE EXTENSION IF NOT EXISTS pg_graphql;
CREATE EXTENSION IF NOT EXISTS ulid;

CREATE ROLE anonymous NOLOGIN;
CREATE ROLE beznet NOLOGIN;

CREATE ROLE authenticator NOINHERIT NOCREATEDB NOCREATEROLE NOSUPERUSER LOGIN;
ALTER ROLE authenticator WITH PASSWORD '1414{bruno}';

GRANT anonymous TO authenticator;
GRANT beznet TO authenticator;

CREATE SCHEMA api;
CREATE SCHEMA auth;

GRANT usage ON SCHEMA auth TO beznet, anonymous;

GRANT usage ON schema api TO beznet;
ALTER DEFAULT PRIVILEGES IN SCHEMA api
GRANT All ON tables TO beznet;

ALTER DEFAULT PRIVILEGES IN SCHEMA api
GRANT All ON FUNCTIONS TO beznet;

ALTER DEFAULT PRIVILEGES IN SCHEMA api
GRANT All ON sequences TO beznet;

GRANT usage ON schema graphql TO beznet;
GRANT EXECUTE ON FUNCTION graphql.resolve TO beznet;

ALTER DEFAULT PRIVILEGES IN SCHEMA graphql
GRANT ALL ON FUNCTIONS TO beznet;

ALTER DEFAULT PRIVILEGES IN SCHEMA graphql
GRANT All ON FUNCTIONS TO beznet;

ALTER DEFAULT PRIVILEGES IN SCHEMA graphql
GRANT All ON sequences TO beznet;


GRANT usage ON schema api TO anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA api
GRANT All ON tables TO anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA api
GRANT All ON FUNCTIONS TO anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA api
GRANT All ON sequences TO anonymous;
GRANT usage ON schema graphql TO anonymous;
GRANT EXECUTE ON FUNCTION graphql.resolve TO anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA graphql
GRANT ALL ON FUNCTIONS TO anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA graphql
GRANT All ON FUNCTIONS TO anonymous;
ALTER DEFAULT PRIVILEGES IN SCHEMA graphql
GRANT All ON sequences TO anonymous;

-- GraphQL Entrypoint
create function api.graphql(
  "operationName" text default null,
  query text default null,
  variables jsonb default null,
  extensions jsonb default null
) returns jsonb language sql as $$
select graphql.resolve(
    query := query,
    variables := coalesce(variables, '{}'),
    "operationName" := "operationName",
    extensions := extensions
  );
$$;

CREATE OR REPLACE FUNCTION auth.authenticate() RETURNS void AS $$
DECLARE email text := current_setting('request.jwt.claims', true)::json->>'email';
BEGIN 
RAISE WARNING 'request.jwt.claims = %',
current_setting('request.jwt.claims');
EXCEPTION
WHEN OTHERS THEN RAISE WARNING 'request.jwt.claims = (no way)';
IF email = 'beznet22@gmail.com' THEN RAISE EXCEPTION 'No, you are evil' USING HINT = 'Stop being so evil and maybe you can log in';
END IF;
END $$ LANGUAGE plpgsql;
GRANT EXECUTE ON FUNCTION auth.authenticate TO anonymous;


CREATE OR REPLACE FUNCTION api.ulid() RETURNS text LANGUAGE sql STABLE AS $$
SELECT gen_ulid()::TEXT; $$;

NOTIFY pgrst,
'reload schema'