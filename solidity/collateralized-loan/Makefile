
runner = bun x

test:
	$(runner) hardhat test 

.PHONY: test

compile:
	$(runner) hardhat compile 

.PHONY: compile

check:
	$(runner) hardhat check

.PHONY: check

fmt: ts-fmt

ts-fmt:
	$(runner) prettier --write './**/*.ts'

.PHONY: fmt ts-fmt

fmt-check:
	$(runner) prettier --check './**/*.ts'
	$(runner) prettier --check --no-config --plugin=prettier-plugin-solidity 'contracts/**/*.sol'

.PHONY: fmt-check

