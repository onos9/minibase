################################################################
FROM postgres:15
RUN apt update
RUN apt install -y --no-install-recommends ca-certificates wget

WORKDIR /app

RUN wget https://github.com/supabase/pg_graphql/releases/download/v1.3.0/pg_graphql-v1.3.0-pg15-amd64-linux-gnu.deb
RUN wget https://github.com/pksunkara/pgx_ulid/releases/download/v0.1.1/pgx_ulid-v0.1.1-pg15-amd64-linux-gnu.deb

RUN dpkg -i pg_graphql-v1.3.0-pg15-amd64-linux-gnu.deb
RUN dpkg -i pgx_ulid-v0.1.1-pg15-amd64-linux-gnu.deb

COPY ./extension /tmp/extension
RUN mv /tmp/extension/* /usr/share/postgresql/15/extension/ && \
    rm -rf /tmp/extension

COPY ./scripts/init.sql /docker-entrypoint-initdb.d/init01.sql
USER postgres

CMD [ "postgres", "-c", "wal_level=logical", "-c", "shared_preload_libraries=pg_stat_statements" ]