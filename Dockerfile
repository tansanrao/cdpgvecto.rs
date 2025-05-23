ARG ALPINE_VERSION=3.19.0
ARG CRUNCHYDATA_VERSION
ARG PG_MAJOR

FROM alpine:${ALPINE_VERSION} as builder

RUN apk add --no-cache curl alien rpm binutils xz

WORKDIR /tmp

ARG PG_MAJOR
ARG TARGETARCH
# renovate: datasource=github-releases depName=tensorchord/pgvecto.rs
ARG PGVECTORS_TAG=v0.3.0
RUN curl -fSL -o pgvectors.deb \
      https://github.com/tensorchord/pgvecto.rs/releases/download/${PGVECTORS_TAG}/vectors-pg${PG_MAJOR}_${PGVECTORS_TAG:1}_${TARGETARCH}.deb \
    && ar x pgvectors.deb \
    && tar -xJf data.tar.xz \
    && rm pgvectors.deb control.tar.* data.tar.*
# renovate: datasource=github-releases depName=tensorchord/vectorchord
ARG VECTORCHORD_TAG=0.3.0
RUN curl -fSL -o vchord.deb \
      https://github.com/tensorchord/VectorChord/releases/download/${VECTORCHORD_TAG}/postgresql-${PG_MAJOR}-vchord_${VECTORCHORD_TAG}-1_${TARGETARCH}.deb \
    && ar x vchord.deb \
    && tar -xJf data.tar.xz \
    && rm vchord.deb control.tar.* data.tar.*

RUN rpm2cpio /tmp/*.rpm | cpio -idmv

ARG CRUNCHYDATA_VERSION
FROM registry.developers.crunchydata.com/crunchydata/crunchy-postgres:${CRUNCHYDATA_VERSION}

ARG PG_MAJOR


# copy pgvecto.rs
COPY --chown=root:root --chmod=755 \
     --from=builder /tmp/usr/lib/postgresql/${PG_MAJOR}/lib/vectors.so \
     /usr/pgsql-${PG_MAJOR}/lib/
COPY --chown=root:root --chmod=755 \
     --from=builder /tmp/usr/share/postgresql/${PG_MAJOR}/extension/vectors* \
     /usr/pgsql-${PG_MAJOR}/share/extension/

# copy VectorChord
COPY --chown=root:root --chmod=755 \
     --from=builder /tmp/usr/lib/postgresql/${PG_MAJOR}/lib/vchord.so \
     /usr/pgsql-${PG_MAJOR}/lib/
COPY --chown=root:root --chmod=755 \
     --from=builder /tmp/usr/share/postgresql/${PG_MAJOR}/extension/vchord* \
     /usr/pgsql-${PG_MAJOR}/share/extension/

# Numeric User ID for Default Postgres User
USER 26

COPY app/pgvectors.sql /docker-entrypoint-initdb.d/
COPY app/vchord.sql /docker-entrypoint-initdb.d/
