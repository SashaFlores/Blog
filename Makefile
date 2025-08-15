-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil zktest

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

format:
	forge fmt 

clean:
	forge clean

update:
	forge update

build:
	forge build

test-forked:
	forge test --fork-url $(MAINNET_RPC_URL) -vvvv

snapshot:
	forge snapshot

NETWORK_ARGS := -rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

deploy-mainnet:
	forge script script/Deploy.s.sol:DeployScript --rpc-url $(MAINNET_RPC_URL) --private-key $(MAINNET_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
