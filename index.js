import * as Merkle from "starknet-merkle-tree";
import fs from "fs";

// Define your airdrop data (address, amount, additional_data)
const airdrop = [
  ['0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a', '1000000000000000000', '0'],
  ['0x53c615080d35defd55569488bc48c1a91d82f2d2ce6199463e095b4a4ead551', '2000000000000000000', '0'],
  ['0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', '500000000000000000', '1'],
  ['0x5678901234567890abcdef1234567890abcdef1234567890abcdef1234567890', '750000000000000000', '0']
];

// Create tree using Poseidon hash (most efficient for Starknet)
const tree = Merkle.StarknetMerkleTree.create(airdrop, Merkle.HashType.Poseidon);

console.log('Merkle Root:', tree.root);
console.log('Tree created with', airdrop.length, 'leaves');

// Generate proofs for all addresses
const proofs = {};
for (let i = 0; i < airdrop.length; i++) {
  const proof = tree.getProof(i);
  const address = airdrop[i][0];
  proofs[address] = {
    proof: proof,
    amount: airdrop[i][1],
    data: airdrop[i][2],
    index: i
  };
  console.log(`Proof for ${address}:`, proof);
}

// Save tree and proofs to files
fs.writeFileSync('merkle_tree.json', JSON.stringify(tree.dump(), null, 2));
fs.writeFileSync('proofs.json', JSON.stringify(proofs, null, 2));

console.log('Tree and proofs saved to files');
