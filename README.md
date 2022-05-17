# JediSwap

Clone of Uniswap V2 to Cairo. AMM for StarkNet.

## Testing and Development

### Dependencies

* [python3](https://www.python.org/downloads/release/python-3910/)
* [nile](https://github.com/OpenZeppelin/nile)
* [pytest-xdist](https://github.com/pytest-dev/pytest-xdist) (required for running tests in parallel)


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