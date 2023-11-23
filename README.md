# JediSwap

Clone of Uniswap V2 to Cairo. AMM for StarkNet.

## Testing and Development

We use [Starknet Foundry](https://github.com/foundry-rs/starknet-foundry) for our testing and development purposes. 
Starknet Foundry is a StarkNet smart contract development toolchain, which helps you with dependencies management, compiling and testing cairo contracts.

### Install Starknet Foundry

#### Note:
You may need to install a specific version of Scarb and Starknet Foundry

1. Install [Scarb](https://docs.swmansion.com/scarb/download.html)
2. Copy and run in a terminal the following commands:
```
curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
```
Follow the instructions and then run:
```
snfoundryup
```
3. Restart the terminal.
4. Run `snforge --version` to check the Starknet Foundry version.
5. Run `scarb --version` to check the Cairo version.

### Compile Contracts
TODO

### Run Tests
1. In the `Scarb.toml` file insert the Starknet Mainnet RPC endpint to the `url` object of the `Fork` section. You can use [Alchemy](https://www.alchemy.com/) or [Infura](https://www.infura.io/)
2. Run tests:
```
snforge test
```

### Run Scripts


#### Setup a local virtual env

```
python -m venv ./venv
source ./venv/bin/activate
```

#### Install dependencies
```
pip install -r requirements.txt
```

Find more info about the installed dependencies here:
* [starknet-devnet](https://github.com/Shard-Labs/starknet-devnet)
* [starknet.py](https://github.com/software-mansion/starknet.py)


#### Run Scripts

All scripts are placed in ```scripts``` folder. testnet config is not committed, please create your own in ```scripts/config```

To run scripts on local system, you first need to run a devnet server:
```
starknet-devnet
```

Run script by specifying the path to the script file. Example:
```
python scripts/deploy.py local
```