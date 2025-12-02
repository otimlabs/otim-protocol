#!/usr/bin/env rust-script
//! ```cargo
//! [package]
//! name = "protocol-cli"
//! version = "0.1.0"
//! edition = "2021"
//! description = "Protocol development and deployment tools including contract deployment, action whitelisting, and directory comparison"
//!
//! [dependencies]
//! anyhow = "1.0"
//! clap = { version = "4.5", features = ["derive"] }
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! serde_yaml = "0.9"
//! tokio = { version = "1.46", features = ["full"] }
//! regex = "1.11"
//! indexmap = { version = "2.10", features = ["serde"] }
//! colored = "3.0"
//! tempfile = "3.8"
//! merkle_hash = "3.8"
//! camino = "1.0"
//! alloy-primitives = "1.4"
//! alloy-sol-types = "1.4"
//! ```

use anyhow::{anyhow, Context, Result, bail};
use clap::{Parser, Subcommand};
use colored::*;
use merkle_hash::{MerkleTree, Encodable};
use serde_json::json;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::Path;
use alloy_primitives::{Address, U256, hex};
use alloy_sol_types::SolValue;

#[derive(Parser)]
#[command(name = "protocol-cli")]
#[command(about = "Protocol development and deployment tools")]
#[command(long_about = "Protocol CLI for multi-chain contract deployment and management.")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Validate contract addresses match expected addresses
    ValidateContracts {
        /// Configuration file with lists of chains and contracts to manage
        #[arg(short, long)]
        config_file: String,
        /// Directory containing network/chain environment variable configs
        #[arg(long)]
        env_dir: String,
        /// Update the environment file with newly calculated addresses
        #[arg(short, long)]
        update: bool,
    },

    /// Deploy contracts to configured chains
    DeployContracts {
        /// Configuration file with lists of chains and contracts to manage
        #[arg(short, long)]
        config_file: String,
        /// Directory containing network/chain environment variable configs
        #[arg(long)]
        env_dir: Option<String>,
        /// Private key for deployment (if not provided, uses AWS KMS)
        #[arg(short, long)]
        private_key: Option<String>,
    },

    /// Whitelist actions within an action manager
    WhitelistActions {
        /// Configuration file with lists of chains and contracts to manage
        #[arg(short, long)]
        config_file: String,
        /// JSON file containing deployed contract addresses to whitelist
        #[arg(short, long)]
        addresses_file: String,
        /// Directory containing network/chain environment variable configs
        #[arg(long)]
        env_dir: Option<String>,
        /// Optional private key for whitelisting (if not provided, uses AWS KMS)
        #[arg(short, long)]
        private_key: Option<String>,
    },

    /// Update chain configuration with deployed contract addresses
    UpdateChainConfig {
        /// Configuration file with lists of chains and contracts to manage
        #[arg(short, long)]
        config_file: String,
        /// JSON file containing contract addresses (e.g., deployed-addresses.json from deploys)
        #[arg(short, long)]
        addresses_file: String,
        /// Chain config file to update
        #[arg(long)]
        chain_config_file: String,
    },

    /// Compare directory contents using Merkle trees
    CompareDirectories {
        /// First directory to compare
        dir1: String,
        /// Second directory to compare
        dir2: String,
        /// Pattern to ignore during comparison
        #[arg(long)]
        ignore: Option<String>,
        /// Show detailed differences when directories don't match
        #[arg(long)]
        show_diff: bool,
    },

    /// Verify deployed contracts on block explorers
    VerifyContracts {
        /// Configuration file containing deployment details
        #[arg(short, long, default_value = ".github/scripts/deployment-config.yaml")]
        config_file: String,
        /// Networks directory containing common and chain-specific environment configuration
        #[arg(short, long, default_value = ".github/networks/")]
        env_dir: String,
        /// Protocol repository root path
        #[arg(short, long, default_value = ".")]
        protocol_root: String,
        /// Etherscan API key for contract verification
        #[arg(short = 'k', long)]
        etherscan_api_key: Option<String>,
        /// Verifier service to use (etherscan, sourcify)
        #[arg(short, long, default_value = "etherscan", value_parser = ["etherscan", "sourcify"])]
        verifier: String,
    },
}

#[derive(Debug, serde::Deserialize)]
struct DeploymentConfig {
    contracts: Vec<String>,
    chains: Option<Vec<String>>,
}

