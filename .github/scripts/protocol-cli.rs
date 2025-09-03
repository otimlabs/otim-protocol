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
use indexmap::IndexMap;
use merkle_hash::{MerkleTree, Encodable};
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
    },

    /// Whitelist actions within an action manager
    WhitelistActions {
        /// JSON file containing contract addresses (e.g., addresses.json from deploy)
        #[arg(short, long)]
        addresses_file: String,
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
    contracts: HashMap<String, TierConfig>,
}

#[derive(Debug, serde::Deserialize)]
struct TierConfig {
    #[serde(default)]
    script: Option<String>,
    contracts: IndexMap<String, ContractDetails>,
}

#[derive(Debug, serde::Deserialize)]
struct ContractDetails {
    script: Option<String>,
    expected_addr_envvar: Option<String>,
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

/// Retrieves configuration for a specific deployment tier
fn get_tier_config<'a>(config: &'a DeploymentConfig, tier: &str) -> Result<&'a TierConfig> {
    config.contracts
        .get(tier)
        .ok_or_else(|| anyhow!("Tier not found: {}", tier))
}

/// Finds contract details by searching across all deployment tiers
fn find_contract_details<'a>(config: &'a DeploymentConfig, contract: &str) -> Option<&'a ContractDetails> {
    config.contracts
        .values()
        .find_map(|tier| tier.contracts.get(contract))
}

/// Loads environment variables from file and sets them in the current process
fn load_env_file(path: &str) -> Result<HashMap<String, String>> {
    if !Path::new(path).exists() {
        bail!("Environment file not found: {}", path);
    }
    
    let content = fs::read_to_string(path)?;
    let mut expected_addr_envvars = HashMap::new();
    
    for line in content.lines() {
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
    let content = fs::read_to_string(path)
        .with_context(|| format!("Failed to read environment file: {}", path))?;
    
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

/// Executes a forge deployment command with AWS KMS signing
async fn run_forge_deploy(script: &str) -> Result<String> {
    let rpc_url = env::var("RPC_URL").context("RPC_URL not found")?;
    let args = vec![
        "script", script,
        "--broadcast",
        "--rpc-url", &rpc_url,
        "--aws",
        "--json"
    ];
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
    let tier_config = get_tier_config(config, tier)?;
    let mut addresses = HashMap::new();

    if let Some(script) = &tier_config.script {
        let output = run_forge_dry_run(script).await?;
        for (contract, details) in &tier_config.contracts {
            // Skip contracts without expected_addr_envvar property
            if details.expected_addr_envvar.is_none() {
                info(&format!("Skipping {} - no expected_addr_envvar configured", contract));
                continue;
            }
            addresses.insert(contract.clone(), extract_address(&output, contract)?);
        }
    } else {
        for (contract, details) in &tier_config.contracts {
            // Skip contracts without expected_addr_envvar property
            if details.expected_addr_envvar.is_none() {
                info(&format!("Skipping {} - no expected_addr_envvar configured", contract));
                continue;
            }
            let script = details.script.as_ref()
                .map(|s| s.clone())
                .unwrap_or_else(|| format!("Deploy{}", contract));
            let output = run_forge_dry_run(&script).await?;
            addresses.insert(contract.clone(), extract_address(&output, contract)?);
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
            if let Some(ContractDetails { expected_addr_envvar: Some(env_var), .. }) = find_contract_details(config, contract) {
                env::set_var(env_var, address);
            }
        }
        
        calculated_addresses.extend(addresses);
    }

    // Compare addresses and collect updates
    for (contract, calculated_address) in &calculated_addresses {
        if let Some(ContractDetails { expected_addr_envvar: Some(env_var), .. }) = find_contract_details(config, contract) {
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
    }

    // Apply updates and/or report differences
    if !updates.is_empty() {
        if update {
            update_env_file(env_file, &updates)?;
            info(&format!("Updated {}", env_file));
        } else {
            info("Address differences detected. Use --update to apply changes.");
            std::process::exit(1);
        }
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
async fn deploy_contracts(config: &DeploymentConfig) -> Result<HashMap<String, String>> {
    info("Deploying contracts...");
    let mut all_addresses = HashMap::new();

    for tier in ["core", "infrastructure", "actions"] {
        info(&format!("Deploying {} contracts...", tier));
        let tier_config = get_tier_config(config, tier)?;

        if let Some(script) = &tier_config.script {
            // Single script for entire tier
            match run_forge_deploy(script).await {
                Ok(output) => {
                    for (contract, _) in &tier_config.contracts {
                        if let Ok(addr) = extract_address(&output, contract) {
                            info(&format!("Deployed {}: {}", contract, addr));
                            all_addresses.insert(contract.clone(), addr);
                        }
                    }
                }
                Err(e) => {
                    if is_known_deployment_error(&e.to_string()) {
                        info(&format!("Tier {} already deployed", tier));
                    } else {
                        info(&format!("Tier {} deployment failed: {}", tier, e));
                    }
                }
            }
        } else {
            // Individual scripts per contract
            for (contract, details) in &tier_config.contracts {
                let script = details.script.as_ref()
                    .map(|s| s.clone())
                    .unwrap_or_else(|| format!("Deploy{}", contract));
                
                match run_forge_deploy(&script).await {
                    Ok(output) => {
                        if let Ok(address) = extract_address(&output, contract) {
                            info(&format!("Deployed {}: {}", contract, address));
                            all_addresses.insert(contract.clone(), address);
                        }
                    }
                    Err(e) => {
                        if is_known_deployment_error(&e.to_string()) {
                            info(&format!("Contract {} already deployed", contract));
                        } else {
                            info(&format!("Failed to deploy {}: {}", contract, e));
                        }
                    }
                }
            }
        }

        // Update environment for next tier dependencies
        for (contract, address) in &all_addresses {
            if let Some(ContractDetails { expected_addr_envvar: Some(expected_addr_envvar), .. }) = find_contract_details(config, &contract) {
                env::set_var(expected_addr_envvar, &address);
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
async fn whitelist_actions(addresses_file: &str) -> Result<()> {
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
        
        let args = vec![
            "script", "AddAction", "--sig", "run(address)", "--broadcast",
            "--rpc-url", &rpc_url, "--aws", action_address
        ];
        
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
        print_differences(&files1, &files2, dir1, dir2);
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

fn print_differences(files1: &HashMap<String, String>, files2: &HashMap<String, String>, _dir1: &str, dir2: &str) {
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

        Commands::DeployContracts { config_file } => {
            let config = load_config(&config_file)?;
            let addresses = deploy_contracts(&config).await?;
            
            // Write addresses to file
            let json_content = serde_json::to_string_pretty(&addresses)?;
            std::fs::write("addresses.json", json_content)?;
            info("Contract addresses written to addresses.json");
            
            Ok(())
        }

        Commands::WhitelistActions { addresses_file } => {
            whitelist_actions(&addresses_file).await
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

