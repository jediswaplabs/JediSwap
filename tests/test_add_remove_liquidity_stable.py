import pytest
import asyncio
import math
from utils.events import get_event_data
from utils.revert import assert_revert

MINIMUM_LIQUIDITY = 1000
BURN_ADDRESS = 1

def uint(a):
    return(a, 0)

# @pytest.mark.asyncio
# async def test_add_liquidity_expired_deadline(router, stable_token_0, stable_token_1, user_1):
#     user_1_signer, user_1_account = user_1
    
#     execution_info = await stable_token_0.decimals().call()
#     stable_token_0_decimals = execution_info.result.decimals
    
#     execution_info = await stable_token_1.decimals().call()
#     stable_token_1_decimals = execution_info.result.decimals

#     amount_stable_token_0 = 2 * (10 ** stable_token_0_decimals)
#     amount_stable_token_1 = 4 * (10 ** stable_token_1_decimals)
    
#     ## New stable_pair with 0 liquidity
#     print("Add liquidity to new stable_pair")
#     await assert_revert(user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
#         stable_token_0.contract_address, 
#         stable_token_1.contract_address, 
#         *uint(amount_stable_token_0), 
#         *uint(amount_stable_token_1), 
#         *uint(0), 
#         *uint(0), 
#         user_1_account.contract_address, 
#         0
#     ]), "Router::_ensure_deadline::expired")

