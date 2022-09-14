import asyncio
from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.account.account_client import AccountClient, KeyPair
from starknet_py.transactions.declare import make_declare_tx
from starknet_py.transactions.deploy import make_deploy_tx
from starknet_py.net.models import StarknetChainId
from pathlib import Path
from base_funcs import *
import sys
import requests
import os

os.environ['CAIRO_PATH'] = 'lib/cairo_contracts/src/'

# Local network
local_network = "http://127.0.0.1:5050"
testnet_network = "https://alpha4.starknet.io"
tokens = []

async def main():
    network_arg = sys.argv[1]

    if network_arg == 'local':
        from config.local import DEPLOYER, deployer_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        current_network = local_network
        current_client = GatewayClient(current_network, chain=StarknetChainId.TESTNET)
        if deployer_address is None:
            deployer = await AccountClient.create_account(current_client, DEPLOYER)
            mint_json = {"address": hex(deployer.address), "amount": 10**18}
            url = f"{local_network}/mint" 
            x = requests.post(url, json = mint_json)
        else:
            deployer = AccountClient(address=deployer_address, key_pair=KeyPair.from_private_key(DEPLOYER),  net=current_network, chain=StarknetChainId.TESTNET)
    elif network_arg == 'testnet':
        from config.testnet_none import DEPLOYER, deployer_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        current_network = testnet_network
        current_client = GatewayClient('testnet')
        if deployer_address is None:
            deployer = await AccountClient.create_account(current_client, DEPLOYER)
        else:
            deployer = AccountClient(address=deployer_address, key_pair=KeyPair.from_private_key(DEPLOYER),  net='testnet')

    print(f"Deployer Address: {deployer.address}, {hex(deployer.address)}")
    
    ## Deploy factory and router
    
    if factory_address is None:
        declare_tx = make_declare_tx(compilation_source=Path("contracts/Pair.cairo").read_text())
        declared_pair_class = await current_client.declare(declare_tx)
        declared_class_hash = declared_pair_class.class_hash
        print(f"Declared class hash: {declared_class_hash}")
        deployment_result = await Contract.deploy(client=current_client, compilation_source=Path("contracts/Factory.cairo").read_text(), constructor_args=[declared_class_hash, deployer.address])
        await deployment_result.wait_for_acceptance()
        factory_address = deployment_result.deployed_contract.address
    factory = await Contract.from_address(factory_address, current_client)
    result = await factory.functions["get_fee_to_setter"].call()
    print(f"Factory deployed: {factory.address}, {hex(factory.address)}, {result}")

    if router_address is None:
        deployment_result = await Contract.deploy(client=current_client, compilation_source=Path("contracts/Router.cairo").read_text(), constructor_args=[factory.address])
        await deployment_result.wait_for_acceptance()
        router_address = deployment_result.deployed_contract.address
    router = await Contract.from_address(router_address, current_client)
    print(f"Router deployed: {router.address}, {hex(router.address)}")

    ## Deploy and Mint tokens
    
    for (token_address, token_decimals) in token_addresses_and_decimals:
        token = await deploy_or_get_token(current_client, token_address, token_decimals, deployer, max_fee)
        tokens.append(token)

    to_create_pairs_array = [
        (tokens[0], tokens[1], 10 ** 8, int((10 ** 8) / 2)), 
        (tokens[0], tokens[2], 10 ** 8, (10 ** 8) * 2),
        (tokens[0], tokens[3], 0.000162, 0.5),
        (tokens[3], tokens[1], 10 ** 8, int((10 ** 8) / 2)),
        (tokens[3], tokens[2], 10 ** 8, (10 ** 8) * 2)
        ]

    for (token0, token1, amount0, amount1) in to_create_pairs_array:
        
        # Set pair
        await create_or_get_pair(current_client, factory, token0, token1, deployer, max_fee)

        # Add liquidity
        await add_liquidity_to_pair(current_client, factory, router, token0, token1, amount0, amount1, deployer, max_fee)

        # Swap
        await swap_token0_to_token1(current_client, factory, router, token0, token1, amount0/20, deployer, max_fee)


if __name__ == "__main__":
    asyncio.run(main())