#[derive(Debug, Clone)]
struct ChainInfo {
    chain_id: u64,
    network: &'static str,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
enum ConstructorType {
    None,       // No constructor args
    Owner,      // Single owner address
    Action,     // (feeTokenRegistry, treasury, gasConstant)
    Core,       // Deployed by OtimDelegate, not directly verifiable
}

#[derive(Debug, Clone)]
struct ContractDetails {
    script: Option<String>,
    expected_addr_envvar: Option<&'static str>,
    chain_config_key: Option<String>,
    source_path: &'static str,
    constructor_type: ConstructorType,
}

#[derive(Debug, Clone)]
struct TierConfig {
    script: Option<String>, // For core tier group deployment
    contracts: HashMap<String, ContractDetails>,
}

/// Gets chain information including chain ID and network
fn get_chain_info(chain: &str) -> Option<ChainInfo> {
    Some(match chain {
        "anvil" => ChainInfo { chain_id: 31337, network: "devnet" },
        "base-sepolia" => ChainInfo { chain_id: 84532, network: "testnet" },
        "base" => ChainInfo { chain_id: 8453, network: "mainnet" },
        "optimism-sepolia" => ChainInfo { chain_id: 11155420, network: "testnet" },
        "optimism" => ChainInfo { chain_id: 10, network: "mainnet" },
        "arbitrum-sepolia" => ChainInfo { chain_id: 421614, network: "testnet" },
        "arbitrum" => ChainInfo { chain_id: 42161, network: "mainnet" },
        "ethereum-sepolia" => ChainInfo { chain_id: 11155111, network: "testnet" },
        "ethereum" => ChainInfo { chain_id: 1, network: "mainnet" },
        "pecorino-signet" => ChainInfo { chain_id: 14174, network: "testnet" },
        "pecorino-host" => ChainInfo { chain_id: 3151908, network: "testnet" },
        _ => return None,
    })
}

/// Returns the tier-based contract mapping configuration
fn get_contract_mapping() -> HashMap<String, TierConfig> {
    use std::collections::HashMap;

    HashMap::from([
        ("core".to_string(), TierConfig {
            script: Some("DeployCore".to_string()),
            contracts: HashMap::from([
                ("OtimDelegate".to_string(), ContractDetails {
                    script: None,
                    expected_addr_envvar: Some("EXPECTED_OTIM_DELEGATE_ADDRESS"),
                    chain_config_key: Some("otim_delegate_addr".to_string()),
                    source_path: "src/OtimDelegate.sol:OtimDelegate",
                    constructor_type: ConstructorType::Owner,
                }),
                ("Gateway".to_string(), ContractDetails {
                    script: None,
                    expected_addr_envvar: Some("EXPECTED_GATEWAY_ADDRESS"),
                    chain_config_key: Some("gateway_addr".to_string()),
                    source_path: "src/core/Gateway.sol:Gateway",
                    constructor_type: ConstructorType::Core,
                }),
                ("InstructionStorage".to_string(), ContractDetails {
                    script: None,
                    expected_addr_envvar: Some("EXPECTED_INSTRUCTION_STORAGE_ADDRESS"),
                    chain_config_key: Some("instruction_storage_addr".to_string()),
                    source_path: "src/core/InstructionStorage.sol:InstructionStorage",
                    constructor_type: ConstructorType::Core,
                }),
                ("ActionManager".to_string(), ContractDetails {
                    script: None,
                    expected_addr_envvar: Some("ACTION_MANAGER_ADDRESS"),
                    chain_config_key: Some("action_manager_addr".to_string()),
                    source_path: "src/core/ActionManager.sol:ActionManager",
                    constructor_type: ConstructorType::Core,
                }),
            ]),
        }),

        ("infrastructure".to_string(), TierConfig {
            script: None,
            contracts: HashMap::from([
                ("FeeTokenRegistry".to_string(), ContractDetails {
                    script: Some("DeployFeeTokenRegistry".to_string()),
                    expected_addr_envvar: Some("EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS"),
                    chain_config_key: Some("fee_token_registry_addr".to_string()),
                    source_path: "src/infrastructure/FeeTokenRegistry.sol:FeeTokenRegistry",
                    constructor_type: ConstructorType::Owner,
                }),
                ("Treasury".to_string(), ContractDetails {
                    script: Some("DeployTreasury".to_string()),
                    expected_addr_envvar: Some("EXPECTED_TREASURY_ADDRESS"),
                    chain_config_key: Some("treasury_addr".to_string()),
                    source_path: "src/infrastructure/Treasury.sol:Treasury",
                    constructor_type: ConstructorType::Owner,
                }),
            ]),
        }),

        ("actions".to_string(), TierConfig {
            script: None,
            contracts: HashMap::from([
                ("TransferAction".to_string(), ContractDetails {
                    script: Some("DeployTransferAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_TRANSFER_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.transfer".to_string()),
                    source_path: "src/actions/TransferAction.sol:TransferAction",
                    constructor_type: ConstructorType::Action,
                }),
                ("TransferERC20Action".to_string(), ContractDetails {
                    script: Some("DeployTransferERC20Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_TRANSFER_ERC20_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.transferERC20".to_string()),
                    source_path: "src/actions/TransferERC20Action.sol:TransferERC20Action",
                    constructor_type: ConstructorType::Action,
                }),
                ("RefuelAction".to_string(), ContractDetails {
                    script: Some("DeployRefuelAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_REFUEL_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.refuel".to_string()),
                    source_path: "src/actions/RefuelAction.sol:RefuelAction",
                    constructor_type: ConstructorType::Action,
                }),
                ("RefuelERC20Action".to_string(), ContractDetails {
                    script: Some("DeployRefuelERC20Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_REFUEL_ERC20_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.refuelERC20".to_string()),
                    source_path: "src/actions/RefuelERC20Action.sol:RefuelERC20Action",
                    constructor_type: ConstructorType::Action,
                }),
                ("UniswapV3ExactInputAction".to_string(), ContractDetails {
                    script: Some("DeployUniswapV3ExactInputAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_UNISWAP_V3_EXACT_INPUT_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.uniswapV3ExactInput".to_string()),
                    source_path: "src/actions/UniswapV3ExactInputAction.sol:UniswapV3ExactInputAction",
                    constructor_type: ConstructorType::Action,
                }),
                ("DeactivateInstructionAction".to_string(), ContractDetails {
                    script: Some("DeployDeactivateInstructionAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_DEACTIVATE_INSTRUCTION_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.deactivateInstruction".to_string()),
                    source_path: "src/actions/DeactivateInstructionAction.sol:DeactivateInstructionAction",
                    constructor_type: ConstructorType::Action,
                }),
                ("SweepAction".to_string(), ContractDetails {
                    script: Some("DeploySweepAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.sweep".to_string()),
                    source_path: "src/actions/SweepAction.sol:SweepAction",
                    constructor_type: ConstructorType::Action,
                }),
                ("SweepERC20Action".to_string(), ContractDetails {
                    script: Some("DeploySweepERC20Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_ERC20_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.sweepERC20".to_string()),
                    source_path: "src/actions/SweepERC20Action.sol:SweepERC20Action",
                    constructor_type: ConstructorType::Action,
                }),
                ("SweepCCTPAction".to_string(), ContractDetails {
                    script: Some("DeploySweepCCTPAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_CCTP_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.sweepCCTP".to_string()),
                    source_path: "src/actions/SweepCCTPAction.sol:SweepCCTPAction",
                    constructor_type: ConstructorType::Action,
                }),
                ("TransferCCTPAction".to_string(), ContractDetails {
                    script: Some("DeployTransferCCTPAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_TRANSFER_CCTP_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.transferCCTP".to_string()),
                    source_path: "src/actions/TransferCCTPAction.sol:TransferCCTPAction",
                    constructor_type: ConstructorType::Action,
                }),
                ("SweepUniswapV3Action".to_string(), ContractDetails {
                    script: Some("DeploySweepUniswapV3Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_UNISWAP_V3_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.sweepUniswapV3".to_string()),
                    source_path: "src/actions/SweepUniswapV3Action.sol:SweepUniswapV3Action",
                    constructor_type: ConstructorType::Action,
                }),
                ("DepositERC4626Action".to_string(), ContractDetails {
                    script: Some("DeployDepositERC4626Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_DEPOSIT_ERC4626_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.depositERC4626".to_string()),
                    source_path: "src/actions/DepositERC4626Action.sol:DepositERC4626Action",
                    constructor_type: ConstructorType::Action,
                }),
                ("SweepDepositERC4626Action".to_string(), ContractDetails {
                    script: Some("DeploySweepDepositERC4626Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_DEPOSIT_ERC4626_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.sweepDepositERC4626".to_string()),
                    source_path: "src/actions/SweepDepositERC4626Action.sol:SweepDepositERC4626Action",
                    constructor_type: ConstructorType::Action,
                }),
                ("WithdrawERC4626Action".to_string(), ContractDetails {
                    script: Some("DeployWithdrawERC4626Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_WITHDRAW_ERC4626_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.withdrawERC4626".to_string()),
                    source_path: "src/actions/WithdrawERC4626Action.sol:WithdrawERC4626Action",
                    constructor_type: ConstructorType::Action,
                }),
                ("SweepWithdrawERC4626Action".to_string(), ContractDetails {
                    script: Some("DeploySweepWithdrawERC4626Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_WITHDRAW_ERC4626_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.sweepWithdrawERC4626".to_string()),
                    source_path: "src/actions/SweepWithdrawERC4626Action.sol:SweepWithdrawERC4626Action",
                    constructor_type: ConstructorType::Action,
                }),
                ("CallOnceAction".to_string(), ContractDetails {
                    script: Some("DeployCallOnceAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_CALL_ONCE_ACTION_ADDRESS"),
                    chain_config_key: Some("actions.callOnce".to_string()),
                    source_path: "src/actions/CallOnceAction.sol:CallOnceAction",
                    constructor_type: ConstructorType::Action,
                }),
            ]),
        }),
    ])
}

// =============================================================================
// UTILITIES
// =============================================================================

/// Prints log messages with colored formatting
fn info(msg: &str) {
    println!("{} {}", "[INFO]".green().bold(), msg);
}

fn warn(msg: &str) {
    println!("{} {}", "[WARN]".yellow().bold(), msg);
}

/// Converts camelCase to SNAKE_CASE
fn to_snake_case(s: &str) -> String {
    s.chars()
        .enumerate()
        .flat_map(|(i, c)| {
            if i > 0 && c.is_uppercase() && !s.chars().nth(i - 1).unwrap().is_uppercase() {
                vec!['_', c]
            } else {
                vec![c]
            }
        })
        .collect::<String>()
        .to_uppercase()
}

/// Loads and parses the deployment configuration from YAML file
fn load_deploy_config(config_path: &str) -> Result<DeploymentConfig> {
    let content = fs::read_to_string(config_path)
        .with_context(|| format!("Failed to read config file: {}", config_path))?;
    serde_yaml::from_str(&content)
        .with_context(|| "Failed to parse deployment config")
}

/// Gets contracts for a specific tier from the config list
fn get_tier_contracts(config: &DeploymentConfig, tier: &str) -> Vec<String> {
    let mapping = get_contract_mapping();
    if let Some(tier_config) = mapping.get(tier) {
        config.contracts.iter()
            .filter(|contract| {
                // Handle "Core" as a special case that maps to all core contracts
                if *contract == "Core" && tier == "core" {
                    true
                } else {
                    tier_config.contracts.contains_key(*contract)
                }
            })
            .cloned()
            .collect()
    } else {
        Vec::new()
    }
}

/// Finds contract details by name from the tier-based mapping
fn find_contract_details(contract: &str) -> Option<ContractDetails> {
    let mapping = get_contract_mapping();
    for (_, tier_config) in mapping.iter() {
        if let Some(details) = tier_config.contracts.get(contract) {
            return Some(details.clone());
        }
    }
    None
}

/// Loads environment variables from file and sets them in the current process
fn load_env_file(path: &str) -> Result<HashMap<String, String>> {
    let mut expected_addr_envvars = HashMap::new();

    if !Path::new(path).exists() {
        warn(&format!("Environment file not found: {}, will create it", path));
        return Ok(expected_addr_envvars);
    }

    let content = fs::read_to_string(path)?;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue; // Skip empty lines and comments
        }
        if let Some((key, value)) = line.split_once('=') {
            let key = key.trim();
            let value = value.trim();
            expected_addr_envvars.insert(key.to_string(), value.to_string());
            env::set_var(key, value);
        }
    }

    Ok(expected_addr_envvars)
}

