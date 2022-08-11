# JediSwap

Clone of Uniswap V2 to Cairo. AMM for StarkNet.

## Testing and Development

### Dependencies
* [protostar](https://docs.swmansion.com/protostar/)

    To install protostar dependencies:
    ```
    protostar install
    ```

### Compile Contracts
```
protostar build
```

### Run Tests

To run protostar tests:
```
protostar test
```

### Run Scripts

#### Additional Dependencies

* [python3.8](https://www.python.org/downloads/release/python-3813/)
* [starknet-devnet](https://github.com/Shard-Labs/starknet-devnet)
* [starknet.py](https://github.com/software-mansion/starknet.py)

All scripts are placed in ```scripts``` folder. testnet config is not committed, please create your own in ```scripts/config```

To run scripts on local system, you first need to run a devnet server:
```
starknet-devnet
```

Example:
```
python scripts/deploy.py local
```