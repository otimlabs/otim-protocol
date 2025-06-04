"""
Update chain configuration with contract deployment addresses.

Usage:
    update_chain_config.py [--config FILE] [--deployment-addresses FILE] [--output FILE]

Arguments:
    --config               Path to chain configuration file (default: chain-config.json)
    --deployment-addresses Path to deployment addresses file (default: deployment_addresses.json)
    --output               Path to output file (default: updated-chain-config.json)
"""

import json
import sys
import os
import argparse

def update_chain_config(config_file="chain-config.json", 
                        deployment_file="deployment_addresses.json", 
                        output_file="updated-chain-config.json"):
    """Update chain configuration with contract deployment addresses."""
    
    # Check if input files exist
    if not os.path.exists(config_file):
        print(f"Error: Chain config file {config_file} not found")
        sys.exit(1)
        
    if not os.path.exists(deployment_file):
        print(f"Error: Deployment addresses file {deployment_file} not found")
        sys.exit(1)
    
    with open(config_file, "r") as file:
        config = json.load(file)

    with open(deployment_file, "r") as file:
        deployment_data = json.load(file)
        
    print("\nDeployment Addresses:")
    print(json.dumps(deployment_data, indent=2))

    # Extract chain ID from deployment data
    chain_id = str(deployment_data.get("ChainId"))

    # Ensure the chain ID exists in the config
    if chain_id not in config:
        print(f"Error: Chain ID {chain_id} not found in chain-config.json")
        sys.exit(1)

    # Map contract names to chain-config.json keys
    mapping = {
        "OtimDelegate": "otim_delegate_addr",
        "InstructionStorage": "instruction_storage_addr",
        "ActionManager": "action_manager_addr",
        "MockERC20": "payment_tokens",  # Will be set to "USDC" only for Devnet
        "Treasury": "treasury_addr",
        "Transfer": "actions",
        "TransferERC20": "actions",
        "Refuel": "actions",
        "RefuelERC20": "actions"
    }

    # Replace existing entries for actions and payment_tokens while preserving others
    for key, config_key in mapping.items():
        if key in deployment_data:
            address = deployment_data[key]

            if key == "MockERC20" and chain_id == "31338": # Devnet ID
                # Replace only the existing MockERC20/USDC entry with USDC if chain_id is 31338 (Devnet)
                existing_entries = {k: v for k, v in config[chain_id]["payment_tokens"].items() if v != "USDC"}
                existing_entries[address] = "USDC"
                config[chain_id]["payment_tokens"] = existing_entries
            elif config_key == "actions":
                # Replace only the existing action entry, keeping others
                existing_entries = {k: v for k, v in config[chain_id]["actions"].items() if v != key[0].lower() + key[1:]}
                existing_entries[address] = key[0].lower() + key[1:]
                config[chain_id]["actions"] = existing_entries
            else:
                # Update top-level key mappings
                config[chain_id][config_key] = address

    with open(output_file, "w") as file:
        json.dump(config, file, indent=4)
    
    # Print the updated config for workflow log
    print("\nUpdated Chain Config:")
    print(json.dumps(config, indent=2))
        
    print(f"\nUpdated chain configuration successfully: {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Update chain configuration with contract deployment addresses."
    )
    
    parser.add_argument(
        "--config", 
        default="chain-config.json", 
        help="Path to chain configuration file (default: chain-config.json)"
    )
    parser.add_argument(
        "--deployment-addresses", 
        default="deployment_addresses.json", 
        help="Path to deployment addresses file (default: deployment_addresses.json)"
    )
    parser.add_argument(
        "--output", 
        default="updated-chain-config.json", 
        help="Path to the updated chain config output file (default: updated-chain-config.json)"
    )
    
    args = parser.parse_args()
    update_chain_config(args.config, args.deployment_addresses, args.output)
