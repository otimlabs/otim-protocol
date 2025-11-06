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

#[derive(Parser)]
#[command(name = "protocol-cli")]
#[command(about = "Protocol development and deployment tools")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Validate contract addresses against environment file
    ValidateContracts {
        /// Configuration file with network and contract details
        #[arg(short, long)]
        config_file: String,
        /// Environment file to source and compare against
        #[arg(short, long)]
        env_file: String,
        /// Update the environment file with newly calculated addresses
        #[arg(short, long)]
        update: bool,
    },

    /// Deploy contracts to a configured network
    DeployContracts {
        /// Configuration file with network and contract details
        #[arg(short, long)]
        config_file: String,
        /// Private key for deployment (if not provided, uses AWS KMS)
        #[arg(short, long)]
        private_key: Option<String>,
    },

    /// Whitelist actions within an action manager
    WhitelistActions {
        /// JSON file containing contract addresses (e.g., addresses.json from deploy)
        #[arg(short, long)]
        addresses_file: String,
        /// Private key for whitelisting (if not provided, uses AWS KMS)
        #[arg(short, long)]
        private_key: Option<String>,
    },

    /// Update chain configuration with deployed contract addresses for a specific network
    UpdateChainConfig {
        /// JSON file containing contract addresses (e.g., addresses.json from deploy)
        #[arg(short, long)]
        addresses_file: String,
        /// Chain config file to update
        #[arg(short, long)]
        chain_config_file: String,
        /// Network name to update (e.g., anvil, base-sepolia)
        #[arg(short, long)]
        network: String,
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
}

#[derive(Debug, serde::Deserialize)]
struct DeploymentConfig {
    contracts: Vec<String>,
}

#[derive(Debug, Clone)]
struct ContractDetails {
    script: Option<String>,
    expected_addr_envvar: Option<String>,
    chain_config_key: Option<String>,
}

#[derive(Debug, Clone)]
struct TierConfig {
    script: Option<String>, // For core tier group deployment
    contracts: HashMap<String, ContractDetails>,
}

