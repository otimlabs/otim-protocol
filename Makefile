.PHONY: help install build test fmt clean snapshot selectors docker-build all

help: ## Show this help
	@echo "Usage: make [target]"
	@echo
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

install: ## Install dependencies
	forge soldeer update

build: ## Build contracts
	forge build

test: ## Run contract unit tests
	forge test

fmt: ## Format contract code
	forge fmt

clean: ## Clean build artifacts
	forge clean

snapshot: ## Update gas snapshots
	forge snapshot

selectors: ## Find function selector (usage: make selectors SELECTOR=0x...)
	forge selectors find $(SELECTOR)

docker-build: ## Build Docker image (usage: make docker-build TAG=latest)
	docker build -t otim-protocol:$${TAG:-local} -f Dockerfile .

all: install build test ## Install, build, and test
