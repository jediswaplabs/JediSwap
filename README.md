# JediSwap

Clone of Uniswap V2 to Cairo. AMM for StarkNet.

## Testing and Development

### Setup a local virtual env

```
python -m venv ./venv
source ./venv/bin/activate
```

### Install dependencies

```
pip install -r requirements.txt
```

### Compile Contracts
```
nile compile
```

### Run Tests
```
pytest -s -v
```
To distribute tests across multiple CPUs to speed up test execution: 
```
pytest -s -v -n auto
```

### Run Scripts

All scripts are placed in ```scripts``` folder. 

Note: Testnet config is not committed, please create your own in ```scripts/config```

Example:
```
python scripts/deploy.py local
```

To run scripts on local system, you need to run a devnet server:
```
starknet-devnet
```

### Resources

* [python3](https://www.python.org/downloads/release/python-3910/)
* [cairo-lang](https://github.com/starkware-libs/cairo-lang)
* [nile](https://github.com/OpenZeppelin/nile)
* [openzeppelin-cairo-contracts](https://github.com/OpenZeppelin/cairo-contracts)
* [pytest](https://docs.pytest.org/en/7.1.x/)
* [pytest-xdist](https://github.com/pytest-dev/pytest-xdist) (required for running tests in parallel)
* [starknet.py](https://github.com/software-mansion/starknet.py)