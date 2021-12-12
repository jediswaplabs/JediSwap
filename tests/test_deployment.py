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
async def test_pair_in_registry(registry, token_0, token_1, pair):
    execution_info = await registry.get_pair_for(token_0.contract_address, token_1.contract_address).call()
    assert execution_info.result.pair == pair.contract_address

    execution_info = await registry.get_pair_for(token_1.contract_address, token_0.contract_address).call()
    assert execution_info.result.pair == pair.contract_address

@pytest.mark.asyncio
async def test_registry_in_router(registry, router):
    execution_info = await router.registry().call()
    assert execution_info.result.address == registry.contract_address