/// Loads environment files for a chain (auto-detects network from chain name)
fn load_chain_env_files(env_dir: &str, chain: &str, network: &str) -> Result<HashMap<String, String>> {
    [(format!("{}/.env-gas-constants", env_dir), "gas constants"),
     (format!("{}/{}/.env-otim-{}", env_dir, network, network), "shared"),
     (format!("{}/{}/.env-{}", env_dir, network, chain), "chain")]
        .iter()
        .try_fold(HashMap::new(), |mut env_vars, (path, env_type)| {
            info(&format!("Loading {} env: {}", env_type, path));
            env_vars.extend(load_env_file(path)?);
            Ok(env_vars)
        })
}

/// Updates environment file with new key-value pairs, preserving comments and structure
fn update_env_file(path: &str, updates: &HashMap<String, String>) -> Result<()> {
    let content = if Path::new(path).exists() {
        fs::read_to_string(path)
            .with_context(|| format!("Failed to read environment file: {}", path))?
    } else {
        String::new()
    };

    let mut updated_content = content;

    for (key, new_value) in updates {
        // Replace the value for the specific key
        let pattern = format!(r"(?m)^{}=.*$", regex::escape(key));
        let replacement = format!("{}={}", key, new_value);

        if let Ok(re) = regex::Regex::new(&pattern) {
            if re.is_match(&updated_content) {
                updated_content = re.replace_all(&updated_content, replacement.as_str()).to_string();
            } else {
                // If key doesn't exist, append it
                if !updated_content.ends_with('\n') {
                    updated_content.push('\n');
                }
                updated_content.push_str(&replacement);
                updated_content.push('\n');
            }
        }
    }

    fs::write(path, updated_content)
        .with_context(|| format!("Failed to write environment file: {}", path))
}

