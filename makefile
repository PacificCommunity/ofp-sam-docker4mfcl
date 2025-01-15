# Variables
IMAGE_NAME = bd
WORKDIR = $(shell pwd)

# Targets
# Build the Docker image
build:
	docker build -t $(IMAGE_NAME) .

make-container:
	docker run --rm -v $(WORKDIR):/workspace -w /workspace $(IMAGE_NAME) make all
