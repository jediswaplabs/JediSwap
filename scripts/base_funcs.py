from numpy import block
from starknet_py.contract import Contract
from pathlib import Path
import time
import json
from starknet_py.hash.casm_class_hash import compute_casm_class_hash
from starknet_py.net.schemas.gateway import CasmClassSchema

def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")

def felt_to_string(number):
    return number.to_bytes(length=(8 + (number + (number < 0)).bit_length()) // 8, byteorder='big', signed=True).decode('UTF-8')

async def print_transaction_execution_details(current_client, tx_hash):
    print(f"transaction_hash: {tx_hash}")
    tx_details = await current_client.get_transaction_receipt(tx_hash)
    print(f"transaction_details: execution_resources: {tx_details.execution_resources}, actual_fee: {tx_details.actual_fee}")
    block_details = await current_client.get_block(block_number=tx_details.block_number)
    print(f"gas price: {block_details.gas_price}")
    cairo_usage = []
    execution_resources = tx_details.execution_resources
    cairo_resource_fee_weights = {"n_steps": 0.05, "pedersen_builtin": 0.4, "range_check_builtin": 0.4, "ecdsa_builtin": 25.6, "bitwise_builtin": 12.8}
    execution_resources_gas_usages = {
        "n_steps": execution_resources.n_steps * cairo_resource_fee_weights["n_steps"], 
        "pedersen_builtin": execution_resources.builtin_instance_counter["pedersen_builtin"] * cairo_resource_fee_weights["pedersen_builtin"],
        "range_check_builtin": execution_resources.builtin_instance_counter["range_check_builtin"] * cairo_resource_fee_weights["range_check_builtin"],
        "ecdsa_builtin": execution_resources.builtin_instance_counter["ecdsa_builtin"] * cairo_resource_fee_weights["ecdsa_builtin"],
        "bitwise_builtin": execution_resources.builtin_instance_counter["bitwise_builtin"] * cairo_resource_fee_weights["bitwise_builtin"]
        }
    print(f"execution_resources_gas_usages: {execution_resources_gas_usages}")
    limiting_factor_gas_usage = max(list(execution_resources_gas_usages.values()))
    limiting_factor = list(execution_resources_gas_usages.keys())[list(execution_resources_gas_usages.values()).index(limiting_factor_gas_usage)]
    print(f"limiting_factor: {limiting_factor}, limiting_factor_gas_usage: {limiting_factor_gas_usage}")
    overall_fee = block_details.gas_price * limiting_factor_gas_usage
    print(f"overall fee calculated: {overall_fee}")


async def deploy_or_get_token(token_address, declared_token_class_hash, deployer, max_fee):
    if token_address is None:
        print("Deploying Token")
        if declared_token_class_hash is None:
            casm_class = CasmClassSchema().loads(Path("target/dev/JediSwap_ERC20.casm.json").read_text())
            casm_class_hash = compute_casm_class_hash(casm_class)
            declare_transaction = await deployer.sign_declare_v2_transaction(compiled_contract=Path("target/dev/JediSwap_ERC20.sierra.json").read_text(), compiled_class_hash=casm_class_hash, max_fee=int(1e16))
            resp = await deployer.client.declare(transaction=declare_transaction)
            await deployer.client.wait_for_tx(resp.transaction_hash)
            declared_token_class_hash = resp.class_hash
            print(f"Declared token class hash: {declared_token_class_hash}, {hex(declared_token_class_hash)}")
        deployment_result = await Contract.deploy_contract(account=deployer, class_hash=declared_token_class_hash, abi=json.loads(Path("build/ERC20_abi.json").read_text()), constructor_args=[str_to_felt("TestTokenJedi"), str_to_felt("TTJ"), (10 ** 9) * (10 ** 18), deployer.address], max_fee=int(1e16))
        await deployment_result.wait_for_acceptance()
        token = deployment_result.deployed_contract
        token_address = token.address
    token = Contract(address=token_address, abi=json.loads(Path("build/ERC20_abi.json").read_text()), provider=deployer)
    print(f"Token deployed: {token.address}, {hex(token.address)}")
    return token, declared_token_class_hash

async def create_or_get_pair(current_client, factory, token0, token1, deployer, max_fee):
    result = await factory.functions["get_pair"].call(token0.address, token1.address)
    if result.pair != 0:
        pair = await Contract.from_address(result.pair, current_client)
        print(f"Pair already deployed: {result.pair}, {pair.address}, {hex(pair.address)}")
        return pair
    ## Create pair
    print("Creating Pair")
    factory_with_account = Contract(address=factory.address, abi=json.loads(Path("build/Factory_abi.json").read_text()), provider=deployer)
    estimated_fee = await factory_with_account.functions["create_pair"].prepare(token0.address, token1.address).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await factory_with_account.functions["create_pair"].invoke(token0.address, token1.address, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    # await print_transaction_execution_details(current_client, invocation.hash)
    result = await factory.functions["get_pair"].call(token0.address, token1.address)
    pair = Contract(address=result.pair, abi=json.loads(Path("build/Pair_abi.json").read_text()), provider=deployer)
    print(f"Pair deployed: {result.pair}, {pair.address}, {hex(pair.address)}")
    return pair

async def add_liquidity_to_pair(current_client, factory, router, token0, token1, amount0, amount1, deployer, max_fee):

    result = await token0.functions["decimals"].call()
    amount0 = int(amount0 * (10 ** result.decimals))
    result = await token1.functions["decimals"].call()
    amount1 = int(amount1 * (10 ** result.decimals))

    # Approve
    token0_with_account = Contract(address=token0.address, abi=json.loads(Path("build/ERC20_abi.json").read_text()), provider=deployer)
    invocation = await token0_with_account.functions["approve"].invoke(router.address, amount0, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    token1_with_account = Contract(address=token1.address, abi=json.loads(Path("build/ERC20_abi.json").read_text()), provider=deployer)
    invocation = await token1_with_account.functions["approve"].invoke(router.address, amount1, max_fee=max_fee)
    await invocation.wait_for_acceptance()

    ## Add liquidity
    print("Adding Liquidity")
    deadline = int(time.time()) + 3000
    router_with_account = Contract(address=router.address, abi=json.loads(Path("build/Router_abi.json").read_text()), provider=deployer)
    estimated_fee = await router_with_account.functions["add_liquidity"].prepare(token0.address, token1.address, amount0, amount1, 0, 0, deployer.address, deadline).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await router_with_account.functions["add_liquidity"].invoke(token0.address, token1.address, amount0, amount1, 0, 0, deployer.address, deadline, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    # await print_transaction_execution_details(current_client, invocation.hash)
    result = await factory.functions["get_pair"].call(token0.address, token1.address)
    pair = Contract(address=result.pair, abi=json.loads(Path("build/Pair_abi.json").read_text()), provider=current_client)
    result = await pair.functions["get_reserves"].call()
    print(result._asdict())

async def swap_token0_to_token1(current_client, factory, router, token0, token1, amount0, deployer, max_fee):

    result = await token0.functions["decimals"].call()
    print(amount0)
    amount0 = int(amount0 * (10 ** result.decimals))
    print(amount0)


    result = await token0.functions["balanceOf"].call(deployer.address)
    print(f"Balance token0: {result.balance}")
    result = await token1.functions["balanceOf"].call(deployer.address)
    print(f"Balance token1: {result.balance}")

    # Approve
    token0_with_account = Contract(address=token0.address, abi=json.loads(Path("build/ERC20_abi.json").read_text()), provider=deployer)
    invocation = await token0_with_account.functions["approve"].invoke(router.address, amount0, max_fee=max_fee)
    await invocation.wait_for_acceptance()

    ## Swap
    print("Swapping")
    deadline = int(time.time()) + 3000
    router_with_account = Contract(address=router.address, abi=json.loads(Path("build/Router_abi.json").read_text()), provider=deployer)
    result = await factory.functions["get_pair"].call(token0.address, token1.address)
    pair = Contract(address=result.pair, abi=json.loads(Path("build/Pair_abi.json").read_text()), provider=current_client)
    result = await pair.functions["get_reserves"].call()
    print(result._asdict())
    result = await router_with_account.functions["get_amounts_out"].call(amount0, [token0.address, token1.address])
    print(result._asdict())
    estimated_fee = await router_with_account.functions["swap_exact_tokens_for_tokens"].prepare(amount0, 0, [token0.address, token1.address], deployer.address, deadline).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await router_with_account.functions["swap_exact_tokens_for_tokens"].invoke(amount0, 0, [token0.address, token1.address], deployer.address, deadline, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    # await print_transaction_execution_details(current_client, invocation.hash)
    result = await pair.functions["get_reserves"].call()
    print(result._asdict())

    result = await token0.functions["balanceOf"].call(deployer.address)
    print(f"Balance token0: {result.balance}")
    result = await token1.functions["balanceOf"].call(deployer.address)
    print(f"Balance token1: {result.balance}")
