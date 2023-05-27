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
from cairo0_setup import *
import sys
import requests
import os

os.environ['CAIRO_PATH'] = 'lib/cairo_contracts/src/'

tokens = []

async def main():
    network_arg = sys.argv[1]

    if network_arg == 'local':
        from config.local import declared_factory_intermediate_class_hash, declared_router_intermediate_class_hash, declared_factory_class_hash, declared_router_class_hash, declared_pair_class_hash, max_fee
        factory_address_0, router_address_0, deployer_account = await cairo_0_setup()
        print(factory_address_0, router_address_0)

    if declared_factory_intermediate_class_hash is None:
        casm_class = CasmClassSchema().loads(Path("target/dev/JediSwap_FactoryC1Intermediate.casm.json").read_text())
        casm_class_hash = compute_casm_class_hash(casm_class)
        declare_transaction = await deployer_account.sign_declare_v2_transaction(compiled_contract=Path("target/dev/JediSwap_FactoryC1Intermediate.sierra.json").read_text(), compiled_class_hash=casm_class_hash, max_fee=int(1e16))
        resp = await deployer_account.client.declare(transaction=declare_transaction)
        await deployer_account.client.wait_for_tx(resp.transaction_hash)
        declared_factory_intermediate_class_hash = resp.class_hash
        print(f"Declared factory class hash: {declared_factory_intermediate_class_hash}, {hex(declared_factory_intermediate_class_hash)}")

    if declared_router_intermediate_class_hash is None:
        casm_class = CasmClassSchema().loads(Path("target/dev/JediSwap_RouterC1Intermediate.casm.json").read_text())
        casm_class_hash = compute_casm_class_hash(casm_class)
        declare_transaction = await deployer_account.sign_declare_v2_transaction(compiled_contract=Path("target/dev/JediSwap_RouterC1Intermediate.sierra.json").read_text(), compiled_class_hash=casm_class_hash, max_fee=int(1e16))
        resp = await deployer_account.client.declare(transaction=declare_transaction)
        await deployer_account.client.wait_for_tx(resp.transaction_hash)
        declared_router_intermediate_class_hash = resp.class_hash
        print(f"Declared router class hash: {declared_router_intermediate_class_hash}, {hex(declared_router_intermediate_class_hash)}")
    
    ## Upgrading factory
    print("Upgrading Factory")
    factory_proxy_with_account = Contract(address=factory_address_0, abi=json.loads(Path("build/FactoryProxy_abi.json").read_text()), provider=deployer_account)
    estimated_fee = await factory_proxy_with_account.functions["upgrade"].prepare(declared_factory_intermediate_class_hash).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await factory_proxy_with_account.functions["upgrade"].invoke(declared_factory_intermediate_class_hash, max_fee=max_fee)
    await invocation.wait_for_acceptance()

    ## Finalizing factory upgrade
    print("Finalizing factory upgrade")
    factory_proxy_with_account = Contract(address=factory_address_0, abi=json.loads(Path("target/dev/FactoryC1Intermediate_abi.json").read_text()), provider=deployer_account)
    estimated_fee = await factory_proxy_with_account.functions["replace_pair_contract_hash"].prepare(declared_pair_class_hash).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await factory_proxy_with_account.functions["replace_pair_contract_hash"].invoke(declared_pair_class_hash, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    
    estimated_fee = await factory_proxy_with_account.functions["replace_implementation_class"].prepare(declared_factory_class_hash).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await factory_proxy_with_account.functions["replace_implementation_class"].invoke(declared_factory_class_hash, max_fee=max_fee)
    await invocation.wait_for_acceptance()

    ## Upgrading router
    print("Upgrading Router")
    router_proxy_with_account = Contract(address=router_address_0, abi=json.loads(Path("build/RouterProxy_abi.json").read_text()), provider=deployer_account)
    estimated_fee = await router_proxy_with_account.functions["upgrade"].prepare(declared_router_intermediate_class_hash).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await router_proxy_with_account.functions["upgrade"].invoke(declared_router_intermediate_class_hash, max_fee=max_fee)
    await invocation.wait_for_acceptance()

    ## Finalizing router upgrade
    print("Finalizing router upgrade")
    router_proxy_with_account = Contract(address=router_address_0, abi=json.loads(Path("target/dev/RouterC1Intermediate_abi.json").read_text()), provider=deployer_account)
    estimated_fee = await router_proxy_with_account.functions["replace_implementation_class"].prepare(declared_router_class_hash).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await router_proxy_with_account.functions["replace_implementation_class"].invoke(declared_router_class_hash, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    
    



if __name__ == "__main__":
    asyncio.run(main())

