import pytest
import asyncio
from utils.revert import assert_revert
from utils.events import get_event_data


@pytest.mark.asyncio
async def test_set_fee_to_non_fee_to_setter(factory, random_acc, fee_recipient):
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await assert_revert(random_signer.send_transaction(random_account, factory.contract_address, 'set_fee_to', [fee_recipient_account.contract_address]),
                        "Factory::set_fee_to::Caller must be fee to setter")


@pytest.mark.asyncio
async def test_set_fee_to(factory, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'set_fee_to', [fee_recipient_account.contract_address])

    execution_info = await factory.get_fee_to().call()
    print(f"Check new fee to is {fee_recipient_account.contract_address}")
    assert execution_info.result.address == fee_recipient_account.contract_address

@pytest.mark.asyncio
async def test_update_fee_to_setter_non_fee_to_setter(factory, random_acc, fee_recipient):
    random_signer, random_account = random_acc
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await assert_revert(random_signer.send_transaction(random_account, factory.contract_address, 'set_fee_to_setter', [fee_recipient_account.contract_address]),
                        "Factory::set_fee_to_setter::Caller must be fee to setter")

@pytest.mark.asyncio
async def test_update_fee_to_setter_zero(factory, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await assert_revert(deployer_signer.send_transaction(deployer_account, factory.contract_address, 'set_fee_to_setter', [0]),
     "Factory::set_fee_to_setter::new_fee_to_setter must be non zero")


@pytest.mark.asyncio
async def test_update_fee_to_setter(factory, deployer, fee_recipient):
    deployer_signer, deployer_account = deployer
    fee_recipient_signer, fee_recipient_account = fee_recipient

    await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'set_fee_to_setter', [fee_recipient_account.contract_address])

    execution_info = await factory.get_fee_to_setter().call()
    print(
        f"Check new fee to setter is {fee_recipient_account.contract_address}")
    assert execution_info.result.address == fee_recipient_account.contract_address
