import pytest
from starkware.starknet.core.os.contract_address.contract_address import calculate_contract_address, calculate_contract_address_from_hash
from Crypto.Hash import keccak
from starkware.python.utils import to_bytes, from_bytes
from starkware.cairo.common.cairo_keccak.keccak_utils import keccak_func, keccak_f


@pytest.mark.asyncio
async def test_pair(pair, pair_name, pair_symbol):
    execution_info = await pair.name().call()
    assert execution_info.result[0] == pair_name
    execution_info = await pair.symbol().call()
    assert execution_info.result[0] == pair_symbol
    execution_info = await pair.decimals().call()
    assert execution_info.result[0] == 18


@pytest.mark.asyncio
async def test_pair_in_factory(factory, token_0, token_1, pair, other_pair):
    execution_info = await factory.get_pair(token_0.contract_address, token_1.contract_address).call()
    assert execution_info.result.pair == pair.contract_address

    execution_info = await factory.get_pair(token_1.contract_address, token_0.contract_address).call()
    assert execution_info.result.pair == pair.contract_address

    execution_info = await factory.get_all_pairs().call()
    assert execution_info.result.all_pairs == [
        pair.contract_address, other_pair.contract_address]


@pytest.mark.asyncio
async def test_factory_in_router(factory, router):
    execution_info = await router.factory().call()
    assert execution_info.result.address == factory.contract_address


@pytest.mark.asyncio
async def test_create2_deployed_pair(deployer, declared_pair_class, token_0, token_3, factory, router):

    """Test a factory deployed pair address with calculated pair address"""

    deployer_signer, deployer_account = deployer
    execution_info = await router.sort_tokens(token_0.contract_address, token_3.contract_address).call()

    sorted_token_0 = execution_info.result.token0
    sorted_token_1 = execution_info.result.token1
    salt = keccak.new(digest_bits=256)

    token0_byte_address = to_bytes(sorted_token_0, None, 'little')
    token1_byte_address = to_bytes(sorted_token_1, None, 'little')

    salt.update(token0_byte_address)
    salt.update(token1_byte_address)

    constructor_calldata = [sorted_token_0,
                            sorted_token_1, factory.contract_address]

    salt_int = from_bytes(salt.digest(), 'little')

    (salt_low, salt_high) = to_uint(salt_int)

    create2_pair_address = calculate_contract_address_from_hash(
        salt=salt_low, class_hash=declared_pair_class.class_hash, deployer_address=factory.contract_address, constructor_calldata=constructor_calldata)

    pair = await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'create_pair', [sorted_token_0, sorted_token_1])

    pair_address = pair.result.response[0]

    print("Create2 Pair address: {}, Actual address: {}". format(
        create2_pair_address, pair_address))

    assert create2_pair_address == pair_address

    return create2_pair_address


def to_uint(a):
    """Takes in value, returns uint256-ish tuple."""
    return (a & ((1 << 128) - 1), a >> 128)
