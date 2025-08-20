-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38

format:
	forge fmt 

snapshot:
	forge snapshot

clean:
	forge clean

update:
	forge update

build:
	forge build

install:

	forge install foundry-rs/forge-std@v1.10.0 && forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.4.0
	&& forge install OpenZeppelin/openzeppelin-foundry-upgrades@v0.4.0 && forge install Cyfrin/foundry-devops@v0.4.0

remove : 
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

deploy-fork:
	@forge script script/DeployBlog.s.sol:DeployBlog --fork-url ${SEPOLIA_RPC} --account testnetsDeployer --broadcast -vvvv

deploy-sepolia:
	@forge script script/DeployBlog.s.sol:DeployBlog --rpc-url ${SEPOLIA_RPC} --account testnetsDeployer --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-ethereum:
	@forge script script/DeployBlog.s.sol:DeployBlog --rpc-url $(ETHEREUM_RPC) --account mainnetsDeployer --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-amoy:
	@forge script script/DeployBlog.s.sol:DeployBlog --rpc-url $(AMOY_RPC) --account testnetsDeployer --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv

deploy-polygon:
	@forge script script/DeployBlog.s.sol:DeployBlog --rpc-url $(POLYGON_RPC) --account mainnetsDeployer --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv

