#!/usr/bin/env rust-script
//! ```cargo
//! [package]
//! name = "contract-deploy-ci"
//! version = "0.1.0"
//! edition = "2021"
//! description = "Contract deployment automation with address validation and chain config generation"
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
//! ```

use anyhow::{anyhow, Context, Result, bail};
use clap::{Parser, Subcommand};
use colored::*;
use indexmap::IndexMap;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::Path;

#[derive(Parser)]
#[command(name = "contract-deployer")]
#[command(about = "Contract deployment automation")]
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

    /// Deploy contracts to specified network
    DeployContracts {
        /// Configuration file with network and contract details
        #[arg(short, long)]
        config_file: String,
        /// Target network for deployment
        #[arg(short, long)]
        network: String,
    },
}

#[derive(Debug, serde::Deserialize)]
struct DeploymentConfig {
    networks: Vec<String>,
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
    env_var: String,
}

struct DeploymentManager {
    config: Option<DeploymentConfig>,
}

impl DeploymentManager {
    fn with_config(config_path: &str) -> Result<Self> {
        let config = Self::load_config(config_path)?;
        Ok(Self { config: Some(config) })
    }

    // =============================================================================
    // UTILITY FUNCTIONS
    // =============================================================================

    /// Loads and parses the deployment configuration from YAML file
    fn load_config(config_path: &str) -> Result<DeploymentConfig> {
        let content = fs::read_to_string(config_path)
            .with_context(|| format!("Failed to read config file: {}", config_path))?;
        serde_yaml::from_str(&content)
            .with_context(|| "Failed to parse deployment config")
    }

    /// Returns a reference to the loaded deployment configuration
    fn get_config(&self) -> Result<&DeploymentConfig> {
        self.config.as_ref().ok_or_else(|| anyhow!("Configuration not loaded"))
    }

    /// Retrieves configuration for a specific deployment tier
    fn get_tier_config(&self, tier: &str) -> Result<&TierConfig> {
        self.get_config()?
            .contracts
            .get(tier)
            .ok_or_else(|| anyhow!("Tier not found: {}", tier))
    }

    /// Loads environment variables from file and sets them in the current process
    fn load_env_file(path: &str) -> Result<HashMap<String, String>> {
        if !Path::new(path).exists() {
            bail!("Environment file not found: {}", path);
        }
        
        let content = fs::read_to_string(path)?;
        let mut env_vars = HashMap::new();
        
        for line in content.lines() {
            if let Some((key, value)) = line.split_once('=') {
                let key = key.trim();
                let value = value.trim();
                env_vars.insert(key.to_string(), value.to_string());
                env::set_var(key, value);
            }
        }
        
        Ok(env_vars)
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

    /// Executes a forge dry-run command to calculate contract addresses without deployment
    async fn run_forge_dry_run(&self, script: &str) -> Result<String> {
        let output = tokio::process::Command::new("forge")
            .args(&["script", script, "--json"])
            .output()
            .await?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            bail!("Forge dry-run failed for {}: {}", script, stderr);
        }
        
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }

