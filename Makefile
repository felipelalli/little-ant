PYTHON := python3
HASKELL_SOURCES := $(shell find src app test -name '*.hs' -type f | sort)

.PHONY: build test cli-test python-test spec-audit coverage vocabulary format-check lint check ci

build:
	cabal build all

test:
	cabal test all

cli-test: build
	./test/e2e/s01-cli.sh

python-test:
	$(PYTHON) -m unittest discover -s test/conformance -t .

spec-audit:
	$(PYTHON) tools/lant_conformance.py audit

coverage:
	$(PYTHON) tools/lant_conformance.py coverage --output /tmp/little-ant-coverage.json

vocabulary:
	$(PYTHON) tools/lant_conformance.py vocabulary

format-check:
	cabal-fmt --check little-ant.cabal
	@for source in $(HASKELL_SOURCES); do fourmolu --mode check "$$source"; done

lint:
	hlint src app test
	cabal check

check: python-test spec-audit coverage vocabulary format-check lint build test cli-test

ci: check
