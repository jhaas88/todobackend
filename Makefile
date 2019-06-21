# Project variables
PROJECT_NAME ?= todobackend
ORG_NAME ?= jhaas8
REPO_NAME ?= todobackend

#Filenames
DEV_COMPOSE_FILE := docker/dev/docker-compose.yml
REL_COMPOSE_FILE := docker/release/docker-compose.yml

#Docker Compose Project Names
REL_PROJECT := $(PROJECT_NAME)$(BUILD_ID)
DEV_PROJECT := $(REL_PROJECT)dev

# Application Service Name - must match Docker Compose release specification application service name
APP_SERVICE_NAME := app

#Build tag expression - can be used to evaluate a shell expression at runtime
BUILD_TAG_EXPRESSION ?= date -u +%Y%m%d%H%M%S

#Execute shell expression
BUILD_EXPRESSION := $(shell $(BUILD_TAG_EXPRESSION))

# Build tag
BUILD_TAG ?= $(BUILD_EXPRESSION)

# Use these settings to specify a custom Docker registry
DOCKER_REGISTRY ?= docker.io

#Check and Inspect Logic
INSPECT := $$(sudo docker-compose -p $$1 -f $$2 ps -q $$3 | xargs -I ARGS sudo docker inspect -f "{{ .State.ExitCode }}" ARGS)

CHECK := @bash -c '\
    if [[ $(INSPECT) -ne 0 ]]; \
    then exit $(INSPECT); fi' VALUE

.PHONY: test build release clean tag buildtag

test:
	${INFO} "Pulling latest images..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) pull
	${INFO} "Building images..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build --pull test
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build cache
	${INFO} "Ensuring database is ready..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) run --rm agent
	${INFO} "Running tests..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test
	@ sudo docker cp $$(sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) test
	${INFO} "Testing complete"

build:
	${INFO} "Creating builder image..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build builder
	${INFO} "Building application artifacts..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) builder
	${INFO} "Copying artifacts to target folder..."
	@ sudo docker cp $$(sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q builder):/wheelhouse/. target
	${INFO} "Build complete"

release:
	${INFO} "Pulling latest images..."
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) pull test
	${INFO} "Building images..."
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build app
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build webroot
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build --pull nginx
	${INFO} "Ensuring database is ready..."
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm agent
	${INFO} "Collecting static files..."
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py collectstatic --noinput
	${INFO} "Running database migrations..."
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py migrate --noinput
	${INFO} "Running acceptance tests..."
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up test
# 	@ sudo docker cp $$(sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(REL_PROJECT) $(REL_COMPOSE_FILE) test
	${INFO} "Acceptance testing complete"

clean:
	${INFO} "Destroying development environment..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) stop
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) rm -f -v
	${INFO} "Destroying release environment..."
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) stop
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) rm -f -v
	${INFO} "Removing dangling images..."
# 	sudo docker -q -f dangling=true -f label=application=$(REPO_NAME) | xargs -I ARGS sudo docker rmi -f ARGS
	@ sudo docker image prune --force --filter "label=application=$(REPO_NAME)"
	${INFO} "Clean complete"

tag:
	${INFO} "Tagging release image with tags $(TAG_ARGS)..."
	@ $(foreach tag,$(TAG_ARGS), sudo docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag);)
	${INFO} "Tagging complete"

buildtag:
	${INFO} "Tagging release image with suffix $(BUILD_TAG) and build tags $(BUILDTAG_ARGS)..."
	@ $(foreach tag,$(BUILDTAG_ARGS), sudo docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag).$(BUILD_TAG);)
	${INFO} "Tagging complete"

#Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

#Shell Functions
INFO := @bash -c '\
    printf $(YELLOW); \
    echo "=> $$1"; \
    printf $(NC)' VALUE

#Get container id of application service container
APP_CONTAINER_ID := $$(sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q $(APP_SERVICE_NAME))

# Get image id of application service
IMAGE_ID := $$(sudo docker inspect -f '{{ .Image }}' $(APP_CONTAINER_ID))

# Extract build tag arguments
ifeq (buildtag,$(firstword $(MAKECMDGOALS)))
    BUILDTAG_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    ifeq ($(BUILDTAG_ARGS),)
        $(error You must specify a tag)
    endif
    $(eval $(BUILDTAG_ARGS):;@:)
endif

# Extract tag arguments
ifeq (tag,$(firstword $(MAKECMDGOALS)))
    TAG_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    ifeq ($(TAG_ARGS),)
        $(error You must specify a tag)
    endif
    $(eval $(TAG_ARGS):;@:)
endif