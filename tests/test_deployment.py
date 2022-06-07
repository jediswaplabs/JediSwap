import pytest
import asyncio


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