/// Executes any command with retry logic
async fn run_command(command: &str, args: &[&str], max_retries: u32, retry_errors: &[&str]) -> Result<String> {
    let mut last_error = None;
    
    for attempt in 1..=max_retries {
        info(&format!("Executing: {} {}", command, args.join(" ")));

        let output = tokio::process::Command::new(command)
            .args(args)
            .env_clear()
            .envs(env::vars())
            .output()
            .await?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let error = anyhow!("Command failed: {} {}\nError: {}", command, args.join(" "), stderr);
            let error_msg = error.to_string();
            
            // Check if error matches any retry patterns (case-insensitive)
            let error_msg_lower = error_msg.to_lowercase();
            let should_retry = retry_errors.iter().any(|pattern| error_msg_lower.contains(&pattern.to_lowercase()));
            
            if should_retry && attempt < max_retries {
                warn(&format!("Attempt {}/{} failed ({}), retrying...", attempt, max_retries, error_msg.lines().next().unwrap_or("unknown error")));
                tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
                last_error = Some(error);
                continue;
            }
            
            return Err(error);
        }

        return Ok(String::from_utf8_lossy(&output.stdout).to_string());
    }
    
    Err(last_error.unwrap_or_else(|| anyhow!("Max retries exceeded")))
}


/// Extracts contract address from forge deployment output using regex pattern matching
fn extract_address(output: &str, contract: &str) -> Result<String> {
    use regex::Regex;

    let re = Regex::new(&format!(r"{} deployed at: (0x[a-fA-F0-9]{{40}})", contract))?;
    re.captures(output)
        .and_then(|caps| caps.get(1))
        .map(|m| m.as_str().to_string())
        .ok_or_else(|| anyhow!("Address not found for {}", contract))
}

// =============================================================================
// VALIDATE CONTRACTS
// =============================================================================

/// Calculates contract addresses for a specific deployment tier using dry-run
async fn calculate_addresses_by_tier(config: &DeploymentConfig, tier: &str) -> Result<HashMap<String, String>> {
    let contracts = get_tier_contracts(config, tier);
    let mut addresses = HashMap::new();
    let tier_mapping = get_contract_mapping();

    if let Some(tier_config) = tier_mapping.get(tier) {
        // Group contracts by script
        let mut script_groups: HashMap<String, Vec<String>> = HashMap::new();

        for contract in contracts {
            if contract == "Core" && tier == "core" {
                // Handle Core as a special case - deploy all core contracts together
                if let Some(core_script) = &tier_config.script {
                    let core_contracts: Vec<String> = tier_config.contracts.keys().cloned().collect();
                    script_groups.entry(core_script.clone()).or_default().extend(core_contracts);
                }
            } else if let Some(details) = tier_config.contracts.get(&contract) {
                // Skip contracts without expected_addr_envvar property
                if details.expected_addr_envvar.is_none() {
                    info(&format!("Skipping {} - no expected_addr_envvar configured", contract));
                    continue;
                }

                // For core tier, use the tier-level script; for others, use individual contract script
                let script_to_use = if tier == "core" {
                    tier_config.script.clone().unwrap_or_else(|| details.script.clone().unwrap_or_default())
                } else {
                    details.script.clone().unwrap_or_default()
                };
                script_groups.entry(script_to_use).or_default().push(contract);
            } else {
                warn(&format!("Contract {} not found in {} tier mapping, skipping", contract, tier));
            }
        }

        // Execute each script and extract addresses for all contracts in that script
        for (script, script_contracts) in script_groups {
            let args = vec!["script", script.as_str(), "--json"];
            let output = run_command("forge", &args, 1, &[]).await?;
            for contract in script_contracts {
                if let Ok(address) = extract_address(&output, &contract) {
                    addresses.insert(contract, address);
                } else {
                    warn(&format!("Could not extract address for {} from script {}", contract, script));
                }
            }
        }
    }

    Ok(addresses)
}

/// Validates calculated contract addresses against environment file values
async fn validate_addresses(config: &DeploymentConfig, network_env_file: &str, chain_env_file: &str, update: bool) -> Result<()> {
    let network_env = load_env_file(network_env_file)?;
    let chain_env = load_env_file(chain_env_file)?;
    let mut calculated_addresses = HashMap::new();
    let mut network_updates = HashMap::new();
    let mut chain_updates = HashMap::new();

    // Calculate addresses for all tiers
    for tier in ["core", "infrastructure", "actions"] {
        info(&format!("Calculating {} addresses...", tier));
        let addresses = calculate_addresses_by_tier(config, tier).await?;

        // Update environment for next tier dependencies
        for (contract, address) in &addresses {
            if let Some(details) = find_contract_details(contract) {
                if let Some(env_var) = &details.expected_addr_envvar {
                    env::set_var(env_var, address);
                }
            }
        }

        calculated_addresses.extend(addresses);
    }

    // Compare addresses and collect updates (route to chain or network env file)
    for (contract, calculated_address) in &calculated_addresses {
        if let Some(details) = find_contract_details(contract) {
            if let Some(env_var) = &details.expected_addr_envvar {
                let is_non_create2 = matches!(*env_var,
                    "EXPECTED_UNISWAP_V3_EXACT_INPUT_ACTION_ADDRESS" | "EXPECTED_SWEEP_CCTP_ACTION_ADDRESS" |
                    "EXPECTED_TRANSFER_CCTP_ACTION_ADDRESS" | "EXPECTED_SWEEP_UNISWAP_V3_ACTION_ADDRESS"
                );
                let (env, updates_map) = if is_non_create2 {
                    (&chain_env, &mut chain_updates)
                } else {
                    (&network_env, &mut network_updates)
                };
                let env_file_path = if is_non_create2 { chain_env_file } else { network_env_file };
                let current_address = env.get(*env_var).map(|s| s.as_str()).unwrap_or("NOT_SET");
                if current_address != calculated_address {
                    warn(&format!("{}: {} → {} ({})", contract, current_address, calculated_address, env_file_path));
                    updates_map.insert(env_var.to_string(), calculated_address.clone());
                } else {
                    info(&format!("{}: {} ✓", contract, calculated_address));
                }
            } else {
                info(&format!("{}: {} (skipped)", contract, calculated_address));
            }
        } else {
            info(&format!("{}: {} (skipped)", contract, calculated_address));
        }
    }

    // Apply updates and/or report differences
    let has_updates = !network_updates.is_empty() || !chain_updates.is_empty();
    if has_updates {
        if update {
            if !network_updates.is_empty() {
                update_env_file(network_env_file, &network_updates)?;
                info(&format!("Updated {}", network_env_file));
            }
            if !chain_updates.is_empty() {
                update_env_file(chain_env_file, &chain_updates)?;
                info(&format!("Updated {}", chain_env_file));
            }
        } else {
            info("Address differences detected. Use --update to apply changes.");
        }
        std::process::exit(2);
    } else {
        info("All addresses match");
    }

    Ok(())
}

