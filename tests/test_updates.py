import pytest
import asyncio
from utils.revert import assert_revert
from utils.events import get_event_data

@pytest.mark.asyncio
async def test_update_fee_to_non_owner(registry, random_acc, fee_recipient):
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await assert_revert(random_signer.send_transaction(random_account, registry.contract_address, 'update_fee_to', [fee_recipient_account.contract_address]), 
                        "Registry::_only_owner::Caller must be owner")

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

    await assert_revert(random_signer.send_transaction(random_account, registry.contract_address, 'initiate_ownership_transfer', [fee_recipient_account.contract_address]),
                        "Registry::_only_owner::Caller must be owner")

@pytest.mark.asyncio
async def test_update_owner_zero_address(registry, deployer):
    deployer_signer, deployer_account = deployer

    await assert_revert(deployer_signer.send_transaction(deployer_account, registry.contract_address, 'initiate_ownership_transfer', [0]),
                        "Registry::initiate_ownership_transfer::New owner can not be zero")

@pytest.mark.asyncio
async def test_update_owner(registry, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    execution_info = await deployer_signer.send_transaction(deployer_account, registry.contract_address, 'initiate_ownership_transfer', [fee_recipient_account.contract_address])
    event_data = get_event_data(execution_info, "owner_change_initiated")
    assert event_data
    assert event_data[0] == deployer_account.contract_address
    assert event_data[1] == fee_recipient_account.contract_address

    execution_info = await registry.future_owner().call()
    print(f"Check new future owner is {fee_recipient_account.contract_address}")
    assert execution_info.result.address == fee_recipient_account.contract_address

@pytest.mark.asyncio
async def test_accept_ownership_non_future_owner(registry, deployer, fee_recipient, random_acc):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient
    random_signer, random_account = random_acc

    execution_info = await deployer_signer.send_transaction(deployer_account, registry.contract_address, 'initiate_ownership_transfer', [fee_recipient_account.contract_address])
    
    await assert_revert(random_signer.send_transaction(random_account, registry.contract_address, 'accept_ownership', []),
                        "Registry::accept_ownership::Only future owner can accept")

@pytest.mark.asyncio
async def test_accept_ownership(registry, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    execution_info = await deployer_signer.send_transaction(deployer_account, registry.contract_address, 'initiate_ownership_transfer', [fee_recipient_account.contract_address])

    execution_info = await fee_recipient_signer.send_transaction(fee_recipient_account, registry.contract_address, 'accept_ownership', [])
    event_data = get_event_data(execution_info, "owner_change_completed")
    assert event_data
    assert event_data[0] == deployer_account.contract_address
    assert event_data[1] == fee_recipient_account.contract_address
    
    execution_info = await registry.owner().call()
    print(f"Check new owner is {fee_recipient_account.contract_address}")
    assert execution_info.result.address == fee_recipient_account.contract_address