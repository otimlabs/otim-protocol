#!/usr/bin/env rust-script
//! ```cargo
//! [package]
//! name = "directory-comparison"
//! version = "0.1.0"
//! edition = "2021"
//! description = "A tool to compare directory contents using Merkle trees"
//!
//! [dependencies]
//! merkle_hash = "3.8"
//! clap = { version = "4.0", features = ["derive", "env"] }
//! camino = "1.0"
//! ```

use std::collections::HashMap;
use std::error::Error;
use std::process;
use merkle_hash::{MerkleTree, Encodable};
use clap::Parser;

#[derive(Parser)]
#[command(name = "directory-comparison")]
#[command(about = "Compare directory contents using Merkle trees")]
struct Cli {
    /// First directory to compare
    #[arg(env = "DIR1")]
    dir1: String,

    /// Second directory to compare
    #[arg(env = "DIR2")]
    dir2: String,

    /// Pattern to ignore during comparison
    #[arg(long, env = "IGNORE_PATTERN")]
    ignore: Option<String>,

    /// Show detailed differences when directories don't match
    #[arg(long, env = "SHOW_DIFF")]
    show_diff: bool,
}

fn main() {
    let cli = Cli::parse();

    match directories_match(&cli.dir1, &cli.dir2, cli.ignore.as_deref(), cli.show_diff) {
        Ok(true) => process::exit(0),
        Ok(false) => process::exit(1),
        Err(e) => {
            eprintln!("Error: {}", e);
            process::exit(1);
        }
    }
}

fn directories_match(dir1: &str, dir2: &str, ignore: Option<&str>, show_diff: bool) -> Result<bool, Box<dyn Error>> {
    let tree1 = MerkleTree::builder(dir1).build()?;
    let tree2 = MerkleTree::builder(dir2).build()?;

    let files1: HashMap<_, _> = tree1.iter()
        .filter(|i| !should_ignore_path(&i.path.relative, ignore))
        .map(|i| (i.path.relative.to_string(), i.hash.to_hex_string()))
        .collect();

    let files2: HashMap<_, _> = tree2.iter()
        .filter(|i| !should_ignore_path(&i.path.relative, ignore))
        .map(|i| (i.path.relative.to_string(), i.hash.to_hex_string()))
        .collect();

    let matches = files1 == files2;
    if !matches && show_diff {
        print_differences(&files1, &files2, dir1, dir2);
    }

    Ok(matches)
}

// -- Helper functions --

fn should_ignore_path(relative_path: &camino::Utf8Path, ignore: Option<&str>) -> bool {
    let path_str = relative_path.as_str();
    // Ignore empty paths
    if path_str.is_empty() {
        return true;
    }

    // Apply ignore pattern if provided
    ignore.map_or(false, |pattern| path_str.contains(pattern))
}

fn print_differences(files1: &HashMap<String, String>, files2: &HashMap<String, String>, _dir1: &str, dir2: &str) {
    let mut diff_count = 0;

    // Find different and missing files
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

    // Find extra files
    for path in files2.keys() {
        if !files1.contains_key(path) {
            println!("{}: extra in {}", path, dir2);
            diff_count += 1;
        }
    }

    println!("\n❌ Found {} differences", diff_count);
}

// -- Tests --

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::{self, File};
    use std::io::Write;
    use std::path::Path;

    fn write_file(dir: &Path, path: &str, content: &str) {
        let file_path = dir.join(path);
        if let Some(parent) = file_path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        File::create(file_path).unwrap().write_all(content.as_bytes()).unwrap();
    }

    #[test]
    fn test_identical_files() {
        let temp = std::env::temp_dir();
        let dir1 = temp.join("test1");
        let dir2 = temp.join("test2");

        fs::create_dir_all(&dir1).unwrap();
        fs::create_dir_all(&dir2).unwrap();

        write_file(&dir1, "file.txt", "content");
        write_file(&dir2, "file.txt", "content");

        assert!(directories_match(dir1.to_str().unwrap(), dir2.to_str().unwrap(), None, false).unwrap());

        fs::remove_dir_all(&dir1).ok();
        fs::remove_dir_all(&dir2).ok();
    }

    #[test]
    fn test_different_files() {
        let temp = std::env::temp_dir();
        let dir1 = temp.join("test3");
        let dir2 = temp.join("test4");

        fs::create_dir_all(&dir1).unwrap();
        fs::create_dir_all(&dir2).unwrap();

        write_file(&dir1, "file.txt", "content A");
        write_file(&dir2, "file.txt", "content B");

        assert!(!directories_match(dir1.to_str().unwrap(), dir2.to_str().unwrap(), None, false).unwrap());

        fs::remove_dir_all(&dir1).ok();
        fs::remove_dir_all(&dir2).ok();
    }

    #[test]
    fn test_ignore_pattern() {
        let temp = std::env::temp_dir();
        let dir1 = temp.join("test5");
        let dir2 = temp.join("test6");

        fs::create_dir_all(&dir1).unwrap();
        fs::create_dir_all(&dir2).unwrap();

        write_file(&dir1, "keep.txt", "same");
        write_file(&dir2, "keep.txt", "same");
        write_file(&dir1, "build-info/ignore.txt", "diff1");
        write_file(&dir2, "build-info/ignore.txt", "diff2");

        assert!(directories_match(dir1.to_str().unwrap(), dir2.to_str().unwrap(), Some("build-info"), false).unwrap());

        fs::remove_dir_all(&dir1).ok();
        fs::remove_dir_all(&dir2).ok();
    }
}
