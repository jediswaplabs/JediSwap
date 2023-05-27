import asyncio
from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.account.account import Account
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.models import StarknetChainId
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.net.schemas.gateway import CasmClassSchema
from pathlib import Path
from base_funcs import *
import sys
import requests
import os

os.environ['CAIRO_PATH'] = 'lib/cairo_contracts/src/'

tokens = []

async def cairo_0_setup():
    network_arg = sys.argv[1]
    deploy_token = None

    if network_arg == 'local':
        from config.local import fee_to_setter_address_0 as fee_to_setter_address, factory_address_0 as factory_address, router_address_0 as router_address, token_addresses_and_decimals, declared_token_class_hash, max_fee
        local_network = "http://127.0.0.1:5050"
        current_client = GatewayClient({"feeder_gateway_url": f"{local_network}/feeder_gateway", "gateway_url": f"{local_network}/gateway"})
        deployed_accounts_url = f"{local_network}/predeployed_accounts" 
        response = requests.get(deployed_accounts_url)
        deployed_accounts = response.json()
        deployer = Account(
            client=current_client, 
            address=deployed_accounts[0]["address"],
            key_pair=KeyPair(private_key=int(deployed_accounts[0]["private_key"], 16), public_key=int(deployed_accounts[0]["public_key"], 16)),
            chain=StarknetChainId.TESTNET,
            )
        print(f"Deployer Address: {deployer.address}, {hex(deployer.address)}")
        if fee_to_setter_address is None:
            fee_to_setter_address = deployer.address
        else:
            fee_to_setter_address = int(fee_to_setter_address, 16)
    elif network_arg == 'testnet':
        from config.testnet_none import fee_to_setter_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        current_client = GatewayClient('testnet')
        fee_to_setter_address = int(fee_to_setter_address, 16)
    elif network_arg == 'testnet2':
        from config.testnet_none import fee_to_setter_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        network_url = "https://alpha4-2.starknet.io"
        current_client = GatewayClient({"feeder_gateway_url": f"{network_url}/feeder_gateway", "gateway_url": f"{network_url}/gateway"})
        fee_to_setter_address = int(fee_to_setter_address, 16)
    elif network_arg == 'mainnet':
        from config.mainnet_none import fee_to_setter_address, factory_address, router_address, token_addresses_and_decimals, max_fee
        current_client = GatewayClient('mainnet')
        fee_to_setter_address = int(fee_to_setter_address, 16)
        deploy_token = os.environ['DEPLOY_TOKEN']
    
    
    ## Deploy factory and router
    
    if factory_address is None:
        declare_transaction = await deployer.sign_declare_transaction(compiled_contract=Path("build/Pair.json").read_text(), max_fee=int(1e16))
        resp = await deployer.client.declare(transaction=declare_transaction)
        await deployer.client.wait_for_tx(resp.transaction_hash)
        declared_pair_class_hash = resp.class_hash
        print(f"Declared pair class hash: {declared_pair_class_hash}, {hex(declared_pair_class_hash)}")
        declare_transaction = await deployer.sign_declare_transaction(compiled_contract=Path("build/PairProxy.json").read_text(), max_fee=int(1e16))
        resp = await deployer.client.declare(transaction=declare_transaction)
        await deployer.client.wait_for_tx(resp.transaction_hash)
        declared_pair_proxy_class_hash = resp.class_hash
        print(f"Declared pair proxy class hash: {declared_pair_proxy_class_hash}, {hex(declared_pair_proxy_class_hash)}")        
        declare_transaction = await deployer.sign_declare_transaction(compiled_contract=Path("build/Factory.json").read_text(), max_fee=int(1e16))
        resp = await deployer.client.declare(transaction=declare_transaction)
        await deployer.client.wait_for_tx(resp.transaction_hash)
        declared_factory_class_hash = resp.class_hash
        print(f"Declared factory class hash: {declared_factory_class_hash}, {hex(declared_factory_class_hash)}")
        declare_result = await Contract.declare(account=deployer, compiled_contract=Path("build/FactoryProxy.json").read_text(),  max_fee=int(1e16))
        await declare_result.wait_for_acceptance()
        declared_factory_proxy_class_hash = declare_result.class_hash
        print(f"Declared factory proxy class hash: {declared_factory_proxy_class_hash}, {hex(declared_factory_proxy_class_hash)}")
        deploy_result = await declare_result.deploy(constructor_args=[declared_factory_class_hash, declared_pair_proxy_class_hash, declared_pair_class_hash, fee_to_setter_address], max_fee=int(1e16))
        await deploy_result.wait_for_acceptance()
        factory_address = deploy_result.deployed_contract.address
    factory = Contract(address=factory_address, abi=json.loads(Path("build/Factory_abi.json").read_text()), provider=deployer)
    print(f"Factory deployed: {factory.address}, {hex(factory.address)}")
    result = await factory.functions["get_fee_to_setter"].call()
    print(f"Fee to setter: {result.address}, {hex(result.address)}")

    if router_address is None:
        declare_transaction = await deployer.sign_declare_transaction(compiled_contract=Path("build/Router.json").read_text(), max_fee=int(1e16))
        resp = await deployer.client.declare(transaction=declare_transaction)
        await deployer.client.wait_for_tx(resp.transaction_hash)
        declared_router_class_hash = resp.class_hash
        print(f"Declared router class hash: {declared_router_class_hash}, {hex(declared_router_class_hash)}")
        declare_result = await Contract.declare(account=deployer, compiled_contract=Path("build/RouterProxy.json").read_text(), max_fee=int(1e16))
        await declare_result.wait_for_acceptance()
        declared_router_proxy_class_hash = declare_result.class_hash
        print(f"Declared router proxy class hash: {declared_router_proxy_class_hash}, {hex(declared_router_proxy_class_hash)}")
        deploy_result = await declare_result.deploy(constructor_args=[declared_router_class_hash, factory.address, fee_to_setter_address], max_fee=int(1e16))
        await deploy_result.wait_for_acceptance()
        router_address = deploy_result.deployed_contract.address
    router = Contract(address=router_address, abi=json.loads(Path("build/Router_abi.json").read_text()), provider=deployer)
    print(f"Router deployed: {router.address}, {hex(router.address)}")

    ## Deploy and Mint tokens
    
    for (token_address, token_decimals) in token_addresses_and_decimals:
        token,  declared_token_class_hash = await deploy_or_get_token(token_address, declared_token_class_hash, deployer, max_fee)
        tokens.append(token)

    to_create_pairs_array = [
        (tokens[0], tokens[1], 10 ** 8, 10 ** 8), 
        # (tokens[0], tokens[2], 10 ** 8, (10 ** 8) * 2),
        # (tokens[0], tokens[3], 0.000162, 0.5),
        # (tokens[3], tokens[1], 10 ** 8, int((10 ** 8) / 2)),
        # (tokens[3], tokens[2], 10 ** 8, (10 ** 8) * 2)
        ]

    for (token0, token1, amount0, amount1) in to_create_pairs_array:
        
        # Set pair
        await create_or_get_pair(current_client, factory, token0, token1, deployer, max_fee)

    #     # Add liquidity
        await add_liquidity_to_pair(current_client, factory, router, token0, token1, amount0, amount1, deployer, max_fee)

    #     # Swap
        await swap_token0_to_token1(current_client, factory, router, token0, token1, 1, deployer, max_fee)
    
    return factory_address, router_address, deployer