/// Returns the tier-based contract mapping configuration
fn get_contract_mapping() -> HashMap<String, TierConfig> {
    use std::collections::HashMap;

    HashMap::from([
        ("core".to_string(), TierConfig {
            script: Some("DeployCore".to_string()),
            contracts: HashMap::from([
                ("OtimDelegate".to_string(), ContractDetails {
                    script: None, // Not used - tier script handles deployment
                    expected_addr_envvar: Some("EXPECTED_OTIM_DELEGATE_ADDRESS".to_string()),
                    chain_config_key: Some("otim_delegate_addr".to_string()),
                }),
                ("Gateway".to_string(), ContractDetails {
                    script: None, // Not used - tier script handles deployment
                    expected_addr_envvar: Some("EXPECTED_GATEWAY_ADDRESS".to_string()),
                    chain_config_key: Some("gateway_addr".to_string()),
                }),
                ("InstructionStorage".to_string(), ContractDetails {
                    script: None, // Not used - tier script handles deployment
                    expected_addr_envvar: Some("EXPECTED_INSTRUCTION_STORAGE_ADDRESS".to_string()),
                    chain_config_key: Some("instruction_storage_addr".to_string()),
                }),
                ("ActionManager".to_string(), ContractDetails {
                    script: None, // Not used - tier script handles deployment
                    expected_addr_envvar: Some("ACTION_MANAGER_ADDRESS".to_string()),
                    chain_config_key: Some("action_manager_addr".to_string()),
                }),
            ]),
        }),

        ("infrastructure".to_string(), TierConfig {
            script: None,
            contracts: HashMap::from([
                ("FeeTokenRegistry".to_string(), ContractDetails {
                    script: Some("DeployFeeTokenRegistry".to_string()),
                    expected_addr_envvar: Some("EXPECTED_FEE_TOKEN_REGISTRY_ADDRESS".to_string()),
                    chain_config_key: Some("fee_token_registry_addr".to_string()),
                }),
                ("Treasury".to_string(), ContractDetails {
                    script: Some("DeployTreasury".to_string()),
                    expected_addr_envvar: Some("EXPECTED_TREASURY_ADDRESS".to_string()),
                    chain_config_key: Some("treasury_addr".to_string()),
                }),
            ]),
        }),

        ("actions".to_string(), TierConfig {
            script: None,
            contracts: HashMap::from([
                ("TransferAction".to_string(), ContractDetails {
                    script: Some("DeployTransferAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_TRANSFER_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.transfer".to_string()),
                }),
                ("TransferERC20Action".to_string(), ContractDetails {
                    script: Some("DeployTransferERC20Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_TRANSFER_ERC20_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.transferERC20".to_string()),
                }),
                ("RefuelAction".to_string(), ContractDetails {
                    script: Some("DeployRefuelAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_REFUEL_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.refuel".to_string()),
                }),
                ("RefuelERC20Action".to_string(), ContractDetails {
                    script: Some("DeployRefuelERC20Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_REFUEL_ERC20_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.refuelERC20".to_string()),
                }),
                ("UniswapV3ExactInputAction".to_string(), ContractDetails {
                    script: Some("DeployUniswapV3ExactInputAction".to_string()),
                    expected_addr_envvar: Some("UNISWAP_V3_EXACT_INPUT_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.uniswapV3ExactInput".to_string()),
                }),
                ("DeactivateInstructionAction".to_string(), ContractDetails {
                    script: Some("DeployDeactivateInstructionAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_DEACTIVATE_INSTRUCTION_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.deactivateInstruction".to_string()),
                }),
                ("SweepAction".to_string(), ContractDetails {
                    script: Some("DeploySweepAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.sweep".to_string()),
                }),
                ("SweepERC20Action".to_string(), ContractDetails {
                    script: Some("DeploySweepERC20Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_ERC20_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.sweepERC20".to_string()),
                }),
                ("SweepCCTPAction".to_string(), ContractDetails {
                    script: Some("DeploySweepCCTPAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_CCTP_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.sweepCCTP".to_string()),
                }),
                ("TransferCCTPAction".to_string(), ContractDetails {
                    script: Some("DeployTransferCCTPAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_TRANSFER_CCTP_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.transferCCTP".to_string()),
                }),
                ("SweepUniswapV3Action".to_string(), ContractDetails {
                    script: Some("DeploySweepUniswapV3Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_UNISWAP_V3_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.sweepUniswapV3".to_string()),
                }),
                ("DepositERC4626Action".to_string(), ContractDetails {
                    script: Some("DeployDepositERC4626Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_DEPOSIT_ERC4626_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.depositERC4626".to_string()),
                }),
                ("SweepDepositERC4626Action".to_string(), ContractDetails {
                    script: Some("DeploySweepDepositERC4626Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_DEPOSIT_ERC4626_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.sweepDepositERC4626".to_string()),
                }),
                ("WithdrawERC4626Action".to_string(), ContractDetails {
                    script: Some("DeployWithdrawERC4626Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_WITHDRAW_ERC4626_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.withdrawERC4626".to_string()),
                }),
                ("SweepWithdrawERC4626Action".to_string(), ContractDetails {
                    script: Some("DeploySweepWithdrawERC4626Action".to_string()),
                    expected_addr_envvar: Some("EXPECTED_SWEEP_WITHDRAW_ERC4626_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.sweepWithdrawERC4626".to_string()),
                }),
                ("CallOnceAction".to_string(), ContractDetails {
                    script: Some("DeployCallOnceAction".to_string()),
                    expected_addr_envvar: Some("EXPECTED_CALL_ONCE_ACTION_ADDRESS".to_string()),
                    chain_config_key: Some("actions.callOnce".to_string()),
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

/// Loads and parses the deployment configuration from YAML file
fn load_config(config_path: &str) -> Result<DeploymentConfig> {
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
        // Replace the value for the specific key, preserving the rest of the file
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

/// Executes any command with proper environment setup
async fn run_command(command: &str, args: &[&str]) -> Result<String> {
    // Output the command being executed
    info(&format!("Executing: {} {}", command, args.join(" ")));

    let output = tokio::process::Command::new(command)
        .args(args)
        .env_clear()  // Clear existing environment
        .envs(env::vars())  // Add all current environment variables
        .output()
        .await?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("Command failed: {} {}\nError: {}", command, args.join(" "), stderr);
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Executes a forge dry-run command to calculate contract addresses without deployment
async fn run_forge_dry_run(script: &str) -> Result<String> {
    let args = vec!["script", script, "--json"];
    run_command("forge", &args).await
}

/// Executes a forge deployment command with private key or AWS KMS signing
async fn run_forge_deploy(script: &str, private_key: Option<&str>) -> Result<String> {
    let rpc_url = env::var("RPC_URL").context("RPC_URL not found")?;

    let mut args = vec![
        "script", script,
        "--broadcast",
        "--rpc-url", &rpc_url,
    ];

    if let Some(pk) = private_key {
        args.extend_from_slice(&["--private-key", pk]);
    } else {
        args.push("--aws");
    }

    args.push("--json");
    run_command("forge", &args).await
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
            let output = run_forge_dry_run(&script).await?;
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
async fn validate_addresses(config: &DeploymentConfig, env_file: &str, update: bool) -> Result<()> {
    info(&format!("Validating addresses against: {}", env_file));

    let original_env = load_env_file(env_file)?;
    let mut calculated_addresses = HashMap::new();
    let mut updates = HashMap::new();

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

    // Compare addresses and collect updates
    for (contract, calculated_address) in &calculated_addresses {
        if let Some(details) = find_contract_details(contract) {
            if let Some(env_var) = &details.expected_addr_envvar {
                let current_address = original_env.get(env_var).map(String::as_str).unwrap_or("NOT_SET");
                if current_address != calculated_address {
                    warn(&format!("{}: {} → {}", contract, current_address, calculated_address));
                    updates.insert(env_var.clone(), calculated_address.clone());
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
    if !updates.is_empty() {
        if update {
            update_env_file(env_file, &updates)?;
            info(&format!("Updated {}", env_file));
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

/// Checks if a forge deployment error is a known/expected error to ignore
fn is_known_deployment_error(error: &str) -> bool {
    error.contains("CreateCollision") ||
    error.contains("AlreadyAdded") ||
    error.contains("empty revert data")
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
        for contract in contracts {
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
                        Err(e) if is_known_deployment_error(&e.to_string()) => {
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
            } else if let Some(details) = tier_config.contracts.get(&contract) {
                // Deploy individual contract
                let script = details.script.clone().unwrap_or_else(|| format!("Deploy{}", contract));
                match run_forge_deploy(&script, private_key).await {
                    Ok(output) => {
                        if let Ok(addr) = extract_address(&output, &contract) {
                            info(&format!("✓ Deployed {}: {}", contract, addr));
                            all_addresses.insert(contract.clone(), addr.clone());
                            if let Some(env_var) = &details.expected_addr_envvar {
                                env::set_var(env_var, &addr);
                            }
                        }
                    }
                    Err(e) if is_known_deployment_error(&e.to_string()) => {
                        info(&format!("Contract {} already deployed", contract));
                        if let Some(env_var) = &details.expected_addr_envvar {
                            let existing_addr = env::var(env_var)
                                .with_context(|| format!("No existing address found for {} ({})", contract, env_var))?;
                            info(&format!("- Using existing {}: {}", contract, existing_addr));
                            all_addresses.insert(contract, existing_addr);
                        }
                    }
                    Err(e) => bail!("Contract {} deployment failed with unknown error: {}", contract, e),
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

/// Whitelists all action contracts in the action manager
async fn whitelist_actions(addresses_file: &str, private_key: Option<&str>) -> Result<()> {
    info("Starting action whitelisting...");

    let addresses: HashMap<String, String> = serde_json::from_str(&fs::read_to_string(addresses_file)?)
        .with_context(|| format!("Failed to parse addresses file: {}", addresses_file))?;

    let action_contracts: Vec<_> = addresses.iter()
        .filter(|(name, _)| name.ends_with("Action"))
        .collect();

    if action_contracts.is_empty() {
        info("No action contracts found in addresses file");
        return Ok(());
    }

    let rpc_url = env::var("RPC_URL")?;
    for (contract_name, action_address) in &action_contracts {
        info(&format!("Whitelisting {} at {}...", contract_name, action_address));

        let mut args = vec![
            "script", "AddAction", "--sig", "run(address)", "--broadcast",
            "--rpc-url", &rpc_url
        ];

        if let Some(pk) = private_key {
            args.extend_from_slice(&["--private-key", pk]);
        } else {
            args.push("--aws");
        }

        args.push(action_address);

        match run_command("forge", &args).await {
            Ok(_) => info(&format!("✓ {} whitelisted", contract_name)),
            Err(e) if e.to_string().contains("AlreadyAdded") => {
                info(&format!("- {} already whitelisted", contract_name));
            }
            Err(e) => bail!("Failed to whitelist {}: {}", contract_name, e),
        }
    }

    info(&format!("✓ Action whitelisting completed! Processed {} contracts", action_contracts.len()));
    Ok(())
}

// =============================================================================
// UPDATE CHAIN CONFIG
// =============================================================================

/// Update chain configuration with deployed contract addresses for a specific network
async fn update_chain_config(addresses_file: &str, chain_config_file: &str, network: &str) -> Result<()> {
    let addresses: HashMap<String, String> = serde_json::from_str(&fs::read_to_string(addresses_file)?)?;
    let mut chain_config: serde_json::Value = serde_json::from_str(&fs::read_to_string(chain_config_file)?)?;

    let target_key = chain_config.as_object()
        .and_then(|obj| obj.iter().find(|(_, v)| v.get("name").and_then(|n| n.as_str()) == Some(network)))
        .map(|(k, _)| k.clone())
        .ok_or_else(|| anyhow!("Network '{}' not found", network))?;

    let target_block = chain_config[&target_key].as_object_mut()
        .ok_or_else(|| anyhow!("Invalid network block"))?;

    let tier_mapping = get_contract_mapping();
    let mut changes = false;
    for (contract_name, address) in &addresses {
        if let Some(details) = tier_mapping.values().find_map(|tier| tier.contracts.get(contract_name)) {
            if let Some(key) = &details.chain_config_key {
                if let Some(action_name) = key.strip_prefix("actions.") {
                    let actions_obj = target_block.entry("actions").or_insert_with(|| json!({})).as_object_mut().unwrap();
                    if actions_obj.get(address).map(|v| v.as_str()) != Some(Some(action_name)) {
                        actions_obj.insert(address.clone(), json!(action_name));
                        changes = true;
                    }
                } else {
                    if target_block.get(key).and_then(|v| v.as_str()) != Some(address) {
                        target_block.insert(key.clone(), json!(address));
                        changes = true;
                    }
                }
            }
        }
    }

    if changes {
        fs::write(chain_config_file, serde_json::to_string_pretty(&chain_config)?)?;
        info(&format!("✓ Updated addresses for network '{}'", network));
        std::process::exit(2);
    } else {
        info(&format!("No changes needed for network '{}'", network));
        std::process::exit(0);
    }
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
        Commands::ValidateContracts { config_file, env_file, update } => {
            let config = load_config(&config_file)?;
            validate_addresses(&config, &env_file, update).await
        }

        Commands::DeployContracts { config_file, private_key } => {
            let config = load_config(&config_file)?;
            let addresses = deploy_contracts(&config, private_key.as_deref()).await?;

            // Write addresses to file
            let json_content = serde_json::to_string_pretty(&addresses)?;
            std::fs::write("deployed-addresses.json", json_content)?;
            info("Contract addresses written to deployed-addresses.json");

            Ok(())
        }

        Commands::WhitelistActions { addresses_file, private_key } => {
            whitelist_actions(&addresses_file, private_key.as_deref()).await
        }

        Commands::UpdateChainConfig { addresses_file, chain_config_file, network } => {
            update_chain_config(&addresses_file, &chain_config_file, &network).await
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
