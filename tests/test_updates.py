import pytest
import asyncio
from utils.revert import assert_revert

@pytest.mark.asyncio
async def test_update_fee_to_non_fee_setter(pair, random_acc, fee_recipient):
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await assert_revert(random_signer.send_transaction(random_account, pair.contract_address, 'update_fee_to', [fee_recipient_account.contract_address]))

@pytest.mark.asyncio
async def test_update_fee_to_zero_address(pair, deployer):
    deployer_signer, deployer_account = deployer

    await assert_revert(deployer_signer.send_transaction(deployer_account, pair.contract_address, 'update_fee_to', [0]))

@pytest.mark.asyncio
async def test_update_fee_to(pair, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await deployer_signer.send_transaction(deployer_account, pair.contract_address, 'update_fee_to', [fee_recipient_account.contract_address])
    
    execution_info = await pair.fee_to().call()
    print(f"Check new fee to is {fee_recipient_account.contract_address}")
    assert execution_info.result.address == fee_recipient_account.contract_address


@pytest.mark.asyncio
async def test_update_fee_setter_non_fee_setter(pair, random_acc, fee_recipient):
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await assert_revert(random_signer.send_transaction(random_account, pair.contract_address, 'update_fee_setter', [fee_recipient_account.contract_address]))

@pytest.mark.asyncio
async def test_update_fee_setter_zero_address(pair, deployer):
    deployer_signer, deployer_account = deployer

    await assert_revert(deployer_signer.send_transaction(deployer_account, pair.contract_address, 'update_fee_setter', [0]))

@pytest.mark.asyncio
async def test_update_fee_setter(pair, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await deployer_signer.send_transaction(deployer_account, pair.contract_address, 'update_fee_setter', [fee_recipient_account.contract_address])
    
    execution_info = await pair.fee_setter().call()
    print(f"Check new fee setter is {fee_recipient_account.contract_address}")
    assert execution_info.result.address == fee_recipient_account.contract_address