// =============================================================================
// DEPLOY CONTRACTS
// =============================================================================

/// Checks if an error is a known/expected error that should not be retried
fn is_known_error(error: &str) -> bool {
    error.contains("CreateCollision") ||
    error.contains("AlreadyAdded") ||
    error.contains("empty revert data")
}


/// Executes a forge deployment command with retry logic
async fn run_forge_deploy(script: &str, private_key: Option<&str>) -> Result<String> {
    let rpc_url = env::var("RPC_URL").context("RPC_URL not found")?;
    let mut args: Vec<&str> = vec![
        "script", script,
        "--broadcast",
        "--rpc-url", rpc_url.as_str(),
        "--timeout", "30", // 30 second timeout
    ];

    if let Some(pk) = private_key {
        args.extend_from_slice(&["--private-key", pk]);
    } else {
        args.push("--aws");
    }

    args.push("--json");
    
    let retry_errors = &["failed to get block", "timed out", "dispatch failure", "connection", "reset by peer"];
    run_command("forge", &args, 3, retry_errors).await
}

/// Deploys all contracts in tier order
async fn deploy_contracts(config: &DeploymentConfig, private_key: Option<&str>) -> Result<HashMap<String, String>> {
    info("Deploying contracts...");
    let mut all_addresses = HashMap::new();
    let tier_mapping = get_contract_mapping();

    for tier in ["core", "infrastructure", "actions"] {
        info(&format!("Deploying {} contracts...", tier));
        let contracts = get_tier_contracts(config, tier);
        let tier_config = tier_mapping.get(tier).unwrap();

        // Deploy each contract
        for contract in &contracts {
            if contract == "Core" && tier == "core" {
                // Deploy all core contracts together
                if let Some(script) = &tier_config.script {
                    match run_forge_deploy(script, private_key).await {
                        Ok(output) => {
                            for (core_contract, details) in &tier_config.contracts {
                                if let Ok(addr) = extract_address(&output, core_contract) {
                                    info(&format!("✓ Deployed {}: {}", core_contract, addr));
                                    all_addresses.insert(core_contract.clone(), addr.clone());
                                    if let Some(env_var) = &details.expected_addr_envvar {
                                        env::set_var(env_var, &addr);
                                    }
                                }
                            }
                        }
                        Err(e) if is_known_error(&e.to_string()) => {
                            info("Core already deployed, collecting existing addresses");
                            for (core_contract, details) in &tier_config.contracts {
                                if let Some(env_var) = &details.expected_addr_envvar {
                                    let existing_addr = env::var(env_var)
                                        .with_context(|| format!("No existing address found for {} ({})", core_contract, env_var))?;
                                    info(&format!("- Using existing {}: {}", core_contract, existing_addr));
                                    all_addresses.insert(core_contract.clone(), existing_addr);
                                }
                            }
                        }
                        Err(e) => bail!("Core deployment failed with unknown error: {}", e),
                    }
                }
            } else if let Some(details) = tier_config.contracts.get(contract) {
                // Deploy individual contract
                let script = details.script.clone().unwrap_or_else(|| format!("Deploy{}", contract));
                match run_forge_deploy(&script, private_key).await {
                    Ok(output) => {
                        if let Ok(addr) = extract_address(&output, contract) {
                            info(&format!("✓ Deployed {}: {}", contract, addr));
                            all_addresses.insert(contract.clone(), addr.clone());
                            if let Some(env_var) = &details.expected_addr_envvar {
                                env::set_var(env_var, &addr);
                            }
                        }
                    }
                    Err(e) if is_known_error(&e.to_string()) => {
                        info(&format!("Contract {} already deployed", contract));
                        if let Some(env_var) = &details.expected_addr_envvar {
                            let existing_addr = env::var(env_var)
                                .with_context(|| format!("No existing address found for {} ({})", contract, env_var))?;
                            info(&format!("- Using existing {}: {}", contract, existing_addr));
                            all_addresses.insert(contract.clone(), existing_addr);
                        }
                    }
                    Err(e) => bail!("Contract {} deployment failed with unknown error: {}", contract, e),
                }
            }
            
            // Add delay between deployments to prevent nonce conflicts
            if let Some(last_contract) = contracts.last() {
                if contract != last_contract {
                    tokio::time::sleep(tokio::time::Duration::from_secs(3)).await;
                }
            }
        }

        // Update environment for next tier dependencies
        for (contract, address) in &all_addresses {
            if let Some(details) = find_contract_details(contract) {
                if let Some(env_var) = &details.expected_addr_envvar {
                    env::set_var(env_var, address);
                }
            }
        }
    }

    info(&format!("Deployment completed! Collected {} addresses", all_addresses.len()));
    Ok(all_addresses)
}

