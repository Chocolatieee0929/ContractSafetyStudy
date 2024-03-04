-include .env

.PHONY: all test clean help install snapshot format anvil 

help:
	@echo "Usage:"
	@echo "  make smulate [ARGS=...]\n    example: make smulate f=\"script/BaseScript.s.sol\""
	@echo ""
	@echo "  make attack [ARGS=...]\n    example: make deploy ARGS=\"script/BaseScript.s.sol\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops@0.1.0 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(ARGS),--network sepolia)
    NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

test:
	@forge test --mp $(f) --fork-url ${SEPOLIA_RPC_URL} -vvvv

smulate:
	@forge script $(f) --fork-url ${SEPOLIA_RPC_URL} -vvvv

attack:
	@forge script $(f) --rpc-url ${SEPOLIA_RPC_URL} --tc Solution --private-key ${PRIVATE_KEY} --broadcast

