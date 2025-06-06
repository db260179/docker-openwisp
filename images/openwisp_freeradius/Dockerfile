FROM freeradius/freeradius-server:3.2.7-alpine

# hadolint ignore=DL3018
RUN apk add --no-cache --update tzdata~=2024b-r1 \
                                postgresql17-client~=17.5-r0 && \
    rm -rf /var/cache/apk/* /tmp/*

RUN addgroup -S freerad && \
    adduser -S freerad -G freerad

CMD ["sh", "init_command.sh"]
EXPOSE 1812/udp 1813/udp

# hadolint ignore=DL3045
COPY ./common/init_command.sh \
    ./common/utils.sh ./
COPY ./openwisp_freeradius/raddb/ /etc/raddb/
RUN chown -R freerad:root /opt/etc/raddb/ && \
    chown -R freerad:root /opt/var/log/

ENV TZ=UTC \
    MODULE_NAME=freeradius \
    DB_NAME=openwisp_db \
    DB_USER=admin \
    DB_PASS=admin \
    DB_HOST=postgres \
    DB_PORT=5432 \
    DB_SSLMODE=disable \
    DB_SSLKEY=None \
    DB_SSLCERT=None \
    DB_SSLROOTCERT=None \
    DB_OPTIONS={} \
    DASHBOARD_INTERNAL=dashboard.internal \
    API_INTERNAL=api.internal \
    DEBUG_MODE=False