// =============================================================================
// WHITELIST ACTIONS
// =============================================================================

/// Whitelists all action contracts in the action manager for a specific chain
async fn whitelist_actions_for_chain(chain: &str, addresses: &HashMap<String, String>, private_key: Option<&str>) -> Result<()> {
    let action_contracts: Vec<_> = addresses.iter()
        .filter(|(name, _)| name.ends_with("Action"))
        .collect();

    if action_contracts.is_empty() {
        info(&format!("No action contracts found for {}", chain));
        return Ok(());
    }

    let rpc_url = env::var("RPC_URL")?;
    let use_legacy = env::var("FORGE_LEGACY")
        .map(|v| v.eq_ignore_ascii_case("true") || v == "1")
        .unwrap_or(false);

    for (contract_name, action_address) in &action_contracts {
        info(&format!("Whitelisting {} at {}...", contract_name, action_address));

        let mut args = vec![
            "script", "AddAction", "--sig", "run(address)", "--broadcast",
            "--rpc-url", &rpc_url
        ];

        if use_legacy {
            args.push("--legacy");
        }

        if let Some(pk) = private_key {
            args.extend_from_slice(&["--private-key", pk]);
        } else {
            args.push("--aws");
        }

        args.push(action_address);

        let retry_errors = &["failed to get block", "timed out", "dispatch failure", "connection", "reset by peer"];
        match run_command("forge", &args, 3, retry_errors).await {
            Ok(_) => {
                info(&format!("✓ {} whitelisted", contract_name));
            }
            Err(e) => {
                let error_str = e.to_string();
                if is_known_error(&error_str) {
                    info(&format!("- {} already whitelisted", contract_name));
                } else {
                    bail!("Failed to whitelist {}: {}", contract_name, e);
                }
            }
        }
        
        // Add delay between whitelisting operations to prevent nonce conflicts
        if let Some((last_contract_name, _)) = action_contracts.last() {
            if *contract_name != *last_contract_name {
                tokio::time::sleep(tokio::time::Duration::from_secs(3)).await;
            }
        }
    }

    info(&format!("✓ Completed whitelisting {} contracts for {}", action_contracts.len(), chain));
    Ok(())
}

// =============================================================================
// UPDATE CHAIN CONFIG
// =============================================================================

/// Update chain configuration with deployed contract addresses
async fn update_chain_config(config: &DeploymentConfig, addresses_file: &str, chain_config_file: &str) -> Result<()> {
    let addresses_by_chain: HashMap<String, HashMap<String, String>> =
        serde_json::from_str(&fs::read_to_string(addresses_file)?)?;
    let mut chain_config: serde_json::Value = serde_json::from_str(&fs::read_to_string(chain_config_file)?)?;
    let chains = config.chains.as_ref().filter(|c| !c.is_empty())
        .ok_or_else(|| anyhow!("No chains in config"))?;
    let tier_mapping = get_contract_mapping();
    let mut has_changes = false;

    for chain in chains {
        let chain_id = get_chain_info(chain).ok_or_else(|| anyhow!("Unknown chain: {}", chain))?.chain_id;
        let addresses = addresses_by_chain.get(chain)
            .ok_or_else(|| anyhow!("No addresses found for '{}'", chain))?;

        let target_key = chain_config.as_object()
            .and_then(|obj| obj.iter().find(|(k, _)| k.parse::<u64>().ok() == Some(chain_id)))
            .map(|(k, _)| k.clone())
            .ok_or_else(|| anyhow!("Chain '{}' (chain_id: {}) not found in config", chain, chain_id))?;

        let target = chain_config[&target_key].as_object_mut().ok_or_else(|| anyhow!("Invalid chain block"))?;
        let mut updated = false;

        for (contract_name, address) in addresses {
            if let Some(key) = tier_mapping.values().find_map(|t| t.contracts.get(contract_name)?.chain_config_key.as_ref()) {
                if let Some(action_name) = key.strip_prefix("actions.") {
                    let actions = target.entry("actions").or_insert_with(|| json!({})).as_object_mut().unwrap();
                    if actions.get(address).and_then(|v| v.as_str()) != Some(action_name) {
                        actions.insert(address.clone(), json!(action_name));
                        updated = true;
                    }
                } else if target.get(key).and_then(|v| v.as_str()) != Some(address) {
                    target.insert(key.clone(), json!(address));
                    updated = true;
                }
            }
        }

        info(&format!("{} {}", if updated { "✓" } else { "-" }, chain));
        has_changes |= updated;
    }

    if has_changes {
        fs::write(chain_config_file, serde_json::to_string_pretty(&chain_config)?)?;
        info(&format!("✓ Updated {} chains", chains.len()));
        std::process::exit(2);
    }
    info("No changes needed");
    std::process::exit(0);
}

// =============================================================================
// VERIFY CONTRACTS
// =============================================================================

