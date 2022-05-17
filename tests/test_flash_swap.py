import pytest
import asyncio
from utils.revert import assert_revert
from utils.events import get_event_data

def uint(a):
    return(a, 0)


async def initialize_pair(router, token_0, token_1, user_1, random_acc):
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
    ## Mint token_1 to user_1
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_1)])

    amount_token_0 = 20 * (10 ** token_0_decimals)
    amount_token_1 = 40 * (10 ** token_1_decimals)
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

@pytest.mark.asyncio
async def test_flash_swap_not_enough_liquidity(router, token_0, token_1, pair, user_1, user_2, random_acc, flash_swap_test):
    user_2_signer, user_2_account = user_2

    await initialize_pair(router, token_0, token_1, user_1, random_acc)

    execution_info = await token_0.balanceOf(user_2_account.contract_address).call()
    user_2_token_0_balance_initial = execution_info.result.balance[0]

    execution_info = await token_1.balanceOf(user_2_account.contract_address).call()
    user_2_token_1_balance_initial = execution_info.result.balance[0]

    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_token_0 = 200 * (10 ** token_0_decimals)
    
    sort_info = await router.sort_tokens(token_0.contract_address, token_1.contract_address).call()
    
    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0_initial = execution_info.result.reserve0[0]
        reserve_1_initial = execution_info.result.reserve1[0]
        swap_call_data = [
            *uint(amount_token_0), 
            *uint(0), 
            flash_swap_test.contract_address, 
            1,
            0
            ]
    else:
        reserve_1_initial = execution_info.result.reserve0[0]
        reserve_0_initial = execution_info.result.reserve1[0]
        swap_call_data = [ 
            *uint(0), 
            *uint(amount_token_0),
            flash_swap_test.contract_address, 
            1,
            0
            ]

    print(f"Initial balances: {user_2_token_0_balance_initial}, {user_2_token_1_balance_initial}, {reserve_0_initial}, {reserve_1_initial}")

    ## Swap
    print("Flash Swap")
    await assert_revert(user_2_signer.send_transaction(user_2_account, pair.contract_address, 'swap', swap_call_data),
                        "Pair::swap::insufficient liquidity")

@pytest.mark.asyncio
async def test_flash_swap_no_repayment(router, token_0, token_1, pair, user_1, user_2, random_acc, flash_swap_test):
    user_2_signer, user_2_account = user_2

    await initialize_pair(router, token_0, token_1, user_1, random_acc)

    execution_info = await token_0.balanceOf(user_2_account.contract_address).call()
    user_2_token_0_balance_initial = execution_info.result.balance[0]

    execution_info = await token_1.balanceOf(user_2_account.contract_address).call()
    user_2_token_1_balance_initial = execution_info.result.balance[0]

    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_token_0 = 2 * (10 ** token_0_decimals)
    
    sort_info = await router.sort_tokens(token_0.contract_address, token_1.contract_address).call()
    
    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0_initial = execution_info.result.reserve0[0]
        reserve_1_initial = execution_info.result.reserve1[0]
        swap_call_data = [
            *uint(amount_token_0), 
            *uint(0), 
            flash_swap_test.contract_address, 
            1,
            0
            ]
    else:
        reserve_1_initial = execution_info.result.reserve0[0]
        reserve_0_initial = execution_info.result.reserve1[0]
        swap_call_data = [ 
            *uint(0), 
            *uint(amount_token_0),
            flash_swap_test.contract_address, 
            1,
            0
            ]

    print(f"Initial balances: {user_2_token_0_balance_initial}, {user_2_token_1_balance_initial}, {reserve_0_initial}, {reserve_1_initial}")

    ## Swap
    print("Flash Swap")
    await assert_revert(user_2_signer.send_transaction(user_2_account, pair.contract_address, 'swap', swap_call_data),
                        "Pair::swap::invariant K")

@pytest.mark.asyncio
async def test_flash_swap_not_enough_repayment(router, token_0, token_1, pair, user_1, user_2, random_acc, flash_swap_test):
    user_2_signer, user_2_account = user_2

    await initialize_pair(router, token_0, token_1, user_1, random_acc)

    execution_info = await token_0.balanceOf(user_2_account.contract_address).call()
    user_2_token_0_balance_initial = execution_info.result.balance[0]

    execution_info = await token_1.balanceOf(user_2_account.contract_address).call()
    user_2_token_1_balance_initial = execution_info.result.balance[0]

    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_token_0 = 2 * (10 ** token_0_decimals)
    
    sort_info = await router.sort_tokens(token_0.contract_address, token_1.contract_address).call()
    
    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0_initial = execution_info.result.reserve0[0]
        reserve_1_initial = execution_info.result.reserve1[0]
        swap_call_data = [
            *uint(amount_token_0), 
            *uint(0), 
            flash_swap_test.contract_address, 
            1,
            0
            ]
    else:
        reserve_1_initial = execution_info.result.reserve0[0]
        reserve_0_initial = execution_info.result.reserve1[0]
        swap_call_data = [ 
            *uint(0), 
            *uint(amount_token_0),
            flash_swap_test.contract_address, 
            1,
            0
            ]

    print(f"Initial balances: {user_2_token_0_balance_initial}, {user_2_token_1_balance_initial}, {reserve_0_initial}, {reserve_1_initial}")

    amount_to_mint_token_0 = int(amount_token_0 * 0.2 / 100)
    ## Mint token_0 to flash swap contract
    random_signer, random_account = random_acc
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [flash_swap_test.contract_address, *uint(amount_to_mint_token_0)])

    ## Swap
    print("Flash Swap")
    await assert_revert(user_2_signer.send_transaction(user_2_account, pair.contract_address, 'swap', swap_call_data),
                        "Pair::swap::invariant K")

