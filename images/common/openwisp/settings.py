import json
import logging
import os
import sys
from urllib.parse import quote

import tldextract
from openwisp.utils import (
    env_bool,
    is_string_env_bool,
    is_string_env_json,
    request_scheme,
)

# Read all the env variables and set them as django configuration.
for config in os.environ:
    if "OPENWISP_" in config:
        value = os.environ[config]
        if value.isdigit():
            globals()[config] = int(value)
        elif is_string_env_bool(value):
            globals()[config] = env_bool(value)
        elif value == "None":
            globals()[config] = None
        elif is_string_env_json(value):
            globals()[config] = json.loads(value)
        else:
            globals()[config] = value

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = env_bool(os.environ["DEBUG_MODE"])
MAX_REQUEST_SIZE = int(os.environ["NGINX_CLIENT_BODY_SIZE"]) * 1024 * 1024
ROOT_DOMAIN = "." + tldextract.extract(os.environ["DASHBOARD_DOMAIN"]).registered_domain
INSTALLED_APPS = []

if "DJANGO_ALLOWED_HOSTS" not in os.environ:
    os.environ["DJANGO_ALLOWED_HOSTS"] = ROOT_DOMAIN

ALLOWED_HOSTS = [
    "localhost",
    os.environ["DASHBOARD_APP_SERVICE"],
    os.environ["DASHBOARD_INTERNAL"],
    os.environ["API_INTERNAL"],
] + os.environ["DJANGO_ALLOWED_HOSTS"].split(",")

AUTH_USER_MODEL = "openwisp_users.User"
SITE_ID = 1
LOGIN_REDIRECT_URL = "admin:index"
ACCOUNT_LOGOUT_REDIRECT_URL = LOGIN_REDIRECT_URL
ROOT_URLCONF = "openwisp.urls"
HTTP_SCHEME = request_scheme()

# CORS
CORS_ALLOWED_ORIGINS = [
    f'{HTTP_SCHEME}://{os.environ["DASHBOARD_DOMAIN"]}',
    f'{HTTP_SCHEME}://{os.environ["API_DOMAIN"]}',
] + os.environ["DJANGO_CORS_HOSTS"].split(",")
CORS_ALLOW_CREDENTIALS = True

if HTTP_SCHEME == "https":
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
if HTTP_SCHEME == "http":
    DJANGO_LOCI_GEOCODE_STRICT_TEST = False

