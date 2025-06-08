#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export BASE_PATH=$HOME/openwisp
export INSTALL_PATH=$HOME/openwisp/docker-openwisp
export LOG_FILE=$HOME/autoinstall.log
export ENV_USER=$HOME/config.env
export ENV_BACKUP=$HOME/backup.env
export GIT_PATH=${GIT_PATH:-https://github.com/db260179/docker-openwisp.git}

# Terminal colors
export RED='\033[1;31m'
export GRN='\033[1;32m'
export YLW='\033[1;33m'
export BLU='\033[1;34m'
export NON='\033[0m'

start_step() { printf '\e[1;34m%-70s\e[m' "$1" && echo "$1" &>>$LOG_FILE; }
report_ok() { echo -e ${GRN}" done"${NON}; }
report_error() { echo -e ${RED}" error"${NON}; }
get_env() { grep "^$1" "$2" | cut -d'=' -f 2-50; }
set_env() {
	line=$(grep -n "^$1=" $INSTALL_PATH/.env)
	if [ -z "$line" ]; then
		echo "$1=$2" >>$INSTALL_PATH/.env
	else
		line_number=$(echo $line | cut -f1 -d:)
		eval $(echo "awk -i inplace 'NR=="${line_number}" {\$0=\"${1}=${2}\"}1' $INSTALL_PATH/.env")
	fi
}

check_status() {
	if [ $1 -eq 0 ]; then
		report_ok
	else
		error_msg "$2"
	fi
}

error_msg() {
	report_error
	echo -e ${RED}${1}${NON}
	echo -e ${RED}"Check logs at $LOG_FILE"${NON}
	exit 1
}

error_msg_with_continue() {
	report_error
	echo -ne ${RED}${1}${NON}
	read reply
	if [[ ! $reply =~ ^[Yy]$ ]]; then
		exit 1
	fi
}

apt_dependenices_setup() {
	start_step "Setting up dependencies (APT)..."
	sudo apt --yes install python3 python3-pip git python3-dev gawk libffi-dev libssl-dev gcc make curl jq &>>$LOG_FILE
	check_status $? "Python dependencies installation failed (APT)."
}

# New function for DNF dependencies
dnf_dependenices_setup() {
	start_step "Setting up dependencies (DNF)..."
	# Update system and install EPEL (Extra Packages for Enterprise Linux) for some packages
	sudo dnf --assumeyes install epel-release &>>$LOG_FILE
	sudo dnf --assumeyes install python3 python3-pip git python3-devel gawk libffi-devel openssl-devel gcc make curl jq &>>$LOG_FILE
	check_status $? "Python dependencies installation failed (DNF)."
}

get_version_from_user() {
	echo -ne ${GRN}"OpenWISP Version (leave blank for latest): "${NON}
	read openwisp_version
	if [[ -z "$openwisp_version" ]]; then
		openwisp_version=$(curl -L --silent https://api.github.com/repos/openwisp/docker-openwisp/releases/latest | jq -r .tag_name)
	fi
}

setup_docker() {
	start_step "Setting up docker..."
	docker info &>/dev/null
	if [ $? -eq 0 ]; then
		report_ok
	else
		curl -fsSL 'https://get.docker.com' -o "$BASE_PATH/get-docker.sh" &>>$LOG_FILE
		sh "$BASE_PATH/get-docker.sh" &>>$LOG_FILE
		docker info &>/dev/null
		check_status $? "Docker installation failed."
	fi
}

download_docker_openwisp() {
	local openwisp_version="$1"
	start_step "Downloading docker-openwisp..."
	if [[ -f $INSTALL_PATH/.env ]]; then
		mv $INSTALL_PATH/.env $ENV_BACKUP &>>$LOG_FILE
		rm -rf $INSTALL_PATH &>>$LOG_FILE
	fi
	if [ -z "$GIT_BRANCH" ]; then
		if [[ "$openwisp_version" == "edge" ]]; then
			GIT_BRANCH="master"
		else
			GIT_BRANCH="$openwisp_version"
		fi
	fi

	git clone $GIT_PATH $INSTALL_PATH --depth 1 --branch $GIT_BRANCH &>>$LOG_FILE
}

setup_docker_openwisp() {
	echo -e ${GRN}"\nOpenWISP Configuration:"${NON}
	get_version_from_user
	echo -ne ${GRN}"Do you have .env file? Enter filepath (leave blank for ad-hoc configuration): "${NON}
	read env_path
	if [[ ! -f "$env_path" ]]; then
		# Dashboard Domain
		echo -ne ${GRN}"(1/5) Enter dashboard domain: "${NON}
		read dashboard_domain
		domain=$(echo "$dashboard_domain" | cut -f2- -d'.')
		# API Domain
		echo -ne ${GRN}"(2/5) Enter API domain (blank for api.${domain}): "${NON}
		read api_domain
		# VPN domain
		echo -ne ${GRN}"(3/5) Enter OpenVPN domain (blank for vpn.${domain}, N to disable module): "${NON}
		read vpn_domain
		# Server domain
		echo -ne ${GRN}"(4/5) Enter Server domain (blank for server.${domain}): "${NON}
		read server_domain
		# Site manager email
		echo -ne ${GRN}"(5/6) Site manager email: "${NON}
		read django_default_email
		# SSL Configuration
		echo -ne ${GRN}"(6/6) Enter letsencrypt email (leave blank for self-signed certificate): "${NON}
		read letsencrypt_email

		# Ask for Cloudflare API Token only if Let's Encrypt is enabled
		if [[ -n "$letsencrypt_email" ]]; then
			echo -ne ${GRN}"Enter Cloudflare API token (optional, required for DNS challenge): "${NON}
			read cloudflare_api_token
		fi
	else
		cp $env_path $ENV_USER &>>$LOG_FILE
	fi
	echo ""

	download_docker_openwisp "$openwisp_version"

	cd $INSTALL_PATH &>>$LOG_FILE
	check_status $? "docker-openwisp download failed."
	echo $openwisp_version >$INSTALL_PATH/VERSION

	if [[ ! -f "$env_path" ]]; then
		# Dashboard Domain
		set_env "DASHBOARD_DOMAIN" "$dashboard_domain"
		# API Domain
		if [[ -z "$api_domain" ]]; then
			set_env "API_DOMAIN" "api.${domain}"
		else
			set_env "API_DOMAIN" "$api_domain"
		fi
		# Use Radius
		if [[ -z "$USE_OPENWISP_RADIUS" ]]; then
			set_env "USE_OPENWISP_RADIUS" "Yes"
		else
			set_env "USE_OPENWISP_RADIUS" "No"
		fi
		# VPN domain
		if [[ -z "$vpn_domain" ]]; then
			set_env "VPN_DOMAIN" "vpn.${domain}"
		elif [[ "${vpn_domain,,}" == "n" ]]; then
			set_env "VPN_DOMAIN" "example.com"
		else
			set_env "VPN_DOMAIN" "$vpn_domain"
		fi
		# Server Domain
		if [[ -z "$server_domain" ]]; then
			set_env "SERVER_DOMAIN" "server.${domain}"
		else
			set_env "SERVER_DOMAIN" "$server_domain"
		fi
		# Site manager email
		set_env "EMAIL_DJANGO_DEFAULT" "$django_default_email"
		# Set random secret values
		python3 $INSTALL_PATH/build.py change-secret-key >/dev/null
		python3 $INSTALL_PATH/build.py change-database-credentials >/dev/null
		# SSL Configuration
		set_env "CERT_ADMIN_EMAIL" "$letsencrypt_email"
		if [[ -z "$letsencrypt_email" ]]; then
			set_env "SSL_CERT_MODE" "SelfSigned"
		else
			set_env "SSL_CERT_MODE" "Yes"
		fi
		# Set Cloudflare token if provided
		if [[ -n "$cloudflare_api_token" ]]; then
			set_env "CLOUDFLARE_API_TOKEN" "$cloudflare_api_token"
		fi
		# Other
		hostname=$(echo "$django_default_email" | cut -d @ -f 2)
		set_env "POSTFIX_ALLOWED_SENDER_DOMAINS" "$hostname"
		set_env "POSTFIX_MYHOSTNAME" "$hostname"
	else
		mv $ENV_USER $INSTALL_PATH/.env &>>$LOG_FILE
		rm -rf $ENV_USER &>>$LOG_FILE
	fi

	start_step "Configuring docker-openwisp..."
	report_ok
	start_step "Starting images docker-openwisp (this will take a while)..."
	make start TAG=$(cat $INSTALL_PATH/VERSION) -C $INSTALL_PATH/ &>>$LOG_FILE
	check_status $? "Starting openwisp failed."
}

upgrade_docker_openwisp() {
	echo -e ${GRN}"\nOpenWISP Configuration:"${NON}
	get_version_from_user
	echo ""

	download_docker_openwisp "$openwisp_version"

	cd $INSTALL_PATH &>>$LOG_FILE
	check_status $? "docker-openwisp download failed."
	echo $openwisp_version >$INSTALL_PATH/VERSION

	start_step "Configuring docker-openwisp..."
	for config in $(grep '=' $ENV_BACKUP | cut -f1 -d'='); do
		value=$(get_env "$config" "$ENV_BACKUP")
		set_env "$config" "$value"
	done
	report_ok

	start_step "Starting images docker-openwisp (this will take a while)..."
	make start TAG=$(cat $INSTALL_PATH/VERSION) -C $INSTALL_PATH/ &>>$LOG_FILE
	check_status $? "Starting openwisp failed."
}

give_information_to_user() {
	dashboard_domain=$(get_env "DASHBOARD_DOMAIN" "$INSTALL_PATH/.env")
	db_user=$(get_env "DB_USER" "$INSTALL_PATH/.env")
	db_pass=$(get_env "DB_PASS" "$INSTALL_PATH/.env")

	echo -e ${GRN}"\nYour setup is ready, your dashboard should be available on https://${dashboard_domain} in 2 minutes.\n"
	echo -e "You can login on the dashboard with"
	echo -e "    username: admin"
	echo -e "    password: admin"
	echo -e "Please remember to change these credentials.\n"
	echo -e "Random database user and password generate by the script:"
	echo -e "    username: ${db_user}"
	echo -e "    password: ${db_pass}"
	echo -e "Please note them, might be helpful for accessing postgresql data in future.\n"${NON}
}

upgrade_os_specific() {
    # Check if a backup .env file exists from a previous installation
    if [[ -f "$ENV_BACKUP" ]]; then
        # Determine the package manager based on the existing .env file or current system
        if grep -q "DEBIAN_FRONTEND" "$ENV_BACKUP" 2>/dev/null; then
            apt_dependenices_setup
        elif grep -q "DOCKER_ENGINE" "$ENV_BACKUP" 2>/dev/null && [ -f "/etc/redhat-release" ]; then
            # Assuming if DOCKER_ENGINE is present and it's a RedHat system, DNF was used
            dnf_dependenices_setup
        else
            # Fallback if no specific package manager detected from backup, try to detect current system
            if command -v apt &> /dev/null; then
                apt_dependenices_setup
            elif command -v dnf &> /dev/null; then
                dnf_dependenices_setup
            else
                error_msg "Could not determine package manager for upgrade."
            fi
        fi
    else
        # If no backup, determine based on current system
        if command -v apt &> /dev/null; then
            apt_dependenices_setup
        elif command -v dnf &> /dev/null; then
            dnf_dependenices_setup
        else
            error_msg "Could not determine package manager for upgrade."
        fi
    fi
    upgrade_docker_openwisp
    dashboard_domain=$(get_env "DASHBOARD_DOMAIN" "$INSTALL_PATH/.env")
    echo -e ${GRN}"\nYour upgrade was successfully done."
    echo -e "Your dashboard should be available on https://${dashboard_domain} in 2 minutes.\n"${NON}
}

install_os_specific() {
    if command -v apt &> /dev/null; then
        apt_dependenices_setup
    elif command -v dnf &> /dev/null; then
        dnf_dependenices_setup
    else
        error_msg "Unsupported operating system. Only Debian, Ubuntu, and Rocky Linux are supported."
    fi
    setup_docker
    setup_docker_openwisp
    give_information_to_user
}


init_setup() {
	if [[ "$1" == "upgrade" ]]; then
		echo -e ${GRN}"Welcome to OpenWISP auto-upgradation script."
		echo -e "You are running the upgrade option to change version of"
		echo -e "OpenWISP already setup with this script.\n"${NON}
	else
		echo -e ${GRN}"Welcome to OpenWISP auto-installation script."
		echo -e "Please ensure following requirements:"
		echo -e "  - Fresh instance"
		echo -e "  - 2GB RAM (Minimum)"
		echo -e "  - Supported systems"
		echo -e "    - Debian: 10 & 11"
		echo -e "    - Ubuntu 18.04, 18.10, 20.04 & 22.04"
		echo -e "    - Rocky Linux: 8 & 9"
		echo -e ${YLW}"\nYou can use -u\--upgrade if you are upgrading from an older version.\n"${NON}
	fi

	mkdir -p $BASE_PATH
	echo "" >$LOG_FILE

	start_step "Checking your system capabilities..."
	# Detect OS and use appropriate package manager
	if command -v lsb_release &>/dev/null; then
		system_id=$(lsb_release --id --short)
		system_release=$(lsb_release --release --short)
	elif [ -f "/etc/os-release" ]; then
		. /etc/os-release
		system_id=$ID
		system_release=$VERSION_ID
	else
		error_msg "Could not determine operating system. Please install lsb-release."
	fi

	incompatible_message="$system_id $system_release is not support. Installation might fail, continue anyway? (Y/n): "

    # Extract the major version for Rocky Linux
    rocky_major_release=$(echo "$system_release" | cut -d'.' -f1)

    case "$system_id" in
        "Debian" | "Ubuntu")
            case "$system_release" in
                18.04 | 20.04 | 22.04 | 10 | 11 | 12)
                    if [[ "$1" == "upgrade" ]]; then
                        report_ok && upgrade_os_specific
                    else
                        report_ok && install_os_specific
                    fi
                    ;;
                *)
                    error_msg_with_continue "$incompatible_message"
                    install_os_specific
                    ;;
            esac
            ;;
        "rocky")
            # Check for major versions 8 or 9 (and any sub-version)
            if [[ "$rocky_major_release" == "8" || "$rocky_major_release" == "9" ]]; then
                if [[ "$1" == "upgrade" ]]; then
                    report_ok && upgrade_os_specific
                else
                    report_ok && install_os_specific
                fi
            else
                error_msg_with_continue "$incompatible_message"
                install_os_specific
            fi
            ;;
        *)
            error_msg_with_continue "$incompatible_message"
            install_os_specific
            ;;
    esac
}

init_help() {
	echo -e ${GRN}"Welcome to OpenWISP auto-installation script.\n"

	echo -e "Please ensure following requirements:"
	echo -e "  - Fresh instance"
	echo -e "  - 2GB RAM (Minimum)"
	echo -e "  - Supported systems"
	echo -e "    - Debian: 10 & 11"
	echo -e "    - Ubuntu 18.04, 18.10, 20.04, 22.04"
	echo -e "    - Rocky Linux: 8 & 9"
	echo -e "  -i\--install : (default) Install OpenWISP"
	echo -e "  -u\--upgrade : Change OpenWISP version already setup with this script"
	echo -e "  -h\--help    : See this help message"
	echo -e ${NON}
}

## Parse command line arguments
while test $# != 0; do
	case "$1" in
	-i | --install) action='install' ;;
	-u | --upgrade) action='upgrade' ;;
	-h | --help) action='help' ;;
	*) action='help' ;;
	esac
	shift
done

## Init script
if [[ "$action" == "help" ]]; then
	init_help
elif [[ "$action" == "upgrade" ]]; then
	init_setup upgrade
else
	init_setup
fi
