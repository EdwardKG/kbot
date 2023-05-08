# Message colors
_SUCCESS := "\033[32m[%s]\033[0m %s\n"
_ERROR := "\033[31m[%s]\033[0m %s\n"
_INFO := "\033[1;34m[%s]\033[0m %s\n"
_WARNING := "\033[93m[%s]\033[0m %s\n"

# Set the name of the app
APP := $(shell basename $(shell git remote get-url origin 2>/dev/null || echo "defapp"))
# Set the Git path for the app
GIT_PATH := $(shell git remote get-url origin | sed 's/.*github.com\//github.com\//;s/\.git$$//' || echo "github.com/yourname/yourrepo")

# Convert text to lowercase
to_lowercase = $(shell echo $(1) | tr A-Z a-z)

# Get the app version from Git
VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "unknown-$(shell date +%s)")

# Set the target OS and architecture
OS := linux
ARCH := amd64
APP_FULL_NAME := $(APP)-$(OS)$(ARCH)

# Set the name of the registry to use
REGISTRY := adalbertbarta

# Define the entrypoint for the app
ENTRYPOINT := ENTRYPOINT [\"./toTestAPP\", \"start\"]

# Define the port to expose
EXPOSE := 8888

# Define a list of variables to display in the help text
VARIABLES := APP GIT_PATH VERSION OS ARCH APP_FULL_NAME REGISTRY ENTRYPOINT EXPOSE

# Define the help target
.PHONY: help
help: ##Help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf $(_ERROR) "Available variables and their values:"
	@printf $(_INFO) "-----------START-----------"
	@$(foreach var,$(VARIABLES_ARRAY),printf $(_WARNING) "$(var) = $($(var))";)
	@printf $(_INFO) "-----------END-----------"
	@printf $(_ERROR) "AND VARIABLES AND VALUES"


# Set the default target to print settings
.DEFAULT_GOAL := help

# Define the test target
.PHONY: test
test:
	@if ! go test -v -cover ./...; then \
		printf $(_ERROR) "Tests failed,build stop"; \
		exit 1; \
	fi
	@printf $(_SUCCESS) "Tests was passed, OK"
	@echo "\n"

# Define the build target
.PHONY: build
build: test
	@printf $(_SUCCESS) "Builder for $(OS) architecture $(ARCHITECTURE)"
	@go get ./...
	@printf $(_WARNING) "-----------START BUILD-----------"
	CGO_ENABLED=0 GOOS=$(OS) GOARCH=$(ARCHITECTURE) go build  -v  -o $(APP_FULL_NAME) -ldflags $(LDFLAGS)
	@printf $(_WARNING) "-----------END BUILD-----------"
	@if [ $$? -ne 0 ]; then \
        printf $(_ERROR) "Error: Failed to build $(APP_FULL_NAME) for $(OS)"; \
        exit 1; \
    fi
	@printf $(_SUCCESS) "Successfully built $(APP_FULL_NAME) for $(OS) with architecture $(ARCHITECTURE)\n"


# Build for Linux, default architecture is amd64
build_linux:
	@make build OS=linux

# Build for macOS, default architecture is amd64
build_macos:
	@make build OS=darwin

# Build for Windows, default architecture is amd64
build_windows:
	@make build OS=windows

# Set the architecture to ARM64 for the given OS type, e.g. "make build_arm linux"
build_arm%:
	$(eval OS=$*)
	$(eval OS=$(call to_lowercase,$(OS)))
	$(eval TARGETARCH=arm64)
	$(eval ARCH_SHORT_NAME=arm)
	$(eval APP_FULL_NAME=$(APP)-$(OS)$(ARCH_SHORT_NAME))
	@if [ -z "$(OS)" ]; then \
		OS=linux; \
	fi
	@printf $(_SUCCESS) "Starting ARM64 build for $(APP_FULL_NAME)"
	@make $(OS) TARGETARCH=$(ARCHITECTURE) ARCH_SHORT_NAME=$(ARCH_SHORT_NAME)

# Set the architecture to AMD64 for the given OS type, e.g. "make build_amd linux"
build_amd%:
	$(eval OS=$*)
	$(eval OS=$(call to_lowercase,$(OS)))
	$(eval TARGETARCH=amd64)
	$(eval ARCH_SHORT_NAME=amd)
	$(eval APP_FULL_NAME=$(APP)-$(OS)$(ARCH_SHORT_NAME))
	@printf $(_SUCCESS) "Starting AMD64 build for $(OS)"
	@make $(OS) TARGETARCH=$(ARCHITECTURE) ARCH_SHORT_NAME=$(ARCH_SHORT_NAME)

# Generate Dockerfile from template
generate_dockerfile:
	@if [ -f $(STATIC_DOCKERFILE) ]; then \
		cat $(STATIC_DOCKERFILE) > $(DOCKERFILE); \
		echo $(BUILDER_LAST_ACTION) >> $(DOCKERFILE); \
		echo $(CERT_SETTINGS) >> $(DOCKERFILE); \
		echo $(ENTRYPOINT) >> $(DOCKERFILE); \
	else \
        printf $(_ERROR) "$(STATIC_DOCKERFILE) does not exist"; \
    fi


build:
	@docker build \
	--no-cache \
	-t $(REGISTRY)/$(APP)-$(OS)$(ARCH_SHORT_NAME):$(VERSION) \
	-f $(DOCKERFILE) \
	--build-arg APP_NAME=$(APP)-$(OS)$(ARCH_SHORT_NAME) \
	--build-arg OS_TARGET=$(ARCH_SHORT_NAME)$(OS) \
	--build-arg FROM_IMAGE=$(IMAGE_BUILDER) \
	.
	@make push

image-linux: build-linux create-dockerfile build

image-macos: build-macos create-dockerfile build

image-windows: build-windows create-dockerfile build

image-arm%: build-arm% create-dockerfile build

image-amd%: build-amd% create-dockerfile build

push:
	@docker push $(REGISTRY)/$(APP)-$(OS)$(ARCH_SHORT_NAME):$(VERSION)

save-image: ## Save Docker image to a tar file
	@docker images
	@read -p "Enter the name of the Docker image to save: " IMAGE_NAME; \
	read -p "Enter the path to save the Docker image: " IMAGE_PATH; \
	if [ -f "$$IMAGE_PATH/$$IMAGE_NAME.tar" ]; then \
        printf $(_WARNING) "The image file already exists. Do you want to overwrite it? [y/n]: "; \
        read OVERWRITE; \
        if [ $$OVERWRITE != "y" ]; then \
            printf $(_INFO) "The image file was not saved."; \
            exit 0; \
        fi; \
    fi; \
	docker save -o $$IMAGE_PATH/$$IMAGE_NAME.tar $$IMAGE_NAME; \
	printf $(_SUCCESS) "The Docker image was saved to $$IMAGE_PATH/$$IMAGE_NAME.tar."



save-image: ## Save Docker image to a tar file
	@docker images
	@read -p "Enter the name of the Docker image to save: " IMAGE_NAME; \
	read -p "Enter the path to save the Docker image: " IMAGE_PATH; \
	if [ -f "$$IMAGE_PATH/$$IMAGE_NAME.tar" ]; then \
        printf $(_WARNING) "The image file already exists. Do you want to overwrite it? [y/n]: "; \
        read OVERWRITE; \
        if [ $$OVERWRITE != "y" ]; then \
            printf $(_INFO) "The image file was not saved."; \
            exit 0; \
        fi; \
    fi; \
	docker save -o $$IMAGE_PATH/$$IMAGE_NAME.tar $$IMAGE_NAME; \
	printf $(_SUCCESS) "The Docker image was saved to $$IMAGE_PATH/$$IMAGE_NAME.tar."