STATICFILES_FINDERS = [
    "django.contrib.staticfiles.finders.FileSystemFinder",
    "django.contrib.staticfiles.finders.AppDirectoriesFinder",
    "openwisp_utils.staticfiles.DependencyFinder",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "allauth.account.middleware.AccountMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

AUTHENTICATION_BACKENDS = [
    "openwisp_users.backends.UsersAuthenticationBackend",
]

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [os.path.join(BASE_DIR, "templates")],
        "OPTIONS": {
            "loaders": [
                (
                    "django.template.loaders.cached.Loader",
                    [
                        "django.template.loaders.filesystem.Loader",
                        "django.template.loaders.app_directories.Loader",
                        "openwisp_utils.loaders.DependencyLoader",
                    ],
                ),
            ],
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

if DEBUG:
    TEMPLATES[0]["OPTIONS"]["context_processors"].insert(
        0, "django.template.context_processors.debug"
    )

if os.environ["MODULE_NAME"] == "dashboard":
    TEMPLATES[0]["OPTIONS"]["context_processors"].extend(
        [
            "openwisp_utils.admin_theme.context_processor.menu_groups",
            "openwisp_utils.admin_theme.context_processor.admin_theme_settings",
            "openwisp_notifications.context_processors.notification_api_settings",
        ]
    )

FORM_RENDERER = "django.forms.renderers.TemplatesSetting"

SESSION_ENGINE = "django.contrib.sessions.backends.cache"
SESSION_CACHE_ALIAS = "default"
SESSION_COOKIE_DOMAIN = ROOT_DOMAIN

# Required for API request from Django admin
CSRF_COOKIE_DOMAIN = ROOT_DOMAIN
CSRF_TRUSTED_ORIGINS = CORS_ALLOWED_ORIGINS

WSGI_APPLICATION = "openwisp.wsgi.application"
ASGI_APPLICATION = "openwisp.asgi.application"

REDIS_HOST = os.environ["REDIS_HOST"]
REDIS_PORT = os.environ.get("REDIS_PORT", 6379)
REDIS_USER = os.environ.get("REDIS_USER")
REDIS_PASS = os.environ.get("REDIS_PASS")
REDIS_SCHEME = (
    "rediss" if env_bool(os.environ.get("REDIS_USE_TLS", "False")) else "redis"
)

# Build base Redis URL

if REDIS_USER and REDIS_PASS:
    credentials = f"{quote(REDIS_USER)}:{quote(REDIS_PASS)}@"
elif REDIS_PASS:
    # Password only
    credentials = f":{quote(REDIS_PASS)}@"
else:
    credentials = ""
REDIS_BASE_URL = f"{REDIS_SCHEME}://{credentials}{REDIS_HOST}:{REDIS_PORT}"

REDIS_CACHE_URL = os.environ.get("REDIS_CACHE_URL", f"{REDIS_BASE_URL}/0")
CHANNEL_REDIS_HOST = os.environ.get("CHANNEL_REDIS_URL", f"{REDIS_BASE_URL}/1")
CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", f"{REDIS_BASE_URL}/2")

CELERY_TASK_ACKS_LATE = True
CELERY_WORKER_PREFETCH_MULTIPLIER = 1
CELERY_BROKER_TRANSPORT_OPTIONS = {"max_retries": 10}
if env_bool(os.environ.get("REDIS_USE_TLS", "False")):
    import ssl

    CELERY_BROKER_USE_SSL = {
        "ssl_cert_reqs": ssl.CERT_REQUIRED,
    }

# Database
# https://docs.djangoproject.com/en/1.9/ref/settings/#databases

DB_OPTIONS = {
    "sslmode": os.environ["DB_SSLMODE"],
    "sslkey": os.environ["DB_SSLKEY"],
    "sslcert": os.environ["DB_SSLCERT"],
    "sslrootcert": os.environ["DB_SSLROOTCERT"],
}
DB_OPTIONS.update(json.loads(os.environ["DB_OPTIONS"]))

DATABASES = {
    "default": {
        "ENGINE": os.environ["DB_ENGINE"],
        "NAME": os.environ["DB_NAME"],
        "USER": os.environ["DB_USER"],
        "PASSWORD": os.environ["DB_PASS"],
        "HOST": os.environ["DB_HOST"],
        "PORT": os.environ["DB_PORT"],
        "OPTIONS": DB_OPTIONS,
    },
}

TIMESERIES_DATABASE = {
    "BACKEND": "openwisp_monitoring.db.backends.influxdb",
    "USER": os.environ["INFLUXDB_USER"],
    "PASSWORD": os.environ["INFLUXDB_PASS"],
    "NAME": os.environ["INFLUXDB_NAME"],
    "HOST": os.environ["INFLUXDB_HOST"],
    "PORT": os.environ["INFLUXDB_PORT"],
}
OPENWISP_MONITORING_DEFAULT_RETENTION_POLICY = os.environ[
    "INFLUXDB_DEFAULT_RETENTION_POLICY"
]

# Channels(Websocket)
# https://channels.readthedocs.io/en/latest/topics/channel_layers.html#configuration
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [CHANNEL_REDIS_HOST]},
    },
}

# Cache
# https://docs.djangoproject.com/en/2.2/ref/settings/#caches

CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": REDIS_CACHE_URL,
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
        },
    }
}

if REDIS_PASS:
    CACHES["default"]["OPTIONS"]["PASSWORD"] = os.environ["REDIS_PASS"]

# Leaflet Configurations
# https://django-leaflet.readthedocs.io/en/latest/templates.html#configuration

