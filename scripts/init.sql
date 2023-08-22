-- --------------------- PG_GRAPQL Flow --------------------------
CREATE EXTENSION IF NOT EXISTS pg_graphql;
CREATE EXTENSION IF NOT EXISTS ulid;

CREATE ROLE anonymous NOLOGIN;

CREATE SCHEMA api;
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

comment on schema public is '@graphql({"inflect_names": true})';

CREATE OR REPLACE FUNCTION api.ulid() RETURNS text LANGUAGE sql STABLE AS $$
SELECT gen_ulid()::TEXT; $$;

NOTIFY pgrst,
'reload schema'