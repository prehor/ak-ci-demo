### DOCKER_IMAGE ###############################################################

DOCKER_PROJECT		?= sicz
DOCKER_NAME		?= ak-ci-demo
DOCKER_IMAGE_NAME	?= $(DOCKER_PROJECT)/$(DOCKER_NAME)
DOCKER_IMAGE_TAG	?= latest
DOCKER_IMAGE_DESC	?= A lighttpd web server based on Alpine Linux
DOCKER_IMAGE_URL	?= https://www.lighttpd.net
DOCKER_IMAGE		?= $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)

GITHUB_URL		?= https://github.com/$(DOCKER_PROJECT)/$(DOCKER_NAME)

BUILD_DEPENDENCIES	?= Dockerfile \
			   $(shell find rootfs)

CREATE_ARGS		?= --expose 80 \
			   --publish 80:80

TEST_RUN		?= docker run $(TEST_ARGS) sicz/dockerspec
TEST_ARGS		?= -it --rm \
			   -e DOCKER_IMAGE=$(DOCKER_IMAGE) \
			   -e SERVICE_NAME=$(DOCKER_NAME) \
			   -e CONTAINER_NAME=`cat .docker-create` \
			   -e SPEC_OPTS="--format doc --tty" \
			   --link `cat .docker-create`:$(DOCKER_NAME) \
			   -v /var/run/docker.sock:/var/run/docker.sock \
			   -w /home/$(DOCKER_NAME)
TEST_CMD		?= rspec

SNYK_ARGS		?= -it --rm \
			   -e SNYK_TOKEN=$$SNYK_TOKEN \
			   -e MONITOR=true \
			   -v /var/run/docker.sock:/var/run/docker.sock
SNYK_CMD		?= test \
			   --docker $(DOCKER_IMAGE) \
			   --file=/project/Dockerfile

### MAKE_TARGETS ###############################################################

# Build a new image and run the tests
.PHONY: all
all: clean build start logs test snyk

# Build a new image, run the tests and clean
.PHONY: ci
ci: all
	@$(MAKE) down

# Build a new image with using the Docker layer caching
.PHONY: build
build: .docker-build
.docker-build: $(BUILD_DEPENDENCIES)
	@rm -f $@
	docker build $(BUILD_ARGS)\
		--tag $(DOCKER_IMAGE) \
		--label org.opencontainers.image.title="$(DOCKER_IMAGE_NAME)" \
		--label org.opencontainers.image.version="$(DOCKER_IMAGE_TAG)" \
		--label org.opencontainers.image.description="$(DOCKER_IMAGE_DESC)" \
		--label org.opencontainers.image.url="$(DOCKER_IMAGE_URL)" \
		--label org.opencontainers.image.source="$(GITHUB_URL)" \
		.
	@touch $@

# Build a new image without using the Docker layer caching
.PHONY: rebuild
rebuild:
	@rm -f $@
	$(MAKE) build BUILD_ARGS=--no-cache

# Creates the container
.PHONY: create
create: .docker-create
.docker-create: .docker-build
	docker create $(CREATE_ARGS) $(DOCKER_IMAGE) | tee $@
	docker cp spec/fixtures/www/index.html `cat .docker-create`:/var/www

# Start the containers
.PHONY: start
start: .docker-start
.docker-start: .docker-create
	docker start `cat .docker-create` | tee $@

# Display the container logs
.PHONY: logs
logs: start
	docker logs `cat .docker-create`

# Follow the container logs
.PHONY: logs-tail tail
logs-tail tail: start
	docker logs -f `cat .docker-create`

# Run shell in the container
.PHONY: shell sh
shell sh: start
	docker exec -it `cat  .docker-create` /bin/bash

# Run the tests
.PHONY: test
test: start
	docker create $(TEST_ARGS) sicz/dockerspec $(TEST_CMD) | tee .docker-test
	docker cp $$PWD `cat .docker-test`:/home
	docker start -i `cat .docker-test`
	rm -f .docker-test

.PHONY: snyk
snyk: start
	docker create $(SNYK_ARGS) snyk/snyk-cli:docker $(SNYK_CMD) | tee .docker-snyk
	docker cp $$PWD `cat .docker-snyk`:/project
	docker start -i `cat .docker-snyk`

# Run the shell in the test container
.PHONY: test-shell tsh
test-shell tsh: start
	@$(MAKE) test TEST_CMD=/bin/bash

# Stop the containers
.PHONY: stop
stop:
	[ ! -e .docker-start ] || docker stop `cat .docker-create`
	@rm -f .docker-start

# Remove the containers
.PHONY: down rm
down rm: stop
	[ ! -e .docker-create ] || docker rm `cat .docker-create`
	@rm -f .docker-create

# Restart the containers
.PHONY: restart
restart: stop
	$(MAKE) start

# Remove the containers and then run them fresh
.PHONY: run up
run up: down
	$(MAKE) start

# Remove all containers and work files
.PHONY: clean
clean: down
	rm -fv .docker-*

# Pull Docker images
.PHONY: docker-pull docker-pull-dependencies
docker-pull:
	docker pull $(DOCKER_IMAGE)

docker-pull-dependencies:
	docker pull sicz/dockerspec
	docker pull snyk/snyk-cli:docker

# Push Docker image to Docker hub
.PHONY: docker-push
docker-push: build
	docker push $(DOCKER_IMAGE)

################################################################################
