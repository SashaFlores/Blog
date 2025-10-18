-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil lint-solidity

DEFAULT_ANVIL_KEY := 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
FOUNDRY_ROOT := solidity

fmt:
	forge fmt --root $(FOUNDRY_ROOT)

snapshot:
	forge snapshot --root $(FOUNDRY_ROOT)

clean:
	forge clean --root $(FOUNDRY_ROOT)

update:
	forge update --root $(FOUNDRY_ROOT)

build:
	forge build --root $(FOUNDRY_ROOT)

lint-solidity:
	cd $(FOUNDRY_ROOT) && forge lint src

install:
	forge install --root $(FOUNDRY_ROOT) foundry-rs/forge-std@v1.10.0 && \
	forge install --root $(FOUNDRY_ROOT) OpenZeppelin/openzeppelin-contracts-upgradeable@v5.4.0 && \
	forge install --root $(FOUNDRY_ROOT) OpenZeppelin/openzeppelin-foundry-upgrades@v0.4.0 && \
	forge install --root $(FOUNDRY_ROOT) Cyfrin/foundry-devops

remove:
	rm -rf .gitmodules && \
	rm -rf .git/modules/* && \
	rm -rf $(FOUNDRY_ROOT)/lib && \
	touch .gitmodules && \
	git add . && \
	git commit -m "modules"

deploy-sepolia:
	@forge script --root $(FOUNDRY_ROOT) script/DeployBlog.s.sol:DeployBlog --rpc-url ${SEPOLIA_RPC} --account testnetsDeployer --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-ethereum:
	@forge script --root $(FOUNDRY_ROOT) script/DeployBlog.s.sol:DeployBlog --rpc-url $(ETHEREUM_RPC) --account mainnetsDeployer --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-amoy:
	@forge script --root $(FOUNDRY_ROOT) script/DeployBlog.s.sol:DeployBlog --rpc-url $(AMOY_RPC) --account testnetsDeployer --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv

deploy-polygon:
	@forge script --root $(FOUNDRY_ROOT) script/DeployBlog.s.sol:DeployBlog --rpc-url $(POLYGON_RPC) --account mainnetsDeployer --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv
