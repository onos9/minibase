FROM postgres:15
RUN apt-get update
RUN apt-get install -y --no-install-recommends ca-certificates wget

WORKDIR /home/pg_graphql

RUN wget https://github.com/supabase/pg_graphql/releases/download/v1.3.0/pg_graphql-v1.3.0-pg15-amd64-linux-gnu.deb
RUN wget https://github.com/pksunkara/pgx_ulid/releases/download/v0.1.1/pgx_ulid-v0.1.1-pg15-amd64-linux-gnu.deb

RUN dpkg -i pg_graphql-v1.3.0-pg15-amd64-linux-gnu.deb
RUN dpkg -i pgx_ulid-v0.1.1-pg15-amd64-linux-gnu.deb

COPY ./extension /tmp/extension
RUN mv /tmp/extension/* /usr/share/postgresql/15/extension/ && \
    rm -rf /tmp/extension

USER postgres

CMD [ "postgres", "-c", "wal_level=logical", "-c", "shared_preload_libraries=pg_stat_statements" ]