LEAFLET_CONFIG = {
    "DEFAULT_CENTER": [
        int(os.environ["DJANGO_LEAFET_CENTER_X_AXIS"]),
        int(os.environ["DJANGO_LEAFET_CENTER_Y_AXIS"]),
    ],
    "RESET_VIEW": False,
    "DEFAULT_ZOOM": int(os.environ["DJANGO_LEAFET_ZOOM"]),
}

# Password validation
# https://docs.djangoproject.com/en/1.9/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": (
            "django.contrib.auth.password_validation."
            "UserAttributeSimilarityValidator"
        )
    },
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# Internationalization
# https://docs.djangoproject.com/en/1.9/topics/i18n/

LANGUAGE_CODE = os.environ["DJANGO_LANGUAGE_CODE"]
TIME_ZONE = os.environ["TZ"]
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/1.9/howto/static-files/

STATIC_ROOT = os.path.join(BASE_DIR, "static")
MEDIA_ROOT = os.path.join(BASE_DIR, "media")
# PRIVATE_STORAGE_ROOT path should be similar to ansible-openwisp2
PRIVATE_STORAGE_ROOT = os.path.join(BASE_DIR, "private")
STATIC_URL = "/static/"
MEDIA_URL = "/media/"

# Email Configurations

DEFAULT_FROM_EMAIL = os.environ["EMAIL_DJANGO_DEFAULT"]
EMAIL_BACKEND = os.environ["EMAIL_BACKEND"]
EMAIL_HOST = os.environ["EMAIL_HOST"]
EMAIL_PORT = os.environ["EMAIL_HOST_PORT"]
EMAIL_HOST_USER = os.environ["EMAIL_HOST_USER"]
EMAIL_HOST_PASSWORD = os.environ["EMAIL_HOST_PASSWORD"]
EMAIL_USE_TLS = env_bool(os.environ["EMAIL_HOST_TLS"])
EMAIL_TIMEOUT = int(os.environ["EMAIL_TIMEOUT"])

# Logging
# http://docs.djangoproject.com/en/dev/topics/logging

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {
        "user_filter": {
            "()": "openwisp.utils.HostFilter",
        },
        "require_debug_false": {
            "()": "django.utils.log.RequireDebugFalse",
        },
    },
    "formatters": {
        "verbose": {
            "format": (
                "\n[%(host)s] - %(levelname)s, time: [%(asctime)s],"
                "process: %(process)d, thread: %(thread)d\n%(message)s"
            )
        },
    },
    "handlers": {
        "console": {
            "level": os.environ["DJANGO_LOG_LEVEL"],
            "class": "logging.StreamHandler",
            "filters": ["user_filter"],
            "formatter": "verbose",
            "stream": sys.stdout,
        },
        "mail_admins": {
            "level": os.environ["DJANGO_LOG_LEVEL"],
            "class": "django.utils.log.AdminEmailHandler",
            "filters": ["require_debug_false", "user_filter"],
        },
        "null": {
            "level": os.environ["DJANGO_LOG_LEVEL"],
            "class": "logging.NullHandler",
            "filters": ["user_filter"],
            "formatter": "verbose",
        },
    },
    "root": {
        "level": os.environ["DJANGO_LOG_LEVEL"],
        "handlers": [
            "console",
            "mail_admins",
        ],
    },
    "loggers": {
        "pre_django_setup": {
            "level": os.environ["DJANGO_LOG_LEVEL"],
            "handlers": ["console"],
            "propagate": False,
        }
    },
}

# Sentry
# https://sentry.io/for/django/

if os.environ["DJANGO_SENTRY_DSN"]:
    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration

    sentry_sdk.init(
        dsn=os.environ["DJANGO_SENTRY_DSN"], integrations=[DjangoIntegration()]
    )

