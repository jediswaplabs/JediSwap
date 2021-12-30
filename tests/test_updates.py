import pytest
import asyncio
from utils.revert import assert_revert

@pytest.mark.asyncio
async def test_update_fee_to_non_owner(registry, random_acc, fee_recipient):
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await assert_revert(random_signer.send_transaction(random_account, registry.contract_address, 'update_fee_to', [fee_recipient_account.contract_address]))

@pytest.mark.asyncio
async def test_update_fee_to_zero_address(registry, deployer):
    deployer_signer, deployer_account = deployer

    await assert_revert(deployer_signer.send_transaction(deployer_account, registry.contract_address, 'update_fee_to', [0]))

@pytest.mark.asyncio
async def test_update_fee_to(registry, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await deployer_signer.send_transaction(deployer_account, registry.contract_address, 'update_fee_to', [fee_recipient_account.contract_address])
    
    execution_info = await registry.fee_to().call()
    print(f"Check new fee to is {fee_recipient_account.contract_address}")
    assert execution_info.result.address == fee_recipient_account.contract_address


@pytest.mark.asyncio
async def test_update_owner_non_owner(registry, random_acc, fee_recipient):
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await assert_revert(random_signer.send_transaction(random_account, registry.contract_address, 'transfer_ownership', [fee_recipient_account.contract_address]))

@pytest.mark.asyncio
async def test_update_owner_zero_address(registry, deployer):
    deployer_signer, deployer_account = deployer

    await assert_revert(deployer_signer.send_transaction(deployer_account, registry.contract_address, 'transfer_ownership', [0]))

@pytest.mark.asyncio
async def test_update_owner(registry, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await deployer_signer.send_transaction(deployer_account, registry.contract_address, 'transfer_ownership', [fee_recipient_account.contract_address])
    
    execution_info = await registry.owner().call()
    print(f"Check new owner is {fee_recipient_account.contract_address}")
    assert execution_info.result.address == fee_recipient_account.contract_address