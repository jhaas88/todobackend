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

#Check and Inspect Logic
INSPECT := $$(sudo docker-compose -p $$1 -f $$2 ps -q $$3 | xargs -I ARGS sudo docker inspect -f "{{ .State.ExitCode }}" ARGS)

CHECK := @bash -c '\
    if [[ $(INSPECT) -ne 0 ]]; \
    then exit $(INSPECT); fi' VALUE

.PHONY: test build release clean

test:
	${INFO} "Building images..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build
	${INFO} "Ensuring database is ready..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) run --rm agent
	${INFO} "Running tests..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test
	@ sudo docker cp $$(sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/reports/. reports
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) test
	${INFO} "Testing complete"

build:
	${INFO} "Building application artifacts..."
	@ sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder
	${CHECK} $(DEV_PROJECT) $(DEV_COMPOSE_FILE) builder
	${INFO} "Copying artifacts to target folder..."
	@ sudo docker cp $$(sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q builder):/wheelhouse/. target
	${INFO} "Build complete"

release:
	${INFO} "Building images..."
	@ sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build
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

#Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

#Shell Functions
INFO := @bash -c '\
    printf $(YELLOW); \
    echo "=> $$1"; \
    printf $(NC)' VALUE