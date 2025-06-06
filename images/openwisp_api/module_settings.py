INSTALLED_APPS = [
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.gis",
    "django.contrib.humanize",
    # all-auth
    "django.contrib.sites",
    # overrides allauth templates
    # must precede allauth
    "openwisp_users.accounts",
    "allauth",
    "allauth.account",
    "allauth.socialaccount",
    "django_extensions",
    # openwisp modules
    "openwisp_users",
    # openwisp-controller
    "openwisp_controller.pki",
    "openwisp_controller.config",
    "openwisp_controller.geo",
    "openwisp_controller.connection",
    "openwisp_controller.subnet_division",
    # openwisp-monitoring
    "openwisp_monitoring.monitoring",
    "openwisp_monitoring.device",
    "openwisp_monitoring.check",
    "nested_admin",
    # openwisp-notification
    "openwisp_notifications",
    # openwisp-ipam
    "openwisp_ipam",
    # openwisp-network-topology
    "openwisp_network_topology",
    # openwisp-firmware-upgrader
    "openwisp_firmware_upgrader",
    # openwisp radius
    "dj_rest_auth",
    "dj_rest_auth.registration",
    "openwisp_radius",
    # admin
    "openwisp_utils.admin_theme",
    "django.contrib.admin",
    "django.forms",
    # other dependencies
    "sortedm2m",
    "reversion",
    "leaflet",
    # rest framework
    "rest_framework",
    "rest_framework_gis",
    "rest_framework.authtoken",
    "django_filters",
    # social login
    "allauth.socialaccount.providers.facebook",
    "allauth.socialaccount.providers.google",
    # other dependencies
    "flat_json_widget",
    "private_storage",
    "drf_yasg",
    "import_export",
    "admin_auto_filters",
    "channels",
    "corsheaders",
]

EXTENDED_APPS = [
    "django_x509",
    "django_loci",
]

LOGIN_REDIRECT_URL = "account_change_password"
ACCOUNT_LOGOUT_REDIRECT_URL = LOGIN_REDIRECT_URL
