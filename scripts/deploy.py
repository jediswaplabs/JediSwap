import asyncio
from starknet_py.contract import Contract
from starknet_py.net.client import Client
from starknet_py.net.account.account_client import AccountClient, KeyPair
from starknet_py.net.models import StarknetChainId
from pathlib import Path
from base_funcs import *
import sys

# Local network
local_network = "http://127.0.0.1:5050"
testnet_network = "https://alpha4.starknet.io"
tokens = []

async def main():
    network_arg = sys.argv[1]

    current_network = local_network

    if network_arg == 'local':
        from config.local import DEPLOYER, deployer_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        current_network = local_network
        current_client = Client(current_network, chain=StarknetChainId.TESTNET)
        if deployer_address is None:
            deployer = await AccountClient.create_account(current_network, DEPLOYER, chain=StarknetChainId.TESTNET)
        else:
            deployer = AccountClient(address=deployer_address, key_pair=KeyPair.from_private_key(DEPLOYER),  net=current_network, chain=StarknetChainId.TESTNET)
    elif network_arg == 'testnet':
        from config.testnet import DEPLOYER, deployer_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        current_network == testnet_network
        current_client = Client('testnet')
        if deployer_address is None:
            deployer = await AccountClient.create_account('testnet', DEPLOYER)
        else:
            deployer = AccountClient(address=deployer_address, key_pair=KeyPair.from_private_key(DEPLOYER),  net='testnet')

    print(f"Deployer Address: {deployer.address}, {hex(deployer.address)}")
    
    ## Deploy factory and router
    
    if factory_address is None:
        declared_pair_class = await current_client.declare(compiled_contract=Path("artifacts/Pair.json").read_text())
        declared_class_hash = int(declared_pair_class["class_hash"], 16)
        print(f"Declared class hash: {declared_class_hash}")
        deployment_result = await Contract.deploy(client=current_client, compiled_contract=Path("artifacts/Factory.json").read_text(), constructor_args=[declared_class_hash, deployer.address])
        await deployment_result.wait_for_acceptance()
        factory = deployment_result.deployed_contract
    else:
        factory = await Contract.from_address(factory_address, current_client)
    print(f"Factory deployed: {factory.address}, {hex(factory.address)}")

    if router_address is None:
        deployment_result = await Contract.deploy(client=current_client, compiled_contract=Path("artifacts/Router.json").read_text(), constructor_args=[factory.address])
        await deployment_result.wait_for_acceptance()
        router = deployment_result.deployed_contract
    else:
        router = await Contract.from_address(router_address, current_client)
    print(f"Router deployed: {router.address}, {hex(router.address)}")

    ## Deploy and Mint tokens
    
    for (token_address, token_decimals) in token_addresses_and_decimals:
        token = await deploy_or_get_token(current_client, token_address, token_decimals, deployer, max_fee)
        tokens.append(token)

    to_create_pairs_array = [
        (tokens[0], tokens[1], 10 ** 8, int((10 ** 8) / 2)), 
        # (token_0, token_2, 10 ** 8, (10 ** 8) * 2),
        # (token_0, token_3, 0.000162, 0.5),
        # (token_3, token_1, 10 ** 8, int((10 ** 8) / 2)),
        # (token_3, token_2, 10 ** 8, (10 ** 8) * 2)
        ]

    for (token0, token1, amount0, amount1) in to_create_pairs_array:
        
        ## Set pair
        pair = await create_or_get_pair(current_client, factory, token0, token1, deployer, max_fee)

        ## Add liquidity
        # await add_liquidity_to_pair(router, pair, token0, token1, amount0, amount1, deployer, max_fee)


if __name__ == "__main__":
    asyncio.run(main())

