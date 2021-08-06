include help.mk

workdir=/app

dev_image=next-dev-image:latest
prod_image=next-prod-image:latest
img_exists=$(shell docker images $(dev_image) | grep next-dev || echo false)

run=docker run \
	--network host \
	--rm \
	--user $(shell id -u) \

run_app=$(run) \
	-v `pwd`:$(workdir) \
	--name next-app-dev \
	--tty --interactive $(dev_image) \

.PHONY: init-project
init-project: ##@ Builds development image
	@if [ -d $(shell pwd)/next-app ]; then \
		echo "Next App project exists"; \
	else \
		echo "Next App not exists, creating..."; \
		$(run) -v `pwd`:$(workdir) node:alpine \
			yarn create next-app --typescript $(workdir)/next-app; \
	fi

.PHONY: build-dev-image
build-dev-image: ##@dev Build dev image
ifeq ($(img_exists), false)
		docker build -t $(dev_image) $(buildarg) -f build/dev/Dockerfile .
endif

.PHONY: run-dev
run-dev: build-dev-image ##@dev Run development stack
	$(run_app) \
		yarn run dev

.PHONY: build-app
build-app: ##@build Build app
	docker build -t $(prod_image) -f build/prod/Dockerfile next-app 
