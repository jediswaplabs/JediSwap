import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

index_name_string = "Mesh Generic Pair"
index_symbol_string = "MGP"

def uint(a):
    return(a, 0)

def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


@pytest.fixture
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture
async def starknet():
    starknet = await Starknet.empty()
    return starknet

@pytest.fixture
async def deployer(starknet):
    deployer_signer = Signer(123456789987654321)
    deployer_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[deployer_signer.public_key]
    )

    return deployer_signer, deployer_account

@pytest.fixture
async def random_acc(starknet):
    random_signer = Signer(987654320023456789)
    random_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[random_signer.public_key]
    )

    return random_signer, random_account

@pytest.fixture
async def user_1(starknet):
    user_1_signer = Signer(987654321123456789)
    user_1_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[user_1_signer.public_key]
    )

    return user_1_signer, user_1_account

@pytest.fixture
async def fee_recipient(starknet):
    fee_recipient_signer = Signer(987654301103456789)
    fee_recipient_account = await starknet.deploy(
        "contracts/test/Account.cairo",
        constructor_calldata=[fee_recipient_signer.public_key]
    )
    return fee_recipient_signer, fee_recipient_account

@pytest.fixture
async def token_0(starknet, random_acc):
    random_signer, random_account = random_acc
    token_0 = await starknet.deploy(
        "contracts/test/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Token 0"),  # name
            str_to_felt("TOKEN0"),  # symbol
            random_account.contract_address
        ]
    )
    return token_0

@pytest.fixture
async def token_1(starknet, random_acc):
    random_signer, random_account = random_acc
    token_1 = await starknet.deploy(
        "contracts/test/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Token 1"),  # name
            str_to_felt("TOKEN1"),  # symbol
            random_account.contract_address
        ]
    )
    return token_1

@pytest.fixture
async def pair_name():
    return str_to_felt(index_name_string)

@pytest.fixture
async def pair_symbol():
    return str_to_felt(index_symbol_string)

@pytest.fixture
async def registry(starknet, deployer):
    deployer_signer, deployer_account = deployer
    registry = await starknet.deploy("contracts/Registry.cairo")
    return registry

@pytest.fixture
async def router(starknet, deployer, registry):
    deployer_signer, deployer_account = deployer
    router = await starknet.deploy(
        "contracts/Router.cairo",
        constructor_calldata=[
            registry.contract_address
        ]
    )
    return router

@pytest.fixture
async def pair(starknet, deployer, pair_name, pair_symbol, token_0, token_1, registry):
    deployer_signer, deployer_account = deployer
    pair = await starknet.deploy(
        "contracts/Pair.cairo",
        constructor_calldata=[
            pair_name,  # name
            pair_symbol,  # symbol
            token_0.contract_address,   # token0
            token_1.contract_address,   # token1
            deployer_account.contract_address   # fee_setter
        ]
    )
    await deployer_signer.send_transaction(deployer_account, registry.contract_address, 'set_pair', [token_0.contract_address, token_1.contract_address, pair.contract_address])
    return pair