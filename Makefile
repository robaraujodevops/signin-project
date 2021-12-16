include help.mk

.PHONY: local-ssl image-dev run-dev drop-dev logs-dev clean install-package check-versions bump-versions update lint-yaml tsc build image image-push
.DEFAULT_GOAL := help

ifneq ("$(wildcard ./dev/.env)","")
  include ./dev/.env
  export
endif

REGISTRY_NAMESPACE = "${CI_REGISTRY_IMAGE}"

NAME          = $(shell sed -n -e '/name/ s/.*: \"\(.*\)\",/\1/p' package.json)
VERSION       = $(shell sed -n -e '/version/ s/.*: \"\(.*\)\",/\1/p' package.json)
IMAGE         = $(REGISTRY_NAMESPACE):$(VERSION)
DEBUG?        = false

COMPOSE_FILE   = dev/docker/docker-compose.yaml
SSL_HOST       = ${NGINX_HOST}## Must use the env var placed in dev/.env file
SSL_CERT_PATH  = dev/nginx/certs
IMAGE_DEV      = $(REGISTRY_NAMESPACE):dev
RUN            = docker run --rm -v $(PWD):/app --user $(shell id -u):$(shell id -g) --name $(NAME) $(IMAGE_DEV) 
RUN_DEV        = docker-compose \
							   --project-directory dev \
							   --file $(COMPOSE_FILE)


package?   = ""
workspace? = ""

guard-%:
	@ if [ "${${*}}" = "" ]; then \
        echo "argument '$*' is required"; \
        exit 1; \
    fi

# GIT setup, configure the default strategy for git pull and push
ifneq ("$(shell git config --local pull.rebase)", "true")
$(shell git config --local pull.rebase true)
$(shell git config --local alias.pushf "push --force-with-lease")
$(info $(shell tput setaf 3)>> Backstage git pattern not configured, executing git setup$(shell tput sgr0))
endif

.PHONY: init-project
init-project: ##@ Builds development image
	@if [ -d $(shell pwd)/next-app ]; then \
		echo "Next App project exists"; \
	else \
		echo "Next App not exists, creating..."; \
		$(run) -v `pwd`:$(workdir) node:alpine \
			yarn create next-app --typescript $(workdir)/next-app; \
	fi

.PHONY: local-ssl
local-ssl: guard-SSL_HOST guard-SSL_CERT_PATH ##@Local-SSL Creates local certs to run with SSL.
	@mkcert -install && \
	mkcert \
		-cert-file $(SSL_CERT_PATH)/$(SSL_HOST).crt \
		-key-file $(SSL_CERT_PATH)/$(SSL_HOST).key \
		$(SSL_HOST) \
	|| echo "mkcert is not installed";

.PHONY: image-dev
image-dev: guard-IMAGE_DEV ##@Dev Build development base image.
	@echo Building Developer image...
	@docker build -f ./dev/docker/Dockerfile -t $(IMAGE_DEV) .
	@docker push $(IMAGE_DEV)

.PHONY: run-dev
run-dev: guard-COMPOSE_FILE local-ssl update ##@Dev Run local dev env.
	@echo Running Developer environment...
	@$(RUN_DEV) up -d

.PHONY: drop-dev
drop-dev: guard-COMPOSE_FILE ##@Dev Drop local dev env.
	@echo Dropping Developer environment...
	@$(RUN_DEV) down --remove-orphans -v

.PHONY: logs-dev
logs-dev: guard-COMPOSE_FILE ##@Dev Run local logs.
	@echo Logging Developer environment...
	@$(RUN_DEV) logs -f 

.PHONY: clean
clean: ##@Clean Clear current dependencies paths.
	@echo Cleaning dependencies paths...
	@$(RUN) rm -fr node_modules 

.PHONY: install-package
install-package: guard-WORKSPACE guard-PACKAGE ##@Dependencies Installs new packages at app or backend workspace.
	@$(RUN) yarn workspace $(WORKSPACE) add $(PACKAGE)

.PHONY: image
image: ##@Build Build docker image (to debug add image_debug=true).
ifeq ($(DEBUG), false)
	@echo "Build docker backstage:$(VERSION) image."
	@DOCKER_BUILDKIT=1 \
		docker build --pull --tag $(IMAGE) . > /dev/null
else
	@echo "Build docker backstage:$(VERSION) image in debug mode."
	@DOCKER_BUILDKIT=1 \
		docker build --pull --tag $(IMAGE) .
endif

.PHONY: image-push
image-push: ##@Build Push image to registry.
	@echo Pushing 
	@docker push $(IMAGE)