@pytest.mark.asyncio
async def test_add_remove_liquidity(router, stable_pair, stable_token_0, stable_token_1, user_1, random_acc):
    user_1_signer, user_1_account = user_1
    random_signer, random_account = random_acc
    
    print("\nMint loads of tokens to user_1")
    execution_info = await stable_token_0.decimals().call()
    stable_token_0_decimals = execution_info.result.decimals
    amount_to_mint_stable_token_0 = 100 * (10 ** stable_token_0_decimals)
    ## Mint stable_token_0 to user_1
    await random_signer.send_transaction(random_account, stable_token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_stable_token_0)])
    
    execution_info = await stable_token_1.decimals().call()
    stable_token_1_decimals = execution_info.result.decimals
    amount_to_mint_stable_token_1 = 100 * (10 ** stable_token_1_decimals)
    ## Mint stable_token_0 to user_1
    await random_signer.send_transaction(random_account, stable_token_1.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_stable_token_1)])

    amount_stable_token_0 = 2 * (10 ** stable_token_0_decimals)
    amount_stable_token_1 = 2 * (10 ** stable_token_1_decimals)
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, stable_token_0.contract_address, 'approve', [router.contract_address, *uint(amount_stable_token_0)])
    await user_1_signer.send_transaction(user_1_account, stable_token_1.contract_address, 'approve', [router.contract_address, *uint(amount_stable_token_1)])
    
    ## New stable_pair with 0 liquidity
    print("Add liquidity to new stable_pair")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        stable_token_0.contract_address, 
        stable_token_1.contract_address, 
        *uint(amount_stable_token_0), 
        *uint(amount_stable_token_1), 
        *uint(0), 
        *uint(0), 
        user_1_account.contract_address, 
        0
    ])
    amountA = execution_info.result.response[0]
    amountB = execution_info.result.response[2]
    liquidity = execution_info.result.response[4]
    print(f"{amountA}, {amountB}, {liquidity}")
    assert amountA == amount_stable_token_0
    assert amountB == amount_stable_token_1
    assert float(liquidity) == math.sqrt(amount_stable_token_0 * amount_stable_token_1) - MINIMUM_LIQUIDITY

    event_data = get_event_data(execution_info, "Mint")
    assert event_data

    sort_info = await router.sort_tokens(stable_token_0.contract_address, stable_token_1.contract_address).call()
    
    execution_info = await stable_pair.get_reserves().call()
    if (sort_info.result.token0 == stable_token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
    execution_info = await stable_pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1
    assert (total_supply + 1) * (total_supply + 1) > reserve_0 * reserve_1


    amount_stable_token_0 = 5 * (10 ** stable_token_0_decimals)
    amount_stable_token_1 = 4 * (10 ** stable_token_1_decimals)
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, stable_token_0.contract_address, 'approve', [router.contract_address, *uint(amount_stable_token_0)])
    await user_1_signer.send_transaction(user_1_account, stable_token_1.contract_address, 'approve', [router.contract_address, *uint(amount_stable_token_1)])

    ## Already used stable_pair, has liquidity
    print("Add liquidity to old stable_pair")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        stable_token_0.contract_address, 
        stable_token_1.contract_address, 
        *uint(amount_stable_token_0), 
        *uint(amount_stable_token_1), 
        *uint(0), 
        *uint(0), 
        user_1_account.contract_address, 
        0
    ])
    amountA = execution_info.result.response[0]
    amountB = execution_info.result.response[2]
    liquidity = execution_info.result.response[4]
    print(f"{amountA}, {amountB}, {liquidity}")

    event_data = get_event_data(execution_info, "Mint")
    assert event_data

    execution_info = await stable_pair.get_reserves().call()
    if (sort_info.result.token0 == stable_token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
    execution_info = await stable_pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1

    execution_info = await stable_token_0.balanceOf(user_1_account.contract_address).call()
    user_1_stable_token_0_balance = execution_info.result.balance[0]
    print(f"Check: depleted user balance for stable_token_0: {amount_to_mint_stable_token_0}, {user_1_stable_token_0_balance}, {reserve_0}")
    assert amount_to_mint_stable_token_0 - user_1_stable_token_0_balance == reserve_0

    execution_info = await stable_token_1.balanceOf(user_1_account.contract_address).call()
    user_1_stable_token_1_balance = execution_info.result.balance[0]
    print(f"Check: depleted user balance for stable_token_1: {amount_to_mint_stable_token_1}, {user_1_stable_token_1_balance}, {reserve_1}")
    assert amount_to_mint_stable_token_1 - user_1_stable_token_1_balance == reserve_1

    execution_info = await stable_pair.balanceOf(user_1_account.contract_address).call()
    user_1_stable_pair_balance = execution_info.result.balance[0]
    print(f"Check: user_1 liquidity + locked liquidity is total supply: {total_supply}, {user_1_stable_pair_balance}")
    assert total_supply == user_1_stable_pair_balance + MINIMUM_LIQUIDITY

    print("Approve required stable_pair tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, stable_pair.contract_address, 'approve', [router.contract_address, *uint(user_1_stable_pair_balance)])

    ## Remove liquidity completely
    print("Remove liquidity")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'remove_liquidity', [
        stable_token_0.contract_address, 
        stable_token_1.contract_address, 
        *uint(user_1_stable_pair_balance), 
        *uint(0), 
        *uint(0), 
        user_1_account.contract_address, 
        0
    ])
    amountA = execution_info.result.response[0]
    amountB = execution_info.result.response[2]
    print(f"{amountA}, {amountB}")

    event_data = get_event_data(execution_info, "Burn")
    assert event_data

    execution_info = await stable_pair.balanceOf(user_1_account.contract_address).call()
    user_1_stable_pair_balance = execution_info.result.balance[0]
    print("Check: user_1 balance is 0")
    assert user_1_stable_pair_balance == 0

    execution_info = await stable_pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"Check: total supply is minimum supply: {total_supply}")
    assert total_supply == MINIMUM_LIQUIDITY

    execution_info = await stable_pair.balanceOf(BURN_ADDRESS).call()
    burn_address_stable_pair_balance = execution_info.result.balance[0]
    print(f"Check: total supply is in burn address: {total_supply} {burn_address_stable_pair_balance}")
    assert total_supply == burn_address_stable_pair_balance

    execution_info = await stable_pair.get_reserves().call()
    if (sort_info.result.token0 == stable_token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1
