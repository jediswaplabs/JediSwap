import pytest
import asyncio
import math

MINIMUM_LIQUIDITY = 1000
BURN_ADDRESS = 1

def uint(a):
    return(a, 0)

@pytest.mark.asyncio
async def test_add_liquidity(starknet, router, pair, token_0, token_1, user_1, random_acc):
    user_1_signer, user_1_account = user_1
    random_signer, random_account = random_acc
    
    print("\nMint loads of tokens to user_1")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 100 * (10 ** token_0_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 100 * (10 ** token_1_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_1)])

    amount_token_0 = 2 * (10 ** token_0_decimals)
    # amount_token_1 = 4 * (10 ** token_1_decimals)  ## TODO Will change once sqrt is available
    amount_token_1 = amount_token_0
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_1_signer.send_transaction(user_1_account, token_1.contract_address, 'approve', [router.contract_address, *uint(amount_token_1)])
    
    ## New pair with 0 liquidity
    print("Add liquidity to new pair")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address, 
        token_1.contract_address, 
        *uint(amount_token_0), 
        *uint(amount_token_1), 
        *uint(0), 
        *uint(0), 
        user_1_account.contract_address, 
        0
    ])
    amountA = execution_info.result.response[0]
    amountB = execution_info.result.response[2]
    liquidity = execution_info.result.response[4]
    print(f"{amountA}, {amountB}, {liquidity}")
    assert amountA == amount_token_0
    assert amountB == amount_token_1
    assert float(liquidity) == math.sqrt(amount_token_0 * amount_token_1) - MINIMUM_LIQUIDITY

    execution_info = await pair.get_reserves().call()
    reserve_0 = execution_info.result.reserve0[0]
    reserve_1 = execution_info.result.reserve1[0]
    execution_info = await pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1
    assert (total_supply + 1) * (total_supply + 1) > reserve_0 * reserve_1


    amount_token_0 = 5 * (10 ** token_0_decimals)
    amount_token_1 = 4 * (10 ** token_1_decimals)
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_1_signer.send_transaction(user_1_account, token_1.contract_address, 'approve', [router.contract_address, *uint(amount_token_1)])

    ## Already used pair, has liquidity
    print("Add liquidity to old pair")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address, 
        token_1.contract_address, 
        *uint(amount_token_0), 
        *uint(amount_token_1), 
        *uint(0), 
        *uint(0), 
        user_1_account.contract_address, 
        0
    ])
    amountA = execution_info.result.response[0]
    amountB = execution_info.result.response[2]
    liquidity = execution_info.result.response[4]
    print(f"{amountA}, {amountB}, {liquidity}")

    execution_info = await pair.get_reserves().call()
    reserve_0 = execution_info.result.reserve0[0]
    reserve_1 = execution_info.result.reserve1[0]
    execution_info = await pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1

    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user_1_token_0_balance = execution_info.result.balance[0]
    print(f"Check: depleted user balance for token_0: {amount_to_mint_token_0}, {user_1_token_0_balance}, {reserve_0}")
    assert amount_to_mint_token_0 - user_1_token_0_balance == reserve_0

    execution_info = await token_1.balanceOf(user_1_account.contract_address).call()
    user_1_token_1_balance = execution_info.result.balance[0]
    print(f"Check: depleted user balance for token_1: {amount_to_mint_token_1}, {user_1_token_1_balance}, {reserve_1}")
    assert amount_to_mint_token_1 - user_1_token_1_balance == reserve_1

    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(f"Check: user_1 liquidity + locked liquidity is total supply: {total_supply}, {user_1_pair_balance}")
    assert total_supply == user_1_pair_balance + MINIMUM_LIQUIDITY

    print("Approve required pair tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, pair.contract_address, 'approve', [router.contract_address, *uint(user_1_pair_balance)])

    ## Remove liquidity completely
    print("Remove liquidity")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'remove_liquidity', [
        token_0.contract_address, 
        token_1.contract_address, 
        *uint(user_1_pair_balance), 
        *uint(0), 
        *uint(0), 
        user_1_account.contract_address, 
        0
    ])
    amountA = execution_info.result.response[0]
    amountB = execution_info.result.response[2]
    print(f"{amountA}, {amountB}")

    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print("Check: user_1 balance is 0")
    assert user_1_pair_balance == 0

    execution_info = await pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"Check: total supply is minimum supply: {total_supply}")
    assert total_supply == MINIMUM_LIQUIDITY

    execution_info = await pair.balanceOf(BURN_ADDRESS).call()
    burn_address_pair_balance = execution_info.result.balance[0]
    print(f"Check: total supply is in burn address: {total_supply} {burn_address_pair_balance}")
    assert total_supply == burn_address_pair_balance

    execution_info = await pair.get_reserves().call()
    reserve_0 = execution_info.result.reserve0[0]
    reserve_1 = execution_info.result.reserve1[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1
