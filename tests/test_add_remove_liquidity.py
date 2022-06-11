import pytest
import math
from utils.events import get_event_data
from utils.revert import assert_revert
from utils.create2_address import get_create2_address
from starkware.starknet.business_logic.state.state import BlockInfo
from starkware.starknet.testing.starknet import StarknetContract


MINIMUM_LIQUIDITY = 1000
BURN_ADDRESS = 1


def uint(a):
    return(a, 0)


@pytest.mark.asyncio
async def test_add_liquidity_expired_deadline(starknet, router, token_0, token_1, user_1):
    user_1_signer, user_1_account = user_1

    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals

    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals

    amount_token_0 = 2 * (10 ** token_0_decimals)
    amount_token_1 = 4 * (10 ** token_1_decimals)

    starknet.state.state.block_info = BlockInfo.create_for_testing(1, 1)

    # New pair with 0 liquidity
    print("Add liquidity to new pair")
    await assert_revert(user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address,
        token_1.contract_address,
        *uint(amount_token_0),
        *uint(amount_token_1),
        *uint(0),
        *uint(0),
        user_1_account.contract_address,
        0
    ]), "Router::_ensure_deadline::expired")


@pytest.mark.asyncio
async def test_add_remove_liquidity(router, pair, token_0, token_1, user_1, random_acc):
    user_1_signer, user_1_account = user_1
    random_signer, random_account = random_acc

    print("\nMint loads of tokens to user_1")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 100 * (10 ** token_0_decimals)
    # Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])

    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 100 * (10 ** token_1_decimals)
    # Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_1)])

    amount_token_0 = 2 * (10 ** token_0_decimals)
    amount_token_1 = 4 * (10 ** token_1_decimals)
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_1_signer.send_transaction(user_1_account, token_1.contract_address, 'approve', [router.contract_address, *uint(amount_token_1)])

    # New pair with 0 liquidity
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
    assert float(liquidity) == pytest.approx(
        math.sqrt(amount_token_0 * amount_token_1) - MINIMUM_LIQUIDITY)

    event_data = get_event_data(execution_info, "Mint")
    assert event_data

    sort_info = await router.sort_tokens(token_0.contract_address, token_1.contract_address).call()

    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
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

    # Already used pair, has liquidity
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

    event_data = get_event_data(execution_info, "Mint")
    assert event_data

    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
    execution_info = await pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1

    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user_1_token_0_balance = execution_info.result.balance[0]
    print(
        f"Check: depleted user balance for token_0: {amount_to_mint_token_0}, {user_1_token_0_balance}, {reserve_0}")
    assert amount_to_mint_token_0 - user_1_token_0_balance == reserve_0

    execution_info = await token_1.balanceOf(user_1_account.contract_address).call()
    user_1_token_1_balance = execution_info.result.balance[0]
    print(
        f"Check: depleted user balance for token_1: {amount_to_mint_token_1}, {user_1_token_1_balance}, {reserve_1}")
    assert amount_to_mint_token_1 - user_1_token_1_balance == reserve_1

    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(
        f"Check: user_1 liquidity + locked liquidity is total supply: {total_supply}, {user_1_pair_balance}")
    assert total_supply == user_1_pair_balance + MINIMUM_LIQUIDITY

    print("Approve required pair tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, pair.contract_address, 'approve', [router.contract_address, *uint(user_1_pair_balance)])

    # Remove liquidity completely
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

    event_data = get_event_data(execution_info, "Burn")
    assert event_data

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
    print(
        f"Check: total supply is in burn address: {total_supply} {burn_address_pair_balance}")
    assert total_supply == burn_address_pair_balance

    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1


@pytest.mark.asyncio
async def test_add_remove_liquidity_for_new_pair(starknet, router, declared_pair_class, token_0, token_3, user_1, random_acc, factory):
    user_1_signer, user_1_account = user_1
    random_signer, random_account = random_acc

    print("\nMint loads of tokens to user_1")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 100 * (10 ** token_0_decimals)
    # Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])

    execution_info = await token_3.decimals().call()
    token_3_decimals = execution_info.result.decimals
    amount_to_mint_token_3 = 100 * (10 ** token_3_decimals)
    # Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_3.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_3)])

    amount_token_0 = 2 * (10 ** token_0_decimals)
    amount_token_3 = 4 * (10 ** token_3_decimals)
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_1_signer.send_transaction(user_1_account, token_3.contract_address, 'approve', [router.contract_address, *uint(amount_token_3)])

    # New pair with 0 liquidity
    print("Add liquidity to new pair")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address,
        token_3.contract_address,
        *uint(amount_token_0),
        *uint(amount_token_3),
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
    assert amountB == amount_token_3
    assert float(liquidity) == pytest.approx(
        math.sqrt(amount_token_0 * amount_token_3) - MINIMUM_LIQUIDITY)

    event_data = get_event_data(execution_info, "Mint")
    assert event_data

    sort_info = await router.sort_tokens(token_0.contract_address, token_3.contract_address).call()

    # Determine the pair address of newly created pair
    pair_address = get_create2_address(
        sort_info.result.token0, sort_info.result.token1, factory.contract_address, declared_pair_class.class_hash)

    pair = StarknetContract(
        starknet.state, declared_pair_class.abi, pair_address, None)

    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
    execution_info = await pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1
    assert (total_supply + 1) * (total_supply + 1) > reserve_0 * reserve_1

    amount_token_0 = 5 * (10 ** token_0_decimals)
    amount_token_3 = 4 * (10 ** token_3_decimals)
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_1_signer.send_transaction(user_1_account, token_3.contract_address, 'approve', [router.contract_address, *uint(amount_token_3)])

    # Already used pair, has liquidity
    print("Add liquidity to old pair")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address,
        token_3.contract_address,
        *uint(amount_token_0),
        *uint(amount_token_3),
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

    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
    execution_info = await pair.totalSupply().call()
    total_supply = execution_info.result.totalSupply[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1

    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user_1_token_0_balance = execution_info.result.balance[0]
    print(
        f"Check: depleted user balance for token_0: {amount_to_mint_token_0}, {user_1_token_0_balance}, {reserve_0}")
    assert amount_to_mint_token_0 - user_1_token_0_balance == reserve_0

    execution_info = await token_3.balanceOf(user_1_account.contract_address).call()
    user_1_token_3_balance = execution_info.result.balance[0]
    print(
        f"Check: depleted user balance for token_3: {amount_to_mint_token_3}, {user_1_token_3_balance}, {reserve_1}")
    assert amount_to_mint_token_3 - user_1_token_3_balance == reserve_1

    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(
        f"Check: user_1 liquidity + locked liquidity is total supply: {total_supply}, {user_1_pair_balance}")
    assert total_supply == user_1_pair_balance + MINIMUM_LIQUIDITY

    print("Approve required pair tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, pair.contract_address, 'approve', [router.contract_address, *uint(user_1_pair_balance)])

    # Remove liquidity completely
    print("Remove liquidity")
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'remove_liquidity', [
        token_0.contract_address,
        token_3.contract_address,
        *uint(user_1_pair_balance),
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
    print(
        f"Check: total supply is in burn address: {total_supply} {burn_address_pair_balance}")
    assert total_supply == burn_address_pair_balance

    execution_info = await pair.get_reserves().call()
    if (sort_info.result.token0 == token_0.contract_address):
        reserve_0 = execution_info.result.reserve0[0]
        reserve_1 = execution_info.result.reserve1[0]
    else:
        reserve_1 = execution_info.result.reserve0[0]
        reserve_0 = execution_info.result.reserve1[0]
    print(f"{reserve_0}, {reserve_1}, {total_supply}")
    assert total_supply * total_supply <= reserve_0 * reserve_1
