# Find documentation in README.md under
# the heading "Makefile Options".

OPENWISP_VERSION = stable-master
# The .env file can override ?= variables in the Makefile (e.g. OPENWISP_VERSION, IMAGE_OWNER)
include .env

# RELEASE_VERSION: version string used when tagging a new release.
RELEASE_VERSION = $(shell cat images/common/openwisp/VERSION)
SHELL := /bin/bash
.SILENT: clean clean-vol pull start stop

default: compose-build

USER = docker.io/openwisp
TAG = edge
SKIP_PULL ?= false
SKIP_BUILD ?= false
SKIP_TESTS ?= false

# Pull
pull:
	printf '\e[1;34m%-6s\e[m\n' "Downloading OpenWISP images..."
	for image in 'openwisp-base' 'openwisp-nfs' 'openwisp-api' 'openwisp-dashboard' \
				 'openwisp-freeradius' 'openwisp-nginx' 'openwisp-openvpn' 'openwisp-postfix' \
				 'openwisp-websocket' ; do \
<<<<<<< HEAD
		docker pull --quiet $(USER)/$${image}:$(TAG); \
		docker tag  $(USER)/$${image}:$(TAG) openwisp/$${image}:latest; \
=======
		docker pull --quiet $(USER)/$${image}:$(OPENWISP_VERSION) || exit 1; \
		docker tag $(USER)/$${image}:$(OPENWISP_VERSION) $(IMAGE_OWNER)/$${image}:$(OPENWISP_VERSION) || exit 1; \
>>>>>>> aa644b2 ([fix] Fixed Docker Hub image pulls #669)
	done

# Build
python-build: build.py
	python build.py change-secret-key

base-build:
	BUILD_ARGS_FILE=$$(cat .build.env 2>/dev/null); \
	for build_arg in $$BUILD_ARGS_FILE; do \
	    BUILD_ARGS+=" --build-arg $$build_arg"; \
	done; \
	docker build --tag openwisp-base:intermedia-system \
	             --file ./images/openwisp_base/Dockerfile \
	             --target system ./images/; \
	docker build --tag openwisp/openwisp-base:intermedia-python \
	             --file ./images/openwisp_base/Dockerfile \
	             --target openwisp_python ./images/ \
	             $$BUILD_ARGS; \
	docker build --tag $(IMAGE_OWNER)/openwisp-base:$(OPENWISP_VERSION) \
	             --file ./images/openwisp_base/Dockerfile \
	             $$BUILD_ARGS \
	             ./images/

nfs-build:
	docker build --tag openwisp/openwisp-nfs:latest \
	             --file ./images/openwisp_nfs/Dockerfile ./images/

compose-build: base-build
	docker compose build --parallel

# Test
runtests:
	make develop-runtests
	docker compose stop

develop-runtests:
	docker compose up -d
	make develop-pythontests

develop-pythontests:
	python3 tests/runtests.py

# Development
develop: compose-build
	docker compose up -d
	docker compose logs -f

# Clean
clean:
	printf '\e[1;34m%-6s\e[m\n' "Removing docker-openwisp containers and images only..."
	docker compose stop &> /dev/null
	docker compose down --remove-orphans --rmi all &> /dev/null
	docker compose rm -svf &> /dev/null
	docker rmi --force openwisp-base:latest \
				openwisp-base:intermedia-system \
				openwisp-base:intermedia-python \
				openwisp/openwisp-nfs:latest \
				`docker images -f "dangling=true" -q` \
				`docker images | grep openwisp/docker-openwisp | tr -s ' ' | cut -d ' ' -f 3` &> /dev/null

clean-vol:
	printf '\e[1;34m%-6s\e[m\n' "Removing docker-openwisp containers and volumes only..."
	docker compose down --remove-orphans --volumes --rmi all &> /dev/null

# Production
start:
	# We build images first
	make compose-build
	printf '\e[1;34m%-6s\e[m\n' "Building images then starting Services...please wait.."
	docker --log-level WARNING compose up -d
	printf '\e[1;32m%-6s\e[m\n' "Success: OpenWISP should be available at your dashboard domain in 2 minutes."

stop:
	printf '\e[1;31m%-6s\e[m\n' "Stopping OpenWISP services..."
	docker --log-level ERROR compose stop
	docker --log-level ERROR compose down --remove-orphans
	docker compose down --remove-orphans &> /dev/null

# Publish
publish:
	if [[ "$(SKIP_BUILD)" == "false" ]]; then \
		make compose-build nfs-build; \
	fi
	if [[ "$(SKIP_TESTS)" == "false" ]]; then \
		make runtests; \
	fi
	for image in 'openwisp-base' 'openwisp-nfs' 'openwisp-api' 'openwisp-dashboard' \
				 'openwisp-freeradius' 'openwisp-nginx' 'openwisp-openvpn' 'openwisp-postfix' \
				 'openwisp-websocket' ; do \
		# Docker images built locally are tagged "latest" by default. \
		# This script updates the tag of each built image to a user-defined tag \
		# and pushes the newly tagged image to a Docker registry under the user's namespace. \
		docker tag openwisp/$${image}:latest $(USER)/$${image}:$(TAG); \
		docker push $(USER)/$${image}:$(TAG); \
		if [ "$(TAG)" != "latest" ]; then \
			docker rmi $(USER)/$${image}:$(TAG); \
		fi; \
	done

release:
	make publish TAG=latest OPENWISP_VERSION=$(RELEASE_VERSION) SKIP_TESTS=true
	make publish TAG=$(RELEASE_VERSION) OPENWISP_VERSION=$(RELEASE_VERSION) SKIP_BUILD=true SKIP_TESTS=true

bump:
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION parameter required. Usage: make bump VERSION=X.Y.Z"; \
		exit 1; \
	fi
	python build.py bump-version "$(VERSION)"