# OpenWISP Modules's configurations
OPENWISP_FIRMWARE_UPGRADER_MAX_FILE_SIZE = MAX_REQUEST_SIZE
DJANGO_X509_DEFAULT_CERT_VALIDITY = int(os.environ["DJANGO_X509_DEFAULT_CERT_VALIDITY"])
DJANGO_X509_DEFAULT_CA_VALIDITY = int(os.environ["DJANGO_X509_DEFAULT_CA_VALIDITY"])
SOCIALACCOUNT_PROVIDERS = {
    "facebook": {
        "METHOD": "oauth2",
        "SCOPE": ["email", "public_profile"],
        "AUTH_PARAMS": {"auth_type": "reauthenticate"},
        "INIT_PARAMS": {"cookie": True},
        "FIELDS": ["id", "email", "name", "first_name", "last_name", "verified"],
        "VERIFIED_EMAIL": True,
    },
    "google": {
        "SCOPE": ["profile", "email"],
        "AUTH_PARAMS": {"access_type": "online"},
    },
}

TEST_RUNNER = "openwisp_utils.metric_collection.tests.runner.MockRequestPostRunner"

# Add Custom OpenWrt Images for openwisp firmware
try:
    OPENWRT_IMAGES = json.loads(os.environ["OPENWISP_CUSTOM_OPENWRT_IMAGES"])
except (json.decoder.JSONDecodeError, TypeError):
    OPENWISP_CUSTOM_OPENWRT_IMAGES = None
    # Key is defined but it's not a proper JSON, probably user
    # needs to read the docs, so let's inform them.
    logging.warning(
        'Could not load "OPENWISP_CUSTOM_OPENWRT_IMAGES" please read '
        "the docs to configure it properly, continuing without it."
    )
except KeyError:
    # Key is not defined, that's okay, default is None.
    pass
else:
    OPENWISP_CUSTOM_OPENWRT_IMAGES = list()
    for image in OPENWRT_IMAGES:
        OPENWISP_CUSTOM_OPENWRT_IMAGES += (
            (
                image["name"],
                {"label": image["label"], "boards": tuple(image["boards"])},
            ),
        )

try:
    from openwisp.module_settings import *  # noqa: F401, F403
except ImportError:
    pass

if env_bool(os.environ["USE_OPENWISP_RADIUS"]):
    REST_AUTH = {
        "SESSION_LOGIN": False,
        "PASSWORD_RESET_SERIALIZER": (
            "openwisp_radius.api.serializers.PasswordResetSerializer"
        ),
        "REGISTER_SERIALIZER": "openwisp_radius.api.serializers.RegisterSerializer",
    }
    OPENWISP_RADIUS_FREERADIUS_ALLOWED_HOSTS = os.environ[
        "OPENWISP_RADIUS_FREERADIUS_ALLOWED_HOSTS"
    ].split(",")
elif "openwisp_radius" in INSTALLED_APPS:
    INSTALLED_APPS.remove("openwisp_radius")

if (
    not env_bool(os.environ["USE_OPENWISP_TOPOLOGY"])
    and "openwisp_network_topology" in INSTALLED_APPS
):
    INSTALLED_APPS.remove("openwisp_network_topology")
if (
    not env_bool(os.environ["USE_OPENWISP_FIRMWARE"])
    and "openwisp_firmware_upgrader" in INSTALLED_APPS
):
    INSTALLED_APPS.remove("openwisp_firmware_upgrader")
if not env_bool(os.environ["USE_OPENWISP_MONITORING"]):
    if "openwisp_monitoring.monitoring" in INSTALLED_APPS:
        INSTALLED_APPS.remove("openwisp_monitoring.monitoring")
    if "openwisp_monitoring.device" in INSTALLED_APPS:
        INSTALLED_APPS.remove("openwisp_monitoring.device")
    if "openwisp_monitoring.check" in INSTALLED_APPS:
        INSTALLED_APPS.remove("openwisp_monitoring.check")
if EMAIL_BACKEND == "djcelery_email.backends.CeleryEmailBackend":
    INSTALLED_APPS.append("djcelery_email")
if env_bool(os.environ.get("METRIC_COLLECTION", "True")):
    INSTALLED_APPS.append("openwisp_utils.metric_collection")

try:
    from .configuration.custom_django_settings import *  # noqa: F403, F401
except ImportError:
    pass