/// Encodes constructor arguments based on contract type and specific action patterns
fn encode_constructor_args(constructor_type: &ConstructorType, contract_name: &str, env_vars: &HashMap<String, String>) -> Result<String> {
    let get = |key: &str| -> Result<Address> {
        env_vars.get(key).ok_or_else(|| anyhow!("{} not found", key))?
            .parse().with_context(|| format!("Failed to parse address: {}", key))
    };
    
    match constructor_type {
        ConstructorType::None | ConstructorType::Core => Ok(String::new()),
        ConstructorType::Owner => Ok(hex::encode_prefixed(get("OWNER_ADDRESS")?.abi_encode())),
        ConstructorType::Action => {
            let (fee, treasury) = (get("EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS")?, get("EXPECTED_TREASURY_ADDRESS")?);
            let gas_key = match contract_name {
                "SweepCCTPAction" => "SWEEP_CCTP_ACTION".to_string(),
                "TransferCCTPAction" => "TRANSFER_CCTP_ACTION".to_string(),
                "SweepUniswapV3Action" => "SWEEP_UNISWAP_V3_ACTION".to_string(),
                "UniswapV3ExactInputAction" => "UNISWAP_V3_EXACT_INPUT_ACTION".to_string(),
                _ => to_snake_case(contract_name),
            };
            let gas = env_vars.get(&format!("{}_GAS_CONSTANT", gas_key))
                .ok_or_else(|| anyhow!("Gas constant not found for {}", contract_name))?
                .parse::<u64>().map(U256::from)
                .with_context(|| format!("Failed to parse gas constant for {}", contract_name))?;
            
            Ok(hex::encode_prefixed(match contract_name {
                "CallOnceAction" | "DeactivateInstructionAction" => 
                    (get("EXPECTED_INSTRUCTION_STORAGE_ADDRESS")?, fee, treasury, gas).abi_encode(),
                "SweepUniswapV3Action" | "UniswapV3ExactInputAction" => 
                    (get("UNIVERSAL_ROUTER_ADDRESS")?, get("UNISWAP_V3_FACTORY_ADDRESS")?, get("WETH9_ADDRESS")?, fee, treasury, gas).abi_encode(),
                "SweepCCTPAction" | "TransferCCTPAction" => 
                    (get("CCTP_TOKEN_MESSENGER_ADDRESS")?, get("CCTP_TOKEN_MINTER_ADDRESS")?, fee, treasury, gas).abi_encode(),
                _ => (fee, treasury, gas).abi_encode(),
            }))
        }
    }
}

/// Verifies contracts for networks based on a deployment config
async fn verify_contracts(
    config_file: &str,
    env_dir: &str,
    protocol_root: &str,
    etherscan_api_key: Option<&str>,
    verifier: &str,
) -> Result<()> {
    let config = load_deploy_config(config_file)?;
    let chains = config.chains.as_ref().filter(|c| !c.is_empty()).ok_or_else(|| anyhow!("No chains in config"))?;

    for chain in chains {
        info(&format!("Verifying contracts for network: {}", chain));
        let chain_info = get_chain_info(chain).ok_or_else(|| anyhow!("Unknown chain: {}", chain))?;
        let env_vars = load_chain_env_files(env_dir, chain, chain_info.network)?;
        env_vars.iter().for_each(|(k, v)| env::set_var(k, v));

        for contract_name in &config.contracts {
            if contract_name == "Core" {
                for (name, details) in &get_contract_mapping().get("core").unwrap().contracts {
                    verify_contract(protocol_root, name, details, chain_info.chain_id, &env_vars, etherscan_api_key, verifier).await?;
                }
                continue;
            }
            let Some(details) = find_contract_details(contract_name) else {
                warn(&format!("Contract {} not found in mapping, skipping", contract_name));
                continue;
            };
            verify_contract(protocol_root, contract_name, &details, chain_info.chain_id, &env_vars, etherscan_api_key, verifier).await?;
        }
        info(&format!("✓ Completed verification for {}", chain));
    }

    info("All contract verifications completed!");
    Ok(())
}

/// Verifies a single contract
async fn verify_contract(
    protocol_root: &str,
    contract_name: &str,
    details: &ContractDetails,
    chain_id: u64,
    env_vars: &HashMap<String, String>,
    etherscan_api_key: Option<&str>,
    verifier: &str,
) -> Result<()> {
    if matches!(details.constructor_type, ConstructorType::Core) {
        info(&format!("Skipping {} (deployed by OtimDelegate)", contract_name));
        return Ok(());
    }

    let address = env_vars.get(details.expected_addr_envvar
        .unwrap_or_else(|| panic!("No address env var for {}", contract_name)))
        .unwrap_or_else(|| panic!("Address not found in environment"));
    info(&format!("Verifying {} at {}", contract_name, address));

    let constructor_args = encode_constructor_args(&details.constructor_type, contract_name, env_vars)?;
    let chain_id_str = chain_id.to_string();
    let mut args = vec!["verify-contract", address, &details.source_path, "--chain-id", &chain_id_str, "--verifier", verifier, "--watch"];
    if !constructor_args.is_empty() {
        args.extend(["--constructor-args", &constructor_args]);
    }
    if let Some(key) = etherscan_api_key.filter(|_| verifier == "etherscan") {
        args.extend(["--etherscan-api-key", key]);
    }

    let status = tokio::process::Command::new("forge").args(&args).current_dir(protocol_root)
        .env_clear().envs(env::vars()).status().await?;
    
    if status.success() {
        info(&format!("✓ {} verified successfully", contract_name));
    } else {
        warn(&format!("Failed to verify {}", contract_name));
    }
    Ok(())
}

// =============================================================================
// COMPARE DIRECTORIES
// =============================================================================

/// Compare two directories using Merkle trees
fn compare_directories(dir1: &str, dir2: &str, ignore: Option<&str>, show_diff: bool) -> Result<bool> {
    let tree1 = MerkleTree::builder(dir1).build()?;
    let tree2 = MerkleTree::builder(dir2).build()?;

    let files1: HashMap<_, _> = tree1.iter()
        .filter(|i| !should_ignore_path(&i.path.relative, ignore))
        .filter(|i| std::path::Path::new(dir1).join(&i.path.relative).is_file())
        .map(|i| (i.path.relative.to_string(), i.hash.to_hex_string()))
        .collect();

    let files2: HashMap<_, _> = tree2.iter()
        .filter(|i| !should_ignore_path(&i.path.relative, ignore))
        .filter(|i| std::path::Path::new(dir2).join(&i.path.relative).is_file())
        .map(|i| (i.path.relative.to_string(), i.hash.to_hex_string()))
        .collect();

    let matches = files1 == files2;
    if !matches && show_diff {
        print_differences(&files1, &files2, dir2);
    }

    Ok(matches)
}

fn should_ignore_path(relative_path: &camino::Utf8Path, ignore: Option<&str>) -> bool {
    let path_str = relative_path.as_str();
    if path_str.is_empty() {
        return true;
    }
    ignore.map_or(false, |pattern| path_str.contains(pattern))
}

