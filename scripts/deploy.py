import asyncio
from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.account.account_client import AccountClient, KeyPair
from starknet_py.transactions.declare import make_declare_tx
from starknet_py.net.models import StarknetChainId
from pathlib import Path
from base_funcs import *
import sys
import requests
import os

from starkware.starknet.core.os.class_hash import compute_class_hash
from starkware.starknet.services.api.contract_class import ContractClass

# Local network
local_network = "http://127.0.0.1:5050"
testnet_network = "https://alpha4.starknet.io"
tokens = []

path_to_json = 'artifacts/'
json_files = [pos_json for pos_json in os.listdir(
    path_to_json) if pos_json.endswith('.json')]


def get_contract_class(class_location):
    location = path_to_json + class_location
    with open(location) as f:
        class_data = json.load(f)
    contract_class = ContractClass.load(class_data)

    return contract_class


def calculate_class_hash(class_location):
    contract_class = get_contract_class(class_location)
    class_hash = compute_class_hash(
        contract_class=contract_class,
    )

    return class_hash

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
        declare_tx = make_declare_tx(compiled_contract=Path("artifacts/Pair.json").read_text())
        declared_pair_class = await current_client.declare(declare_tx)
        # declared_pair_class = await current_client.declare(compiled_contract=Path("artifacts/Pair.json").read_text())
        print(f"Declared Pair Class: {declared_pair_class}")
        # declared_class_hash = int(declared_pair_class["class_hash"], 16)
        declared_class_hash = declared_pair_class.hash
        print(f"Declared class hash: {declared_class_hash}")
        class_hash = calculate_class_hash("Pair.json")
        print(f" class hash: {class_hash}")
        deployment_result = await Contract.deploy(client=current_client, compiled_contract=Path("artifacts/Factory.json").read_text(), constructor_args=[class_hash, deployer.address])
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

