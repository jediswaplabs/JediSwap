import os
import sysconfig
import pytest_asyncio
import asyncio
from starkware.starknet.testing.starknet import Starknet, StarknetContract
from utils.Signer import MockSigner
from utils.contract_class import get_contract_class

pair_name_string = "JediSwap Pair"
pair_symbol_string = "JEDI-P"

oz_lib_path = sysconfig.get_paths()["purelib"]
oz_account_contract_path = os.path.join(oz_lib_path, 'openzeppelin/account/presets/Account.cairo')
oz_token_contract_path = os.path.join(oz_lib_path, 'openzeppelin/token/erc20/presets/ERC20Mintable.cairo')


def uint(a):
    return(a, 0)


def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


@pytest_asyncio.fixture
def event_loop():
    return asyncio.new_event_loop()


@pytest_asyncio.fixture
async def starknet():
    starknet = await Starknet.empty()
    return starknet


@pytest_asyncio.fixture
async def deployer(starknet):
    deployer_signer = MockSigner(123456789987654321)
    deployer_account = await starknet.deploy(
        oz_account_contract_path,
        constructor_calldata=[deployer_signer.public_key]
    )

    return deployer_signer, deployer_account


@pytest_asyncio.fixture
async def random_acc(starknet):
    random_signer = MockSigner(987654320023456789)
    random_account = await starknet.deploy(
        oz_account_contract_path,
        constructor_calldata=[random_signer.public_key]
    )

    return random_signer, random_account


@pytest_asyncio.fixture
async def user_1(starknet):
    user_1_signer = MockSigner(987654321123456789)
    user_1_account = await starknet.deploy(
        oz_account_contract_path,
        constructor_calldata=[user_1_signer.public_key]
    )

    return user_1_signer, user_1_account


@pytest_asyncio.fixture
async def user_2(starknet):
    user_2_signer = MockSigner(987654331133456789)
    user_2_account = await starknet.deploy(
        oz_account_contract_path,
        constructor_calldata=[user_2_signer.public_key]
    )

    return user_2_signer, user_2_account


@pytest_asyncio.fixture
async def fee_recipient(starknet):
    fee_recipient_signer = MockSigner(987654301103456789)
    fee_recipient_account = await starknet.deploy(
        oz_account_contract_path,
        constructor_calldata=[fee_recipient_signer.public_key]
    )
    return fee_recipient_signer, fee_recipient_account


@pytest_asyncio.fixture
async def token_0(starknet, random_acc):
    random_signer, random_account = random_acc
    token_0 = await starknet.deploy(
        oz_token_contract_path,
        constructor_calldata=[
            str_to_felt("Token 0"),  # name
            str_to_felt("TOKEN0"),  # symbol
            18,                     # decimals
            *uint(1000),            # initial supply
            random_account.contract_address,
            random_account.contract_address
        ]
    )
    return token_0


@pytest_asyncio.fixture
async def token_1(starknet, random_acc):
    random_signer, random_account = random_acc
    token_1 = await starknet.deploy(
        oz_token_contract_path,
        constructor_calldata=[
            str_to_felt("Token 1"),  # name
            str_to_felt("TOKEN1"),  # symbol
            6,                     # decimals
            *uint(1000),           # initial supply
            random_account.contract_address,
            random_account.contract_address
        ]
    )
    return token_1


@pytest_asyncio.fixture
async def token_2(starknet, random_acc):
    random_signer, random_account = random_acc
    token_2 = await starknet.deploy(
        oz_token_contract_path,
        constructor_calldata=[
            str_to_felt("Token 2"),  # name
            str_to_felt("TOKEN2"),  # symbol
            18,                     # decimals
            *uint(1000),            # initial supply
            random_account.contract_address,
            random_account.contract_address
        ]
    )
    return token_2


@pytest_asyncio.fixture
async def token_3(starknet, random_acc):
    random_signer, random_account = random_acc
    token_3 = await starknet.deploy(
        oz_token_contract_path,
        constructor_calldata=[
            str_to_felt("Token 3"),  # name
            str_to_felt("TOKEN3"),  # symbol
            18,                     # decimals
            *uint(1000),            # initial supply
            random_account.contract_address,
            random_account.contract_address
        ]
    )
    return token_3


@pytest_asyncio.fixture
async def pair_name():
    return str_to_felt(pair_name_string)


@pytest_asyncio.fixture
async def pair_symbol():
    return str_to_felt(pair_symbol_string)


@pytest_asyncio.fixture
async def declared_pair_class(starknet):
    pair_contract_class = get_contract_class("Pair.json")
    declared_pair_class = await starknet.declare(contract_class=pair_contract_class)
    return declared_pair_class


@pytest_asyncio.fixture
async def factory(starknet, deployer, declared_pair_class):
    deployer_signer, deployer_account = deployer

    factory = await starknet.deploy("contracts/Factory.cairo",
     constructor_calldata=[
        declared_pair_class.class_hash,
        deployer_account.contract_address
    ])

    return factory


@pytest_asyncio.fixture
async def router(starknet, factory):
    router = await starknet.deploy(
        "contracts/Router.cairo",
        constructor_calldata=[
            factory.contract_address
        ]
    )
    return router


@pytest_asyncio.fixture
async def pair(starknet, deployer, declared_pair_class, token_0, token_1, router, factory):
    deployer_signer, deployer_account = deployer
    execution_info = await router.sort_tokens(token_0.contract_address, token_1.contract_address).call()
    pair = await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'create_pair', [execution_info.result.token0, execution_info.result.token1])
    pair_address = pair.result.response[0]
    return StarknetContract(starknet.state, declared_pair_class.abi, pair_address, None)


@pytest_asyncio.fixture
async def other_pair(starknet, deployer, declared_pair_class, token_1, token_2, router, factory):
    deployer_signer, deployer_account = deployer
    execution_info = await router.sort_tokens(token_1.contract_address, token_2.contract_address).call()
    other_pair = await deployer_signer.send_transaction(deployer_account, factory.contract_address, 'create_pair', [execution_info.result.token0, execution_info.result.token1])
    other_pair_address = other_pair.result.response[0]
    return StarknetContract(starknet.state, declared_pair_class.abi, other_pair_address, None)


@pytest_asyncio.fixture
async def flash_swap_test(starknet, factory):
    flash_swap_test = await starknet.deploy(
        "contracts/test/FlashSwapTest.cairo",
        constructor_calldata=[
            factory.contract_address
        ]
    )
    return flash_swap_test
