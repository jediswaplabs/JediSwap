# JediSwap

Clone of Uniswap V2 to Cairo. AMM for StarkNet.

## Testing and Development

### Dependencies

* [python3](https://www.python.org/downloads/release/python-3910/)
* [nile](https://github.com/OpenZeppelin/nile)
* [pytest-xdist](https://github.com/pytest-dev/pytest-xdist) (required for running tests in parallel)
* [openzeppelin-cairo-contracts](https://github.com/OpenZeppelin/cairo-contracts)


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

#### Additional Dependencies

* [starknet.py](https://github.com/software-mansion/starknet.py)

All scripts are placed in ```scripts``` folder. testnet config is not committed, please create your own in ```scripts/config```

Example:
```
python scripts/deploy.py local
```

To run scripts on local system, you need to run a devnet server:
```
starknet-devnet
```