from starknet_py.contract import Contract
from pathlib import Path
import time
import json

def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")

def felt_to_string(number):
    return number.to_bytes(length=(8 + (number + (number < 0)).bit_length()) // 8, byteorder='big', signed=True).decode('UTF-8')

async def deploy_or_get_token(current_client, token_address, token_decimals, deployer, max_fee):
    if token_address is None:
        print("Deploying Token")
        deployment_result = await Contract.deploy(client=deployer, compiled_contract=Path("artifacts/ERC20.json").read_text(), constructor_args=[str_to_felt("TestTokenJedi"), str_to_felt("TTJ"), token_decimals, deployer.address])
        await deployment_result.wait_for_acceptance()
        token = deployment_result.deployed_contract
        estimated_fee = await token.functions["mint"].prepare(deployer.address, (10 ** 9) * (10 ** token_decimals)).estimate_fee()
        print(f"Estimated fee: {estimated_fee}")
        await token.functions["mint"].invoke(deployer.address, (10 ** 9) * (10 ** token_decimals), max_fee=max_fee)
    else:
        token = await Contract.from_address(token_address, current_client)
        # token = Contract(token_address, json.loads(Path("artifacts/abis/ERC20.json").read_text()), current_client)
    print(f"Token deployed: {token.address}, {hex(token.address)}")
    return token

async def create_or_get_pair(current_client, factory, token0, token1, deployer, max_fee):
    result = await factory.functions["get_pair"].call(token0.address, token1.address)
    if result.pair != 0:
        pair = await Contract.from_address(result.pair, current_client)
        print(f"Pair already deployed: {result.pair}, {pair.address}, {hex(pair.address)}")
        return pair
    ## Create pair
    print("Creating Pair")
    factory_with_account = await Contract.from_address(factory.address, deployer)
    estimated_fee = await factory_with_account.functions["create_pair"].prepare(token0.address, token1.address).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await factory_with_account.functions["create_pair"].invoke(token0.address, token1.address, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    print(f"transaction_hash: {invocation.hash}")
    result = await factory.functions["get_pair"].call(token0.address, token1.address)
    pair = await Contract.from_address(result.pair, current_client)
    print(f"Pair deployed: {result.pair}, {pair.address}, {hex(pair.address)}")
    return pair

async def add_liquidity_to_pair(current_client, factory, router, token0, token1, amount0, amount1, deployer, max_fee):

    result = await token0.functions["decimals"].call()
    amount0 = int(amount0 * (10 ** result.decimals))
    result = await token1.functions["decimals"].call()
    amount1 = int(amount1 * (10 ** result.decimals))

    # Approve
    token0_with_account = await Contract.from_address(token0.address, deployer)
    invocation = await token0_with_account.functions["approve"].invoke(router.address, amount0, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    token1_with_account = await Contract.from_address(token1.address, deployer)
    invocation = await token1_with_account.functions["approve"].invoke(router.address, amount1, max_fee=max_fee)
    await invocation.wait_for_acceptance()

    ## Add liquidity
    print("Adding Liquidity")
    deadline = int(time.time()) + 3000
    router_with_account = await Contract.from_address(router.address, deployer)
    estimated_fee = await router_with_account.functions["add_liquidity"].prepare(token0.address, token1.address, amount0, amount1, 0, 0, deployer.address, deadline).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await router_with_account.functions["add_liquidity"].invoke(token0.address, token1.address, amount0, amount1, 0, 0, deployer.address, deadline, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    print(f"transaction_hash: {invocation.hash}")
    result = await factory.functions["get_pair"].call(token0.address, token1.address)
    pair = await Contract.from_address(result.pair, current_client)
    result = await pair.functions["get_reserves"].call()
    print(result)

async def swap_token0_to_token1(current_client, factory, router, token0, token1, amount0, deployer, max_fee):

    result = await token0.functions["decimals"].call()
    amount0 = int(amount0 * (10 ** result.decimals))

    result = await token0.functions["balanceOf"].call(deployer.address)
    print(f"Balance token0: {result.balance}")
    result = await token1.functions["balanceOf"].call(deployer.address)
    print(f"Balance token1: {result.balance}")

    # Approve
    token0_with_account = await Contract.from_address(token0.address, deployer)
    invocation = await token0_with_account.functions["approve"].invoke(router.address, amount0, max_fee=max_fee)
    await invocation.wait_for_acceptance()

    ## Swap
    print("Swapping")
    deadline = int(time.time()) + 3000
    router_with_account = await Contract.from_address(router.address, deployer)
    estimated_fee = await router_with_account.functions["swap_exact_tokens_for_tokens"].prepare(amount0, 0, [token0.address, token1.address], deployer.address, deadline).estimate_fee()
    print(f"Estimated fee: {estimated_fee}")
    invocation = await router_with_account.functions["swap_exact_tokens_for_tokens"].invoke(amount0, 0, [token0.address, token1.address], deployer.address, deadline, max_fee=max_fee)
    await invocation.wait_for_acceptance()
    print(f"transaction_hash: {invocation.hash}")
    result = await factory.functions["get_pair"].call(token0.address, token1.address)
    pair = await Contract.from_address(result.pair, current_client)
    result = await pair.functions["get_reserves"].call()
    print(result)

    result = await token0.functions["balanceOf"].call(deployer.address)
    print(f"Balance token0: {result.balance}")
    result = await token1.functions["balanceOf"].call(deployer.address)
    print(f"Balance token1: {result.balance}")