    /// Executes a forge deployment command with AWS KMS signing
    async fn run_forge_deploy(&self, script: &str) -> Result<String> {
        let output = tokio::process::Command::new("forge")
            .args(&[
                "script", script,
                "--broadcast",
                "--rpc-url", &env::var("RPC_URL").context("RPC_URL not found")?,
                "--aws",
                "--json"
            ])
            .output()
            .await?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            bail!("Deployment failed for {}: {}", script, stderr);
        }
        
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }

    // =============================================================================
    // ADDRESS VALIDATION
    // =============================================================================

    /// Extracts contract address from forge deployment output using regex pattern matching
    fn extract_address(&self, output: &str, contract: &str) -> Result<String> {
        use regex::Regex;
        
        let re = Regex::new(&format!(r"{} deployed at: (0x[a-fA-F0-9]{{40}})", contract))?;
        re.captures(output)
            .and_then(|caps| caps.get(1))
            .map(|m| m.as_str().to_string())
            .ok_or_else(|| anyhow!("Address not found for {}", contract))
    }

    /// Validates calculated contract addresses against environment file values
    async fn validate_addresses(&self, env_file: &str, update: bool) -> Result<()> {
        info(&format!("Validating addresses against: {}", env_file));
        
        let _config = self.get_config()?;
        
        let current_env = Self::load_env_file(env_file)?;
        let mut calculated_addresses = HashMap::new();
        let mut updates = HashMap::new();
        let mut has_changes = false;

        // Calculate addresses in deployment order
        for tier in ["core", "infrastructure", "actions"] {
            info(&format!("Calculating {} addresses...", tier));
            let addresses = self.calculate_addresses_by_tier(tier).await?;
            
            for (contract, address) in &addresses {
                calculated_addresses.insert(contract.clone(), address.clone());
                if let Some(details) = self.find_contract_details(contract) {
                    env::set_var(&details.env_var, address);
                }
            }
        }

        // Compare and update if needed
        for (contract, calculated_address) in &calculated_addresses {
            if let Some(details) = self.find_contract_details(contract) {
                let current_address = current_env.get(&details.env_var)
                    .cloned()
                    .unwrap_or_else(|| "NOT_SET".to_string());
                
                if current_address != *calculated_address {
                    has_changes = true;
                    info(&format!("{}: {} → {}", 
                        contract, current_address, calculated_address));
                    
                    if update {
                        updates.insert(details.env_var.clone(), calculated_address.clone());
                    }
                }
            }
        }

        if has_changes {
            if update {
                Self::update_env_file(env_file, &updates)?;
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

    /// Calculates contract addresses for a specific deployment tier using dry-run
    async fn calculate_addresses_by_tier(&self, tier: &str) -> Result<HashMap<String, String>> {
        let tier_config = self.get_tier_config(tier)?;
        let mut addresses = HashMap::new();

        if let Some(script) = &tier_config.script {
            let output = self.run_forge_dry_run(script).await?;
            for (contract, _) in &tier_config.contracts {
                addresses.insert(contract.clone(), self.extract_address(&output, contract)?);
            }
        } else {
            for (contract, details) in &tier_config.contracts {
                let script = details.script.as_ref()
                    .map(|s| s.clone())
                    .unwrap_or_else(|| format!("Deploy{}", contract));
                let output = self.run_forge_dry_run(&script).await?;
                addresses.insert(contract.clone(), self.extract_address(&output, contract)?);
            }
        }

        Ok(addresses)
    }

    /// Finds contract details by searching across all deployment tiers
    fn find_contract_details(&self, contract: &str) -> Option<&ContractDetails> {
        self.get_config().ok()?
            .contracts
            .values()
            .find_map(|tier| tier.contracts.get(contract))
    }

    // =============================================================================
    // CONTRACT DEPLOYMENT
    // =============================================================================

    /// Deploys all contracts to the specified network in tier order
    async fn deploy_contracts(&self, network: &str) -> Result<()> {
        info(&format!("Deploying contracts to: {}", network));
        
        let config = self.get_config()?;

        // Validate network exists
        if !config.networks.contains(&network.to_string()) {
            bail!("Network '{}' not found in configuration", network);
        }

        // Deploy in tier order
        for tier in ["core", "infrastructure", "actions"] {
            info(&format!("Deploying {} contracts...", tier));
            
            match self.deploy_contracts_by_tier(tier).await {
                Ok(addresses) => {
                    info(&format!("{} tier deployed:", tier));
                    for (contract, address) in &addresses {
                        info(&format!("  {}: {}", contract, address));
                        
                        // Update environment for next tier dependencies
                        if let Some(details) = self.find_contract_details(contract) {
                            env::set_var(&details.env_var, address);
                        }
                    }
                }
                Err(e) => {
                    let error_msg = e.to_string();
                    if error_msg.contains("CreateCollision") || 
                       error_msg.contains("AlreadyAdded") ||
                       error_msg.contains("empty revert data") {
                        info(&format!("{} contracts already deployed", tier));
                    } else {
                        bail!("Deployment failed for {} on {}: {}", tier, network, e);
                    }
                }
            }
        }

        info(&format!("Deployment to {} completed", network));
        Ok(())
    }

    /// Deploys all contracts in a specific tier and returns their addresses
    async fn deploy_contracts_by_tier(&self, tier: &str) -> Result<HashMap<String, String>> {
        let tier_config = self.get_tier_config(tier)?;
        let mut addresses = HashMap::new();

        if let Some(script) = &tier_config.script {
            let output = self.run_forge_deploy(script).await?;
            for (contract, _) in &tier_config.contracts {
                addresses.insert(contract.clone(), self.extract_address(&output, contract)?);
            }
        } else {
            for (contract, details) in &tier_config.contracts {
                let script = details.script.as_ref()
                    .map(|s| s.clone())
                    .unwrap_or_else(|| format!("Deploy{}", contract));
                let output = self.run_forge_deploy(&script).await?;
                addresses.insert(contract.clone(), self.extract_address(&output, contract)?);
            }
        }

        Ok(addresses)
    }
}

/// Prints an informational message with colored formatting
fn info(msg: &str) {
    println!("{} {}", "[INFO]".green().bold(), msg);
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    match cli.command {
        Commands::ValidateContracts { config_file, env_file, update } => {
            DeploymentManager::with_config(&config_file)?
                .validate_addresses(&env_file, update).await
        }

        Commands::DeployContracts { config_file, network } => {
            DeploymentManager::with_config(&config_file)?
                .deploy_contracts(&network).await
        }
    }
}

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

        DeploymentManager::update_env_file(temp_file.path().to_str().unwrap(), &updates).unwrap();
        let content = fs::read_to_string(temp_file.path()).unwrap();
        
        assert!(content.contains("EXISTING_VAR=new_value"));
        assert!(content.contains("NEW_VAR=added_value"));
        assert!(content.contains("OTHER_VAR=unchanged"));
        assert!(content.contains("# Comments"));
        assert!(!content.contains("old_value"));
    }

    #[test]
    fn test_extract_address() {
        let manager = DeploymentManager { config: None };
        let forge_output = "OtimDelegate deployed at: 0x1234567890123456789012345678901234567890\nGateway deployed at: 0xabcdefabcdefabcdefabcdefabcdefabcdefabcd";
        
        assert_eq!(manager.extract_address(forge_output, "OtimDelegate").unwrap(), "0x1234567890123456789012345678901234567890");
        assert_eq!(manager.extract_address(forge_output, "Gateway").unwrap(), "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd");
        assert!(manager.extract_address(forge_output, "NonexistentContract").is_err());
        assert!(manager.extract_address("No deployment info", "OtimDelegate").is_err());
    }
}
