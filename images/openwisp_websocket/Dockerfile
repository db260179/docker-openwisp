# hadolint ignore=DL3007
FROM openwisp-base:latest

WORKDIR /opt/openwisp/

COPY --chown=openwisp:root  ./common/ \
    /opt/openwisp/
COPY --chown=openwisp:root  ./openwisp_websocket/module_settings.py \
    ./openwisp_websocket/urls.py ./openwisp_websocket/start_websocket \
    /opt/openwisp/openwisp/

ARG WEBSOCKET_APP_PORT=8002
ENV MODULE_NAME=websocket \
    DJANGO_WEBSOCKET_HOST=0.0.0.0 \
    CONTAINER_PORT=$WEBSOCKET_APP_PORT

EXPOSE $WEBSOCKET_APP_PORT
CMD ["bash", "init_command.sh"]
