#!/bin/sh
# OpenWISP common module init script
set -e
source utils.sh

GOSU_CELERY="gosu openwisp"

SUPERVISOR_DIR=/etc/supervisor/conf.d
BASE_SUPERVISOR_CONF=/etc/supervisor/supervisord.conf
rm -rf "$SUPERVISOR_DIR"/*
mkdir -p "$SUPERVISOR_DIR"

init_conf

# Helper: Create Supervisor .conf program file
create_program_conf() {
    name="$1"
    shift
    cat > "$SUPERVISOR_DIR/$name.conf" <<EOF
[program:$name]
command=$@
autorestart=true
stdout_logfile=/proc/self/fd/1
stderr_logfile=/proc/self/fd/1
# Set logfile maxbytes to 0 to
# avoid invalid seek error
stdout_logfile_maxbytes=0
stderr_logfile_maxbytes=0
EOF
}

case "$MODULE_NAME" in
    dashboard)
        if [ "$OPENWISP_GEOCODING_CHECK" = 'True' ]; then
           $GOSU_CELERY python manage.py check --deploy --tag geocoding
        fi
        $GOSU_CELERY python services.py database redis
        $GOSU_CELERY python manage.py migrate --noinput
        test -f "$SSH_PRIVATE_KEY_PATH" || ssh-keygen -t ed25519 -f "$SSH_PRIVATE_KEY_PATH" -N ""
        $GOSU_CELERY python load_init_data.py
        $GOSU_CELERY python collectstatic.py
        create_program_conf "uwsgi" $GOSU_CELERY /opt/openwisp/start_uwsgi
        ;;

    postfix)
        postfix_config
        create_program_conf "postfix" /opt/openwisp/start_postfix
        ;;

    freeradius)
        wait_nginx_services
        if [ "$DEBUG_MODE" = 'False' ]; then
            create_program_conf "freeradius" "sh -c 'source docker-entrypoint.sh'"
        else
            create_program_conf "freeradius" "sh -c 'source docker-entrypoint.sh -X'"
        fi
        ;;

    openvpn)
        [ -z "$VPN_DOMAIN" ] && exit
        wait_nginx_services
        openvpn_preconfig
        openvpn_config
        openvpn_config_download
        crl_download
        echo "*/1 * * * * sh /openvpn.sh" | crontab -
        ( crontab -l; echo "0 0 * * * sh /revokelist.sh" ) | crontab -
        crond
        [ "$USE_OPENWISP_TOPOLOGY" = "True" ] && init_send_network_topology

        create_program_conf "openvpn" "/start_openvpn.sh"
        ;;

    nginx)
        rm -rf /etc/nginx/conf.d/default.conf
        if [ "$NGINX_CUSTOM_FILE" = 'True' ]; then
            create_program_conf "nginx" "nginx -g 'daemon off;'"
        else
            envsubst </etc/nginx/nginx.template.conf >/etc/nginx/nginx.conf
            envsubst_create_config /etc/nginx/openwisp.internal.template.conf internal INTERNAL
            if [ "$SSL_CERT_MODE" = 'Yes' ]; then
                nginx_prod
            elif [ "$SSL_CERT_MODE" = 'SelfSigned' ]; then
                nginx_dev
            else
                envsubst_create_config /etc/nginx/openwisp.template.conf http DOMAIN
            fi
            create_program_conf "nginx" "nginx -g 'daemon off;'"
        fi
        ;;

    celery)
        $GOSU_CELERY python services.py database redis dashboard
        create_program_conf "celery_default" $GOSU_CELERY celery -A openwisp worker -l ${DJANGO_LOG_LEVEL} --queues celery \
            -n celery@%%h --pidfile /opt/openwisp/celery.pid ${OPENWISP_CELERY_COMMAND_FLAGS}

        if [ "$USE_OPENWISP_CELERY_NETWORK" = "True" ]; then
            create_program_conf "celery_network" $GOSU_CELERY celery -A openwisp worker -l ${DJANGO_LOG_LEVEL} --queues network \
                -n network@%%h --pidfile /opt/openwisp/celery_network.pid ${OPENWISP_CELERY_NETWORK_COMMAND_FLAGS}
        fi

        if [ "$USE_OPENWISP_FIRMWARE" = "True" ] && [ "$USE_OPENWISP_CELERY_FIRMWARE" = "True" ]; then
            create_program_conf "celery_firmware_upgrader" $GOSU_CELERY celery -A openwisp worker -l ${DJANGO_LOG_LEVEL} --queues firmware_upgrader \
                -n firmware_upgrader@%%h --pidfile /opt/openwisp/celery_firmware_upgrader.pid ${OPENWISP_CELERY_FIRMWARE_COMMAND_FLAGS}
        fi
        ;;

    celery_monitoring)
        $GOSU_CELERY python services.py database redis dashboard
        if [ "$USE_OPENWISP_MONITORING" = "True" ] && [ "$USE_OPENWISP_CELERY_MONITORING" = 'True' ]; then
            create_program_conf "celery_monitoring" $GOSU_CELERY celery -A openwisp worker -l ${DJANGO_LOG_LEVEL} --queues monitoring \
                -n monitoring@%%h --pidfile /opt/openwisp/celery_monitoring.pid ${OPENWISP_CELERY_MONITORING_COMMAND_FLAGS}
            create_program_conf "celery_monitoring_checks" $GOSU_CELERY celery -A openwisp worker -l ${DJANGO_LOG_LEVEL} --queues monitoring_checks \
                -n monitoring_checks@%%h --pidfile /opt/openwisp/celery_monitoring_checks.pid ${OPENWISP_CELERY_MONITORING_CHECKS_COMMAND_FLAGS}
        else
            echo "Monitoring queues are not activated, exiting."
            exit 0
        fi
        ;;

    celerybeat)
        rm -rf celerybeat.pid
        $GOSU_CELERY python services.py database redis dashboard
        create_program_conf "celerybeat" $GOSU_CELERY celery -A openwisp beat -l ${DJANGO_LOG_LEVEL}
        ;;

    websocket)
        create_program_conf "websocket" $GOSU_CELERY /opt/openwisp/openwisp/start_websocket
        ;;

    *)
        $GOSU_CELERY python services.py database redis dashboard
        create_program_conf "uwsgi" $GOSU_CELERY /opt/openwisp/start_uwsgi
        ;;
esac

# Replace env vars in all generated conf files
for conf in "$SUPERVISOR_DIR"/*.conf; do
    envsubst < "$conf" > "${conf}.tmp" && mv "${conf}.tmp" "$conf"
done

# Start Supervisor
exec supervisord --nodaemon --configuration "$BASE_SUPERVISOR_CONF"