fn print_differences(files1: &HashMap<String, String>, files2: &HashMap<String, String>, dir2: &str) {
    let mut diff_count = 0;

    for (path, hash1) in files1 {
        match files2.get(path) {
            Some(hash2) if hash1 != hash2 => {
                println!("{}: content differs", path);
                diff_count += 1;
            }
            None => {
                println!("{}: missing in {}", path, dir2);
                diff_count += 1;
            }
            _ => {}
        }
    }

    for path in files2.keys() {
        if !files1.contains_key(path) {
            println!("{}: extra in {}", path, dir2);
            diff_count += 1;
        }
    }

    println!("\n❌ Found {} differences", diff_count);
}

// ---

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::ValidateContracts { config_file, env_dir, update } => {
            let config = load_deploy_config(&config_file)?;
            let chains = config.chains.as_ref().filter(|c| !c.is_empty()).ok_or_else(|| anyhow!("No chains in config"))?;

            for chain in chains {
                let chain_info = get_chain_info(chain).ok_or_else(|| anyhow!("Unknown chain: {}", chain))?;
                info(&format!("Validating {} ({})", chain, chain_info.network));
                load_chain_env_files(&env_dir, chain, chain_info.network)?;
                validate_addresses(
                    &config,
                    &format!("{}/{}/.env-otim-{}", env_dir, chain_info.network, chain_info.network),
                    &format!("{}/{}/.env-{}", env_dir, chain_info.network, chain),
                    update
                ).await?;
            }
            info(&format!("✓ Validated {} chains", chains.len()));
            Ok(())
        }

        Commands::DeployContracts { config_file, env_dir, private_key } => {
            let config = load_deploy_config(&config_file)?;
            let chains = config.chains.as_ref().filter(|c| !c.is_empty()).ok_or_else(|| anyhow!("No chains in config"))?;

            let mut all_addresses = HashMap::new();
            for chain in chains {
                info(&format!("Deploying to {}", chain));
                if let Some(dir) = &env_dir {
                    load_chain_env_files(dir, chain, get_chain_info(chain).ok_or_else(|| anyhow!("Unknown chain: {}", chain))?.network)?;
                }
                all_addresses.insert(chain.clone(), deploy_contracts(&config, private_key.as_deref()).await?);
            }
            std::fs::write("deployed-addresses.json", serde_json::to_string_pretty(&all_addresses)?)?;
            info(&format!("✓ Deployed to {} chains → deployed-addresses.json", chains.len()));
            Ok(())
        }

        Commands::WhitelistActions { config_file, addresses_file, env_dir, private_key } => {
            let config = load_deploy_config(&config_file)?;
            let chains = config.chains.as_ref().filter(|c| !c.is_empty()).ok_or_else(|| anyhow!("No chains in config"))?;
            let addresses_by_chain: HashMap<String, HashMap<String, String>> =
                serde_json::from_str(&fs::read_to_string(&addresses_file)?)?;

            // Ensure all config chains have deployed addresses
            let missing: Vec<_> = chains.iter().filter(|c| !addresses_by_chain.contains_key(*c)).collect();
            if !missing.is_empty() { bail!("Topology mismatch: {:?} missing from addresses file", missing); }

            // Warn about extra chains in addresses file
            let extra: Vec<_> = addresses_by_chain.keys().filter(|k| !chains.contains(k)).collect();
            if !extra.is_empty() { warn(&format!("Skipping chains not in config: {:?}", extra)); }

            for chain in chains {
                info(&format!("Whitelisting {}", chain));
                if let Some(dir) = &env_dir {
                    load_chain_env_files(dir, chain, get_chain_info(chain).ok_or_else(|| anyhow!("Unknown chain: {}", chain))?.network)?;
                }
                whitelist_actions_for_chain(chain, addresses_by_chain.get(chain).unwrap(), private_key.as_deref()).await?;
            }
            info(&format!("✓ Whitelisted {} chains", chains.len()));
            Ok(())
        }

        Commands::UpdateChainConfig { config_file, addresses_file, chain_config_file } => {
            let config = load_deploy_config(&config_file)?;
            update_chain_config(&config, &addresses_file, &chain_config_file).await
        }

        Commands::VerifyContracts { config_file, env_dir, protocol_root, etherscan_api_key, verifier } => {
            verify_contracts(&config_file, &env_dir, &protocol_root, etherscan_api_key.as_deref(), &verifier).await
        }

        Commands::CompareDirectories { dir1, dir2, ignore, show_diff } => {
            match compare_directories(&dir1, &dir2, ignore.as_deref(), show_diff) {
                Ok(true) => std::process::exit(0),
                Ok(false) => std::process::exit(1),
                Err(e) => {
                    eprintln!("Error: {}", e);
                    std::process::exit(1);
                }
            }
        }
    }
}

// --- Tests ---

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::NamedTempFile;

    #[test]
    fn test_update_env_file() {
        let temp_file = NamedTempFile::new().unwrap();
        fs::write(temp_file.path(), "# Comments\nEXISTING_VAR=old_value\nOTHER_VAR=unchanged").unwrap();

        let mut updates = HashMap::new();
        updates.insert("EXISTING_VAR".to_string(), "new_value".to_string());
        updates.insert("NEW_VAR".to_string(), "added_value".to_string());

        update_env_file(temp_file.path().to_str().unwrap(), &updates).unwrap();
        let content = fs::read_to_string(temp_file.path()).unwrap();

        assert!(content.contains("EXISTING_VAR=new_value"));
        assert!(content.contains("NEW_VAR=added_value"));
        assert!(content.contains("OTHER_VAR=unchanged"));
        assert!(content.contains("# Comments"));
        assert!(!content.contains("old_value"));
    }

    #[test]
    fn test_extract_address() {
        let forge_output = "OtimDelegate deployed at: 0x1234567890123456789012345678901234567890\nGateway deployed at: 0xabcdefabcdefabcdefabcdefabcdefabcdefabcd";

        assert_eq!(extract_address(forge_output, "OtimDelegate").unwrap(), "0x1234567890123456789012345678901234567890");
        assert_eq!(extract_address(forge_output, "Gateway").unwrap(), "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd");
        assert!(extract_address(forge_output, "NonexistentContract").is_err());
        assert!(extract_address("No deployment info", "OtimDelegate").is_err());
    }
}
