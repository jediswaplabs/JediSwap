// @title JediSwap V2 Factory Cairo 1.0
// @author Mesh Finance
// @license MIT
// @notice Factory to create and register new pairs

#[contract]
mod FactoryC1 {
    use array::ArrayTrait;
    use zeroable::Zeroable;
    // use starknet::PartialOrd;
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::ClassHash;
    use starknet::ClassHashZeroable;
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::contract_address_to_felt252;
    use starknet::class_hash::class_hash_to_felt252;
    use integer::u256_from_felt252;
    use starknet::syscalls::deploy_syscall;



    //
    // Storage
    //

    struct Storage {
        _fee_to: ContractAddress,       // @dev Address of fee recipient
        _fee_to_setter: ContractAddress,        // @dev Address allowed to change feeTo.
        _all_pairs: LegacyMap::<u32, ContractAddress>,     // @dev Array of all pairs
        _pair: LegacyMap::<(ContractAddress, ContractAddress), ContractAddress>,    // @dev Pair address for pair of `token0` and `token1`
        _num_of_pairs: u32,    // @dev Total pairs
        _pair_proxy_contract_class_hash: ClassHash,
        _pair_contract_class_hash: ClassHash
    }

    // @dev Emitted each time a pair is created via createPair
    // token0 is guaranteed to be strictly less than token1 by sort order.
    #[event]
    fn PairCreated(token0: ContractAddress, token1: ContractAddress, pair: ContractAddress, total_pairs: u32) {}

    //
    // Constructor
    //

    // @notice Contract constructor
    // @param fee_to_setter Fee Recipient Setter
    #[external]
    fn initializer(pair_proxy_contract_class_hash: ClassHash, pair_contract_class_hash: ClassHash, fee_to_setter: ContractAddress) {
        
        assert(!fee_to_setter.is_zero(), 'can not be zero');

        assert(!pair_proxy_contract_class_hash.is_zero(), 'can not be zero');

        assert(!pair_contract_class_hash.is_zero(), 'can not be zero');

        _fee_to_setter::write(fee_to_setter);
        _pair_proxy_contract_class_hash::write(pair_proxy_contract_class_hash);
        _pair_contract_class_hash::write(pair_contract_class_hash);
        _num_of_pairs::write(0_u32);
        // Proxy.initializer(fee_to_setter);   //TODO proxy integration
    }

    //
    // Getters
    //

    // @notice Get pair address for the pair of `token0` and `token1`
    // @param token0 Address of token0
    // @param token1 Address of token1
    // @return pair Address of the pair
    #[view]
    fn get_pair(token0: ContractAddress, token1: ContractAddress) -> ContractAddress {
        let pair_0_1 = _pair::read((token0, token1));
        if (pair_0_1 == contract_address_const::<0>()) {
            let pair_1_0 = _pair::read((token1, token0));
            return pair_1_0;
        } else {
            return pair_0_1;
        }
    }

    // @notice Get all the pairs registered
    // @return all_pairs_len Length of `all_pairs` array
    // @return all_pairs Array of addresses of the registered pairs
    #[view]
    fn get_all_pairs() -> (u32, Array::<ContractAddress>) {  //Array::<ContractAddress>
        let mut all_pairs_array = ArrayTrait::<ContractAddress>::new();
        let num_pairs = _num_of_pairs::read();
        let mut current_index = 0_u32;
        loop {
            match gas::withdraw_gas_all(get_builtin_costs()) {
                Option::Some(_) => {
                },
                Option::None(_) => {
                    let mut err_data = array::array_new();
                    array::array_append(ref err_data, 'Out of gas');
                    panic(err_data)
                },
            }

            if current_index == num_pairs {
                break true;
            }
            all_pairs_array.append(_all_pairs::read(current_index));
            current_index += 1_u32;
        };
        (num_pairs, all_pairs_array)
    }

    // @notice Get the number of pairs
    // @return num_of_pairs
    #[view]
    fn get_num_of_pairs() -> u32 {
        _num_of_pairs::read()
    }