@pytest.mark.asyncio
async def test_flash_swap_same_token_repayment(router, token_0, token_1, pair, user_1, user_2, random_acc, flash_swap_test):
    user_2_signer, user_2_account = user_2

    await initialize_pair(router, token_0, token_1, user_1, random_acc)

    execution_info = await token_0.balanceOf(user_2_account.contract_address).call()
    user_2_token_0_balance_initial = execution_info.result.balance[0]

    execution_info = await token_1.balanceOf(user_2_account.contract_address).call()
    user_2_token_1_balance_initial = execution_info.result.balance[0]

    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_token_0 = 2 * (10 ** token_0_decimals)
    
    sort_info = await router.sort_tokens(token_0.contract_address, token_1.contract_address).call()
    
    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0_initial = execution_info.result.reserve0[0]
        reserve_1_initial = execution_info.result.reserve1[0]
        swap_call_data = [
            *uint(amount_token_0), 
            *uint(0), 
            flash_swap_test.contract_address, 
            1,
            0
            ]
    else:
        reserve_1_initial = execution_info.result.reserve0[0]
        reserve_0_initial = execution_info.result.reserve1[0]
        swap_call_data = [ 
            *uint(0), 
            *uint(amount_token_0),
            flash_swap_test.contract_address, 
            1,
            0
            ]

    print(f"Initial balances: {user_2_token_0_balance_initial}, {user_2_token_1_balance_initial}, {reserve_0_initial}, {reserve_1_initial}")

    amount_to_mint_token_0 = int(amount_token_0 * 0.4 / 100)
    ## Mint token_0 to flash swap contract
    random_signer, random_account = random_acc
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [flash_swap_test.contract_address, *uint(amount_to_mint_token_0)])

    ## Swap
    print("Flash Swap")
    execution_info = await user_2_signer.send_transaction(user_2_account, pair.contract_address, 'swap', swap_call_data)

    event_data = get_event_data(execution_info, "Swap")
    assert event_data

    execution_info = await token_0.balanceOf(user_2_account.contract_address).call()
    user_2_token_0_balance_final = execution_info.result.balance[0]

    execution_info = await token_1.balanceOf(user_2_account.contract_address).call()
    user_2_token_1_balance_final = execution_info.result.balance[0]

    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0_final = execution_info.result.reserve0[0]
        reserve_1_final = execution_info.result.reserve1[0]
    else:
        reserve_1_final = execution_info.result.reserve0[0]
        reserve_0_final = execution_info.result.reserve1[0]

    print(f"Final balances: {user_2_token_0_balance_final}, {user_2_token_1_balance_final}, {reserve_0_final}, {reserve_1_final}")

    expected_amount_1 = (amount_token_0 * reserve_1_initial) / (amount_token_0 + reserve_0_initial)
    print(f"Expected amount for token_1: {expected_amount_1}")


@pytest.mark.asyncio
async def test_flash_swap_other_token_repayment(router, token_0, token_1, pair, user_1, user_2, random_acc, flash_swap_test):
    user_2_signer, user_2_account = user_2

    await initialize_pair(router, token_0, token_1, user_1, random_acc)

    execution_info = await token_0.balanceOf(user_2_account.contract_address).call()
    user_2_token_0_balance_initial = execution_info.result.balance[0]

    execution_info = await token_1.balanceOf(user_2_account.contract_address).call()
    user_2_token_1_balance_initial = execution_info.result.balance[0]

    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_token_0 = 2 * (10 ** token_0_decimals)
    
    sort_info = await router.sort_tokens(token_0.contract_address, token_1.contract_address).call()
    
    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0_initial = execution_info.result.reserve0[0]
        reserve_1_initial = execution_info.result.reserve1[0]
        swap_call_data = [
            *uint(amount_token_0), 
            *uint(0), 
            flash_swap_test.contract_address, 
            1,
            0
            ]
    else:
        reserve_1_initial = execution_info.result.reserve0[0]
        reserve_0_initial = execution_info.result.reserve1[0]
        swap_call_data = [ 
            *uint(0), 
            *uint(amount_token_0),
            flash_swap_test.contract_address, 
            1,
            0
            ]

    print(f"Initial balances: {user_2_token_0_balance_initial}, {user_2_token_1_balance_initial}, {reserve_0_initial}, {reserve_1_initial}")

    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_token_1 = 4 * (10 ** token_1_decimals)
    amount_to_mint_token_1 = int(amount_token_1 * 0.4 / 100)
    ## Mint token_0 to flash swap contract
    random_signer, random_account = random_acc
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [flash_swap_test.contract_address, *uint(amount_to_mint_token_1)])

    ## Swap
    print("Flash Swap")
    execution_info = await user_2_signer.send_transaction(user_2_account, pair.contract_address, 'swap', swap_call_data)

    event_data = get_event_data(execution_info, "Swap")
    assert event_data

    execution_info = await token_0.balanceOf(user_2_account.contract_address).call()
    user_2_token_0_balance_final = execution_info.result.balance[0]

    execution_info = await token_1.balanceOf(user_2_account.contract_address).call()
    user_2_token_1_balance_final = execution_info.result.balance[0]

    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0_final = execution_info.result.reserve0[0]
        reserve_1_final = execution_info.result.reserve1[0]
    else:
        reserve_1_final = execution_info.result.reserve0[0]
        reserve_0_final = execution_info.result.reserve1[0]

    print(f"Final balances: {user_2_token_0_balance_final}, {user_2_token_1_balance_final}, {reserve_0_final}, {reserve_1_final}")

    expected_amount_1 = (amount_token_0 * reserve_1_initial) / (amount_token_0 + reserve_0_initial)
    print(f"Expected amount for token_1: {expected_amount_1}")
