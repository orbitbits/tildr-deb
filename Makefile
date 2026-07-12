# ----- Makefile -----
#
BRANCH := $(shell git branch --show-current 2>/dev/null || echo "unknown")
REMOTES := $(shell git remote 2>/dev/null || echo "")
VERSION := $(shell head -1 debian/changelog | grep -oP '\(.*?\)' | tr -d '()' | sed 's/-.*//')
.DEFAULT_GOAL := help

.PHONY: help build install lint version publish-repo index clean push push-lease

help:
	@echo "Options:"
	@echo
	@echo "  make build        -> Build the DEB package"
	@echo "  make install      -> Build and install the DEB package"
	@echo "  make lint         -> Validate DEB package with lintian"
	@echo "  make version      -> Show current package version"
	@echo "  make publish-repo -> Generate local APT repo for testing"
	@echo "  make index        -> Generate directory index.html for file listing"
	@echo "  make clean        -> Clean all build files"
	@echo
	@echo "  make push         -> Performs a remote push to all branches"
	@echo "  make push-lease   -> Performs a remote push of all branches (lease mode)"

# ----- DEB BUILD -----
build:
	@bash tools/main.sh build

install:
	@bash tools/main.sh install

lint:
	@bash tools/main.sh lint

version:
	@echo "$(VERSION)"

publish-repo:
	@bash tools/publish-repo.sh generate

index:
	@bash tools/generate-index.sh repo

clean:
	@bash tools/main.sh clean

# ----- GIT PUSH -----
push:
	@echo "Push normal → branch: $(BRANCH)"
	@for remote in $(REMOTES); do \
		echo "  pushing to $$remote..."; \
		git push $$remote $(BRANCH); \
	done

push-lease:
	@echo "Push --force-with-lease → branch: $(BRANCH)"
	@for remote in $(REMOTES); do \
		echo "  pushing to $$remote..."; \
		git push --force-with-lease $$remote $(BRANCH); \
	done
