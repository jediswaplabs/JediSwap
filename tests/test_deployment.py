import pytest
from starkware.starknet.core.os.contract_address.contract_address import calculate_contract_address
# from utils.calculate_class_hash import get_contract_class
# from Crypto.Hash import keccak
# from starkware.python.utils import to_bytes


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

# TODO: Fix this test
# @pytest.mark.asyncio
# async def test_create2_deployed_pair(starknet, deployer, token_0, token_3, factory, router):

#     deployer_signer, deployer_account = deployer
#     execution_info = await router.sort_tokens(token_0.contract_address, token_3.contract_address).call()

#     sorted_token_0 = str(execution_info.result.token0)

#     print("Sorted Token 0: {}".format(sorted_token_0))

#     sorted_token_3 = str(execution_info.result.token1)

#     print("Sorted Token 3: {}".format(sorted_token_3))

#     pair_contract_class = get_contract_class('Pair_compiled.json')

#     salt = keccak.new(digest_bits=256)

#     tokens = bytearray(sorted_token_0 + sorted_token_3)

#     print("Token Byte Array: {}".format(tokens))

#     salt.update(tokens)

#     constructor_calldata = [sorted_token_0,
#                             sorted_token_3, factory.contract_address]

#     create2_pair_address = calculate_contract_address(
#         salt=salt, contract_class=pair_contract_class, deployer_address=deployer_account.contract_address, constructor_calldata=constructor_calldata)

#     print("Create2 Pair address: {}". format(create2_pair_address))

#     return create2_pair_address
