-- --------------------- PG_GRAPQL Flow --------------------------
CREATE EXTENSION IF NOT EXISTS pg_graphql;
CREATE EXTENSION IF NOT EXISTS ulid;

CREATE ROLE anonymous nologin;
CREATE ROLE webuser nologin;
CREATE ROLE authenticator WITH NOINHERIT LOGIN PASSWORD 'vfx4M4$l$Fu4';

GRANT anonymous TO authenticator;
GRANT webuser TO authenticator;

grant usage on schema public to anonymous;
alter default privileges in schema public grant all on tables to anonymous;
alter default privileges in schema public grant all on functions to anonymous;
alter default privileges in schema public grant all on sequences to anonymous;

grant usage on schema public to webuser;
alter default privileges in schema public grant all on tables to webuser;
alter default privileges in schema public grant all on functions to webuser;
alter default privileges in schema public grant all on sequences to webuser;

grant usage on schema graphql to anonymous;
grant all on function graphql.resolve to anonymous;

alter default privileges in schema graphql grant all on tables to anonymous;
alter default privileges in schema graphql grant all on functions to anonymous;
alter default privileges in schema graphql grant all on sequences to anonymous;

-- GraphQL Entrypoint
CREATE OR REPLACE function graphql(
    "operationName" text default null,
    query text default null,
    variables jsonb default null,
    extensions jsonb default null
)
    returns jsonb
    language sql
as $$
    select graphql.resolve(
        query := query,
        variables := coalesce(variables, '{}'),
        "operationName" := "operationName",
        extensions := extensions
    );
$$;

comment on schema public is '@graphql({"inflect_names": true})';

-- --------------------- Authentication Flow --------------------------
ALTER DATABASE cavelms SET "app.jwt_secret" TO 'Q!6HLp@B5wD24Pbq*LNd!%S4&H%ly7bt';

-- add custom extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgjwt;


-- Authentication management schema
CREATE SCHEMA IF NOT EXISTS auth;

-- users table
CREATE TABLE IF NOT EXISTS auth.users (
  email			  TEXT PRIMARY KEY CHECK ( email ~* '^.+@.+\..+$' ),
  password	  TEXT NOT NULL CHECK (LENGTH(password) < 512),
  role			  NAME NOT NULL CHECK (LENGTH(role) < 512)
);


CREATE OR REPLACE FUNCTION auth.check_role_exists() RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles AS r WHERE r.rolname = new.role) THEN
    raise foreign_key_violation USING message =
      'unknown database role: ' || new.role;
    RETURN NULL;
  END IF;
  RETURN new;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS ensure_user_role_exists ON auth.users;
CREATE CONSTRAINT TRIGGER ensure_user_role_exists
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE auth.check_role_exists();

CREATE OR REPLACE FUNCTION
auth.encrypt_password() RETURNS trigger AS $$
BEGIN
  IF tg_op = 'INSERT' OR new.password <> old.password THEN
    new.password = crypt(new.password, gen_salt('bf'));
  END IF;
  RETURN new;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS encrypt_password ON auth.users;
CREATE TRIGGER encrypt_password
  BEFORE INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE auth.encrypt_password();
  
-- add new type
DROP TYPE IF EXISTS auth.jwt_token cascade;
CREATE TYPE auth.jwt_token AS (
  token TEXT,
  exp INTEGER
);

-- login should be on our exposed schema
CREATE OR REPLACE FUNCTION
public.login(email text, password text, expireAt integer DEFAULT 3600) 
RETURNS auth.jwt_token AS $$
DECLARE
  _user auth.users;
  result auth.jwt_token;
BEGIN
  -- Check email and password
  SELECT users.* FROM auth.users
   WHERE users.email = login.email
     AND users.password = crypt(login.password, users.password)
  INTO _user;

  IF NOT FOUND THEN
    raise invalid_password USING message = 'invalid user or password';
  END IF;

  -- Generate a JWT token
  SELECT 
    sign(
      row_to_json(r), current_setting('app.jwt_secret')
    ) AS token, 
    extract(epoch FROM now())::INTEGER + login.expireAt AS exp
  INTO result
  FROM (
    SELECT _user.role AS role, login.email AS email
  ) r;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION
public.signup(email text, password text) RETURNS jsonb AS $$
DECLARE
    response jsonb;
    inserted_count integer;
BEGIN
  INSERT INTO auth.users (email, password, role) 
  VALUES (signup.email, signup.password, 'webuser');
  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  IF inserted_count > 0 THEN
    response = '{"success": true}'::jsonb;
  ELSE
    response = '{"success": false}'::jsonb;
  END IF;
  RETURN response;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


GRANT EXECUTE ON FUNCTION public.login(text,text,integer) TO anonymous;
GRANT EXECUTE ON FUNCTION public.signup(text,text) TO anonymous;

NOTIFY pgrst, 'reload schema'