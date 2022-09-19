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

tokens = []

async def main():
    network_arg = sys.argv[1]
    deploy_token = None

    if network_arg == 'local':
        from config.local import DEPLOYER, deployer_address, fee_to_setter_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        local_network = "http://127.0.0.1:5050"
        current_client = GatewayClient(local_network, chain=StarknetChainId.TESTNET)
        if deployer_address is None:
            deployer = await AccountClient.create_account(current_client, DEPLOYER)
            mint_json = {"address": hex(deployer.address), "amount": 10**18}
            url = f"{local_network}/mint" 
            x = requests.post(url, json = mint_json)
        else:
            deployer = AccountClient(address=deployer_address, key_pair=KeyPair.from_private_key(DEPLOYER),  net=local_network, chain=StarknetChainId.TESTNET)
        print(f"Deployer Address: {deployer.address}, {hex(deployer.address)}")
        if fee_to_setter_address is None:
            fee_to_setter_address = deployer.address
        else:
            fee_to_setter_address = int(fee_to_setter_address, 16)
    elif network_arg == 'testnet':
        from config.testnet_none import DEPLOYER, deployer_address, fee_to_setter_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        current_client = GatewayClient('testnet')
        fee_to_setter_address = int(fee_to_setter_address, 16)
    elif network_arg == 'mainnet':
        from config.mainnet_none import DEPLOYER, deploy_token_mainnet, deployer_address, fee_to_setter_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        current_client = GatewayClient('mainnet')
        fee_to_setter_address = int(fee_to_setter_address, 16)
        deploy_token = deploy_token_mainnet
    
    
    ## Deploy factory and router
    
    ## Generate the json files using starknet-compile as the mainnet token for deployment is generated using those compiled files.
    ## These are not included in the repo. Please run starknet-compile contracts/Pair.cairo --output Pair.json. Similarly for others.
    
    if factory_address is None:
        declare_tx = make_declare_tx(compiled_contract=Path("Pair.json").read_text())
        declared_pair_class = await current_client.declare(declare_tx, token=deploy_token)
        declared_class_hash = declared_pair_class.class_hash
        print(f"Declared class hash: {declared_class_hash}")
        deploy_tx = make_deploy_tx(compiled_contract=Path("Factory.json").read_text(), constructor_calldata=[declared_class_hash, fee_to_setter_address])
        deployment_result = await current_client.deploy(deploy_tx, token=deploy_token)
        await current_client.wait_for_tx(deployment_result.transaction_hash)
        factory_address = deployment_result.contract_address
    factory = await Contract.from_address(factory_address, current_client)
    result = await factory.functions["get_fee_to_setter"].call()
    print(f"Factory deployed: {factory.address}, {hex(factory.address)}, {result.address}, {hex(result.address)}")

    if router_address is None:
        deploy_tx = make_deploy_tx(compiled_contract=Path("Router.json").read_text(), constructor_calldata=[factory.address])
        deployment_result = await current_client.deploy(deploy_tx, token=deploy_token)
        await current_client.wait_for_tx(deployment_result.transaction_hash)
        router_address = deployment_result.contract_address
    router = await Contract.from_address(router_address, current_client)
    print(f"Router deployed: {router.address}, {hex(router.address)}")

    # ## Deploy and Mint tokens
    
    # for (token_address, token_decimals) in token_addresses_and_decimals:
    #     token = await deploy_or_get_token(current_client, token_address, token_decimals, deployer, max_fee)
    #     tokens.append(token)

    # to_create_pairs_array = [
    #     (tokens[0], tokens[1], 10 ** 8, int((10 ** 8) / 2)), 
    #     (tokens[0], tokens[2], 10 ** 8, (10 ** 8) * 2),
    #     (tokens[0], tokens[3], 0.000162, 0.5),
    #     (tokens[3], tokens[1], 10 ** 8, int((10 ** 8) / 2)),
    #     (tokens[3], tokens[2], 10 ** 8, (10 ** 8) * 2)
    #     ]

    # for (token0, token1, amount0, amount1) in to_create_pairs_array:
        
    #     # Set pair
    #     await create_or_get_pair(current_client, factory, token0, token1, deployer, max_fee)

    #     # Add liquidity
    #     await add_liquidity_to_pair(current_client, factory, router, token0, token1, amount0, amount1, deployer, max_fee)

    #     # Swap
    #     await swap_token0_to_token1(current_client, factory, router, token0, token1, amount0/20, deployer, max_fee)


if __name__ == "__main__":
    asyncio.run(main())

