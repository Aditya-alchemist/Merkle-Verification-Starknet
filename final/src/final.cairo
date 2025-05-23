use starknet::ContractAddress;

#[starknet::interface]
trait IMerkleVerifier<TContractState> {
    fn verify_proof(
        self: @TContractState,
        proof: Array<felt252>,
        leaf: felt252
    ) -> bool;
    fn verify_claim(
        self: @TContractState,
        proof: Array<felt252>,
        address: ContractAddress,
        amount: u256,
        additional_data: felt252
    ) -> bool;
    fn get_merkle_root(self: @TContractState) -> felt252;
    fn set_merkle_root(ref self: TContractState, new_root: felt252);
}

#[starknet::contract]
mod MerkleVerifier {
    use super::IMerkleVerifier;
    use starknet::{ContractAddress, get_caller_address};
    use core::poseidon::poseidon_hash_span;
    use core::array::ArrayTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        merkle_root: felt252,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProofVerified: ProofVerified,
        RootUpdated: RootUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct ProofVerified {
        #[key]
        leaf: felt252,
        verified: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct RootUpdated {
        old_root: felt252,
        new_root: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, merkle_root: felt252) {
        self.owner.write(owner);
        self.merkle_root.write(merkle_root);
    }

    #[abi(embed_v0)]
    impl MerkleVerifierImpl of IMerkleVerifier<ContractState> {
        fn verify_proof(
            self: @ContractState,
            proof: Array<felt252>,
            leaf: felt252
        ) -> bool {
            let root = self.merkle_root.read();
            let is_valid = self._verify_merkle_proof(proof.span(), leaf, root);
            
            is_valid
        }

        fn verify_claim(
            self: @ContractState,
            proof: Array<felt252>,
            address: ContractAddress,
            amount: u256,
            additional_data: felt252
        ) -> bool {
            let leaf_hash = self._compute_leaf_hash(address, amount, additional_data);
            self.verify_proof(proof, leaf_hash)
        }

        fn get_merkle_root(self: @ContractState) -> felt252 {
            self.merkle_root.read()
        }

        fn set_merkle_root(ref self: ContractState, new_root: felt252) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can update root');
            
            let old_root = self.merkle_root.read();
            self.merkle_root.write(new_root);
            
            self.emit(RootUpdated { old_root, new_root });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _verify_merkle_proof(
            self: @ContractState,
            proof: Span<felt252>,
            leaf: felt252,
            root: felt252
        ) -> bool {
            let mut computed_hash = leaf;
            let mut i = 0;

            while i < proof.len() {
                let proof_element = *proof.at(i);
                
                // Use a deterministic ordering based on the hash values
                // Hash the smaller value first to ensure consistency
                computed_hash = if self._felt_lt(computed_hash, proof_element) {
                    poseidon_hash_span(array![computed_hash, proof_element].span())
                } else {
                    poseidon_hash_span(array![proof_element, computed_hash].span())
                };
                
                i += 1;
            };

            computed_hash == root
        }

        fn _compute_leaf_hash(
            self: @ContractState,
            address: ContractAddress,
            amount: u256,
            additional_data: felt252
        ) -> felt252 {
            let mut hash_data = ArrayTrait::new();
            hash_data.append(address.into());
            hash_data.append(amount.low.into());
            hash_data.append(amount.high.into());
            hash_data.append(additional_data);
            
            poseidon_hash_span(hash_data.span())
        }

        fn _felt_lt(self: @ContractState, a: felt252, b: felt252) -> bool {
            // Simple comparison using the fact that felt252 can be converted to u256
            let a_u256: u256 = a.into();
            let b_u256: u256 = b.into();
            a_u256 < b_u256
        }
    }
}
