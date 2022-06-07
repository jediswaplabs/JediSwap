import pytest
import asyncio


def uint(a):
    return(a, 0)


async def initialize_pairs(factory, router, token_0, token_1, token_2, deployer, fee_recipient, user_1, random_acc):
    user_1_signer, user_1_account = user_1
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    print("Set fee to")
    await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'set_fee_to', [fee_recipient_account.contract_address])

    print("\nMint loads of tokens to user_1")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 100 * (10 ** token_0_decimals)
    # Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])

    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 100 * (10 ** token_1_decimals)
    # Mint token_1 to user_1
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_1)])

    execution_info = await token_2.decimals().call()
    token_2_decimals = execution_info.result.decimals
    amount_to_mint_token_2 = 100 * (10 ** token_2_decimals)
    # Mint token_2 to user_1
    await random_signer.send_transaction(random_account, token_2.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_2)])

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


async def mint_to_user_2(router, token_0, token_1, token_2, user_2, random_acc):
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc

    print("\nMint loads of tokens to user_2")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 100 * (10 ** token_0_decimals)
    # Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_0)])
    print("Approve required tokens to be spent by router")
    await user_2_signer.send_transaction(user_2_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_to_mint_token_0)])

    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 100 * (10 ** token_1_decimals)
    # Mint token_1 to user_2
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_1)])

    execution_info = await token_2.decimals().call()
    token_2_decimals = execution_info.result.decimals
    amount_to_mint_token_2 = 100 * (10 ** token_2_decimals)
    # Mint token_2 to user_2
    await random_signer.send_transaction(random_account, token_2.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_2)])


@pytest.mark.asyncio
async def test_protocol_fee(starknet, factory, router, token_0, token_1, token_2, pair, other_pair, deployer, fee_recipient, user_1, user_2, random_acc):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await initialize_pairs(factory, router, token_0, token_1, token_2, deployer, fee_recipient, user_1, random_acc)
    await mint_to_user_2(router, token_0, token_1, token_2, user_2, random_acc)

    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_token_0 = 2 * (10 ** token_0_decimals)
    print("Approve required tokens to be spent by router")
    await user_2_signer.send_transaction(user_2_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])

    # Swap
    print("Swap")
    execution_info = await user_2_signer.send_transaction(user_2_account, router.contract_address, 'swap_exact_tokens_for_tokens', [
        *uint(amount_token_0),
        *uint(0),
        2,
        token_0.contract_address,
        token_1.contract_address,
        user_2_account.contract_address,
        0
    ])

    amounts_len = execution_info.result.response[0]
    amounts = execution_info.result.response[1:]
    print(f"{amounts_len}, {amounts}")

    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    # print(f"Check: user_1 liquidity + locked liquidity is total supply: {total_supply}, {user_1_pair_balance}")

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

    execution_info = await pair.balanceOf(fee_recipient_account.contract_address).call()
    fee_recipient_pair_balance = execution_info.result.balance[0]
    print(f"Check: fee_recipient balance is : {fee_recipient_pair_balance}")
    assert fee_recipient_pair_balance > 0
