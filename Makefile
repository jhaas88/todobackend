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

.PHONY: test build release clean

test:
	sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build
	sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up agent
	sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test

build:
	sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder

release:
	sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build
	sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up agent
	sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py collectstatic --noinput
	sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py migrate --noinput
	sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up test

clean:
	sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) stop
	sudo docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) rm -f
	sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) stop
	sudo docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) rm -f