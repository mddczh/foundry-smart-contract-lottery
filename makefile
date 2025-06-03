-include .env

.PHONY: all test deploy build

build :; forge build

test :; forge test

install :; forge install Cyfrin/foundry-devops@0.2.2 --no-commit && \
forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 --no-commit && \
forge install foundry-rs/forge-std@v1.9.7 --no-commit && \
forge install transmissions11/solmate@v6 --no-commit

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 10

deploy-anvil :; forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvv

deploy-sepolia :; @forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast -vvvv