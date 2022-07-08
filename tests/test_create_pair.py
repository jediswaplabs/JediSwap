import pytest
from starkware.cairo.lang.vm.crypto import pedersen_hash

from utils.revert import assert_revert
from utils.create2_address import get_create2_address


@pytest.mark.asyncio
async def test_create2_deployed_pair(deployer, declared_pair_class, token_0, token_3, factory, router):

    """Test a factory deployed pair address with calculated pair address"""

    deployer_signer, deployer_account = deployer
    execution_info = await router.sort_tokens(token_0.contract_address, token_3.contract_address).call()

    sorted_token_0 = execution_info.result.token0
    sorted_token_1 = execution_info.result.token1

    create2_pair_address = get_create2_address(sorted_token_0, sorted_token_1, factory.contract_address, declared_pair_class.class_hash)

    pair = await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'create_pair', [sorted_token_0, sorted_token_1])

    pair_address = pair.result.response[0]

    print("Create2 Pair address: {}, Actual address: {}". format(
        create2_pair_address, pair_address))

    assert create2_pair_address == pair_address


@pytest.mark.asyncio
async def test_create_pair_without_tokens(deployer, factory, token_0):
    deployer_signer, deployer_account = deployer

    """ Should revert if no tokens are passed """
    await assert_revert(deployer_signer.send_transaction(
        deployer_account, factory.contract_address, 'create_pair', [0, 0]), "Factory::create_pair::tokenA and tokenB must be non zero")

    """Should revert if single token is passed  """
    await assert_revert(deployer_signer.send_transaction(
        deployer_account, factory.contract_address, 'create_pair', [token_0.contract_address, 0]), "Factory::create_pair::tokenA and tokenB must be non zero")


@pytest.mark.asyncio
async def test_create_pair_same_tokens(deployer, factory, token_0, token_3):
    deployer_signer, deployer_account = deployer

    """Should revert if both tokens are same"""
    await assert_revert(deployer_signer.send_transaction(
        deployer_account, factory.contract_address, 'create_pair', [token_0.contract_address, token_0.contract_address]), "Factory::create_pair::tokenA and tokenB must be different")


@pytest.mark.asyncio
async def test_create_pair_same_pair(deployer, factory, token_0, token_3):
    deployer_signer, deployer_account = deployer

    token_0_contract_address = token_0.contract_address
    token_3_contract_address = token_3.contract_address

    """ Pair created using token0 and token3 should pass"""
    pair = await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'create_pair', [token_0_contract_address, token_3_contract_address])

    pair_address = pair.result.response[0]

    assert pair_address != 0

    """Pair created with same tokens in different order(or same order) token3-token1 should revert"""
    await assert_revert(deployer_signer.send_transaction(deployer_account, factory.contract_address, 'create_pair', [token_3_contract_address, token_0_contract_address]), "Factory::create_pair::pair already exists for tokenA and tokenB")

    await assert_revert(deployer_signer.send_transaction(deployer_account, factory.contract_address, 'create_pair', [token_0_contract_address, token_3_contract_address]), "Factory::create_pair::pair already exists for tokenA and tokenB")


@pytest.mark.asyncio
async def test_create_pair_performance(deployer, token_0, token_1, router, factory):
    deployer_signer, deployer_account = deployer
    execution_info = await router.sort_tokens(token_0.contract_address, token_1.contract_address).call()
    pair = await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'create_pair', [execution_info.result.token0, execution_info.result.token1])
    print(pair.call_info.execution_resources)


@pytest.mark.asyncio
async def test_salt():
    sorted_token_0 = 2087021424722619777119509474943472645767659996348769578120564519014510906823
    sorted_token_1 = 1767481910113252210994791615708990276342505294349567333924577048691453030089
    salt = pedersen_hash(sorted_token_0, sorted_token_1)
    print("Salt: {}".format(str(salt)))

    assert salt == 3190531016477750283662426342216626187248855880035896941162231379006066586650