    // @notice Get fee recipient address
    // @return address
    #[view]
    fn get_fee_to() -> ContractAddress {
        _fee_to::read()
    }

    // @notice Get the address allowed to change fee_to.
    // @return address
    #[view]
    fn get_fee_to_setter() -> ContractAddress {
        _fee_to_setter::read()
    }

    // @notice Get the class hash of the Pair contract which is deployed for each pair.
    // @return class_hash
    #[view]
    fn get_pair_contract_class_hash() -> ClassHash {
        _pair_proxy_contract_class_hash::read()
    }

    //
    // Setters
    //

    // @notice Create pair of `tokenA` and `tokenB` with deterministic address using deploy
    // @dev tokens are sorted before creating pair. We deploy PairProxy.
    // @param tokenA Address of tokenA
    // @param tokenB Address of tokenB
    // @return pair Address of the created pair
    #[external]
    fn create_pair(tokenA: ContractAddress, tokenB: ContractAddress) -> ContractAddress {

        assert(!tokenA.is_zero() & !tokenB.is_zero(), 'must be non zero');

        assert(tokenA != tokenB, 'must be different');

        let existing_pair = get_pair(tokenA, tokenB);
        assert(existing_pair.is_zero(), 'pair already exists');
        
        let pair_proxy_class_hash = _pair_proxy_contract_class_hash::read();
        let pair_implementation_class_hash = _pair_contract_class_hash::read();
        let (token0, token1) = _sort_tokens(tokenA, tokenB);
        let salt = pedersen(contract_address_to_felt252(token0), contract_address_to_felt252(token1));
        let fee_to_setter = get_fee_to_setter();

        let mut constructor_calldata = ArrayTrait::new();

        constructor_calldata.append(class_hash_to_felt252(pair_implementation_class_hash));
        constructor_calldata.append(contract_address_to_felt252(token0));
        constructor_calldata.append(contract_address_to_felt252(token1));
        constructor_calldata.append(contract_address_to_felt252(fee_to_setter));

        let syscall_result = deploy_syscall(pair_proxy_class_hash, salt, constructor_calldata.span(), false);
        let (pair, _) = syscall_result.unwrap_syscall();

        _pair::write((token0, token1), pair);
        let num_pairs = _num_of_pairs::read();
        _all_pairs::write(num_pairs, pair);
        _num_of_pairs::write(num_pairs + 1_u32);
        PairCreated(token0, token1, pair, num_pairs + 1_u32);

        pair
    }

    // @notice Change fee recipient to `new_fee_to`
    // @dev Only fee_to_setter can change
    // @param fee_to Address of new fee recipient
    #[external]
    fn set_fee_to(new_fee_to: ContractAddress) {
        let sender = get_caller_address();
        let fee_to_setter = get_fee_to_setter();
        assert(sender == fee_to_setter, 'must be fee to setter');
        _fee_to::write(new_fee_to);
    }

    // @notice Change fee setter to `fee_to_setter`
    // @dev Only fee_to_setter can change
    // @param fee_to_setter Address of new fee setter
    #[external]
    fn set_fee_to_setter(new_fee_to_setter: ContractAddress) {
        let sender = get_caller_address();
        let fee_to_setter = get_fee_to_setter();
        assert(sender == fee_to_setter, 'must be fee to setter');
        assert(!new_fee_to_setter.is_zero(), 'must be non zero');
        _fee_to_setter::write(new_fee_to_setter);
    }

    //
    // Internals LIBRARY
    //

    fn _sort_tokens(tokenA: ContractAddress, tokenB: ContractAddress) -> (ContractAddress, ContractAddress) {
        assert(tokenA != tokenB, 'must not be identical');
        let mut token0 = contract_address_const::<0>();
        let mut token1 = contract_address_const::<0>();
        if u256_from_felt252(contract_address_to_felt252(tokenA)) < u256_from_felt252(contract_address_to_felt252(tokenB)) { // TODO token comparison directly
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }

        assert(!token0.is_zero(), 'must be non zero');
        (token0, token1)
    }
}
