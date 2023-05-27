import asyncio
from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.account.account import Account
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.models import StarknetChainId
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.net.udc_deployer.deployer import Deployer
from starknet_py.net.schemas.gateway import CasmClassSchema
from pathlib import Path
from base_funcs import *
import sys
import requests
import os

os.environ['CAIRO_PATH'] = 'lib/cairo_contracts/src/'

tokens = []

async def main():
    network_arg = sys.argv[1]

    if network_arg == 'local':
        from config.local import fee_to_setter_address, factory_address, router_address, token_addresses_and_decimals, declared_token_class_hash, max_fee
        local_network = "http://127.0.0.1:5050"
        current_client = GatewayClient({"feeder_gateway_url": f"{local_network}/feeder_gateway", "gateway_url": f"{local_network}/gateway"})
        deployed_accounts_url = f"{local_network}/predeployed_accounts" 
        response = requests.get(deployed_accounts_url)
        deployed_accounts = response.json()
        deployer_account = Account(
            client=current_client, 
            address=deployed_accounts[0]["address"],
            key_pair=KeyPair(private_key=int(deployed_accounts[0]["private_key"], 16), public_key=int(deployed_accounts[0]["public_key"], 16)),
            chain=StarknetChainId.TESTNET,
            )
        print(f"Deployer Address: {deployer_account.address}, {hex(deployer_account.address)}")
        if fee_to_setter_address is None:
            fee_to_setter_address = deployer_account.address
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
        casm_class = CasmClassSchema().loads(Path("target/dev/JediSwap_PairC1.casm.json").read_text())
        casm_class_hash = compute_casm_class_hash(casm_class)
        declare_transaction = await deployer_account.sign_declare_v2_transaction(compiled_contract=Path("target/dev/JediSwap_PairC1.sierra.json").read_text(), compiled_class_hash=casm_class_hash, max_fee=int(1e16))
        resp = await deployer_account.client.declare(transaction=declare_transaction)
        await deployer_account.client.wait_for_tx(resp.transaction_hash)
        declared_pair_class_hash = resp.class_hash
        print(f"Declared pair class hash: {declared_pair_class_hash}, {hex(declared_pair_class_hash)}")
        casm_class = CasmClassSchema().loads(Path("target/dev/JediSwap_FactoryC1.casm.json").read_text())
        casm_class_hash = compute_casm_class_hash(casm_class)
        declare_transaction = await deployer_account.sign_declare_v2_transaction(compiled_contract=Path("target/dev/JediSwap_FactoryC1.sierra.json").read_text(), compiled_class_hash=casm_class_hash, max_fee=int(1e16))
        resp = await deployer_account.client.declare(transaction=declare_transaction)
        await deployer_account.client.wait_for_tx(resp.transaction_hash)
        declared_factory_class_hash = resp.class_hash
        print(f"Declared factory class hash: {declared_factory_class_hash}, {hex(declared_factory_class_hash)}")
        udc_deployer = Deployer()
        contract_deployment = udc_deployer.create_contract_deployment_raw(class_hash=declared_factory_class_hash, raw_calldata=[declared_pair_class_hash, fee_to_setter_address])
        deploy_invoke_transaction = await deployer_account.sign_invoke_transaction(calls=contract_deployment.call, max_fee=int(1e16))
        resp = await deployer_account.client.send_transaction(deploy_invoke_transaction)
        await deployer_account.client.wait_for_tx(resp.transaction_hash)
        factory_address = contract_deployment.address
    factory = Contract(address=factory_address, abi=json.loads(Path("build/Factory_abi.json").read_text()), provider=deployer_account)
    print(f"Factory deployed: {factory.address}, {hex(factory.address)}")
    result = await factory.functions["get_fee_to_setter"].call()
    print(f"Fee to setter: {result.address}, {hex(result.address)}")

    if router_address is None:
        casm_class = CasmClassSchema().loads(Path("target/dev/JediSwap_RouterC1.casm.json").read_text())
        casm_class_hash = compute_casm_class_hash(casm_class)
        declare_transaction = await deployer_account.sign_declare_v2_transaction(compiled_contract=Path("target/dev/JediSwap_RouterC1.sierra.json").read_text(), compiled_class_hash=casm_class_hash, max_fee=int(1e16))
        resp = await deployer_account.client.declare(transaction=declare_transaction)
        await deployer_account.client.wait_for_tx(resp.transaction_hash)
        declared_router_class_hash = resp.class_hash
        print(f"Declared router class hash: {declared_router_class_hash}, {hex(declared_router_class_hash)}")
        udc_deployer = Deployer()
        contract_deployment = udc_deployer.create_contract_deployment_raw(class_hash=declared_router_class_hash, raw_calldata=[factory.address])
        deploy_invoke_transaction = await deployer_account.sign_invoke_transaction(calls=contract_deployment.call, max_fee=int(1e16))
        resp = await deployer_account.client.send_transaction(deploy_invoke_transaction)
        await deployer_account.client.wait_for_tx(resp.transaction_hash)
        router_address = contract_deployment.address
    router = Contract(address=router_address, abi=json.loads(Path("build/Router_abi.json").read_text()), provider=deployer_account)
    print(f"Router deployed: {router.address}, {hex(router.address)}")

    ## Deploy and Mint tokens
    
    for (token_address, token_decimals) in token_addresses_and_decimals:
        token,  declared_token_class_hash = await deploy_or_get_token(token_address, declared_token_class_hash, deployer_account, max_fee)
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
        await create_or_get_pair(current_client, factory, token0, token1, deployer_account, max_fee)

        # Add liquidity
        await add_liquidity_to_pair(current_client, factory, router, token0, token1, amount0, amount1, deployer_account, max_fee)

    #     # Swap
        await swap_token0_to_token1(current_client, factory, router, token0, token1, amount0/20, deployer_account, max_fee)


if __name__ == "__main__":
    asyncio.run(main())

