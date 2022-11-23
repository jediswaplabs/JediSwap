import asyncio
from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.account.account_client import AccountClient, KeyPair
from starknet_py.transactions.declare import make_declare_tx
from starknet_py.transactions.deploy import make_deploy_tx
from starknet_py.net.models import StarknetChainId
from pathlib import Path
from base_funcs import *
import sys
import requests
import os

os.environ['CAIRO_PATH'] = 'lib/cairo_contracts/src/'

tokens = []

async def main():
    network_arg = sys.argv[1]
    deploy_token = None

    if network_arg == 'local':
        local_network = "http://127.0.0.1:5050"
        current_client = GatewayClient({"feeder_gateway_url": f"{local_network}/feeder_gateway", "gateway_url": f"{local_network}/gateway"})
    elif network_arg == 'testnet':
        current_client = GatewayClient('testnet')
    if network_arg == 'testnet2':
        network_url = "https://alpha4-2.starknet.io"
        current_client = GatewayClient({"feeder_gateway_url": f"{network_url}/feeder_gateway", "gateway_url": f"{network_url}/gateway"})
    elif network_arg == 'mainnet':
        current_client = GatewayClient('mainnet')
        deploy_token = os.environ['DEPLOY_TOKEN']
    
    deploy_tx = make_deploy_tx(compiled_contract=Path("build/Multicall.json").read_text(), constructor_calldata=[])
    deployment_result = await current_client.deploy(deploy_tx, token=deploy_token)
    await current_client.wait_for_tx(deployment_result.transaction_hash)
    multicall_address = deployment_result.contract_address
    multicall = await Contract.from_address(multicall_address, current_client)
    print(f"Multicall deployed: {multicall.address}, {hex(multicall.address)}")


if __name__ == "__main__":
    asyncio.run(main())

