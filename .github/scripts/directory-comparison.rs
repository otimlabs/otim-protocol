#!/usr/bin/env rust-script
//! ```cargo
//! [package]
//! name = "directory-comparison"
//! version = "0.1.0"
//! edition = "2021"
//! description = "A tool to compare directory contents using Merkle trees"
//!
//! [dependencies]
//! merkle_hash = "3.7"
//! ```

use std::collections::HashMap;
use std::env;
use std::error::Error;
use std::path::Path;
use std::process;
use merkle_hash::{MerkleTree, Encodable};

fn main() {
    let args: Vec<String> = env::args().collect();
    
    if args.len() < 3 || args.len() > 4 {
        eprintln!("Usage: {} <dir1> <dir2> [ignore_pattern]", args[0]);
        process::exit(1);
    }
    
    let dir1 = &args[1];
    let dir2 = &args[2];
    let ignore = args.get(3).map(String::as_str);

    match compare_dirs(dir1, dir2, ignore) {
        Ok((is_match, output)) => {
            println!("{output}");
            if is_match {
                process::exit(0);
            } else {
                process::exit(1);
            }
        },
        Err(e) => {
            eprintln!("Error: {}", e);
            process::exit(1);
        }
    }
}

fn compare_dirs(dir1: &str, dir2: &str, ignore: Option<&str>) -> Result<(bool, String), Box<dyn Error>> {
    // Build directory trees and get file hashes
    let tree1 = MerkleTree::builder(dir1).build()?;
    let tree2 = MerkleTree::builder(dir2).build()?;
    
    // Convert to hash maps, filtering by ignore pattern and directories
    let files1: HashMap<_, _> = tree1.iter()
        .filter(|i| {
            // Filter out empty paths
            !i.path.relative.to_string().is_empty() && 
            // Apply ignore pattern if provided
            ignore.map_or(true, |p| !i.path.relative.to_string().contains(p)) &&
            // Only include files, skip directories
            Path::new(dir1).join(&i.path.relative.to_string()).is_file()
        })
        .map(|i| (i.path.relative.to_string(), i.hash.to_hex_string()))
        .collect();

    let files2: HashMap<_, _> = tree2.iter()
        .filter(|i| {
            !i.path.relative.to_string().is_empty() && 
            ignore.map_or(true, |p| !i.path.relative.to_string().contains(p)) &&
            Path::new(dir2).join(&i.path.relative.to_string()).is_file()
        })
        .map(|i| (i.path.relative.to_string(), i.hash.to_hex_string()))
        .collect();

    // Collect differences
    let mut diffs = Vec::new();
    for (path, hash1) in &files1 {
        if let Some(hash2) = files2.get(path) {
            if hash1 != hash2 {
                diffs.push((path.clone(), Some((hash1.clone(), hash2.clone()))));
            }
        } else {
            diffs.push((format!("{} (only in {})", path, dir1), None));
        }
    }

    for path in files2.keys() {
        if !files1.contains_key(path) {
            diffs.push((format!("{} (only in {})", path, dir2), None));
        }
    }

    // Show results
    let mut output = String::new();
    if diffs.is_empty() {
        output.push_str("Content matches: All files are identical");
        Ok((true, output))
    } else {
        output.push_str("Content diffs:");
        for (path, hash_diff) in &diffs {
            let line = if let Some((hash1, hash2)) = hash_diff {
                format!("- {} [{}≠{}]", path, &hash1[..8], &hash2[..8])
            } else {
                format!("- {}", path)
            };
            
            output.push_str("\n");
            output.push_str(&line);
        }

        Ok((false, output))
    }
}

// --- Unit Tests ---
#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::{self, File};
    use std::io::Write;
    use std::path::{Path, PathBuf};

    // Create a test directory structure with dir1 and dir2 subdirectories
    fn setup_test_dirs(name: &str) -> (PathBuf, PathBuf, PathBuf) {
        let test_dir = std::env::temp_dir().join(format!("artifact_test_{}", name));
        if test_dir.exists() {
            let _ = fs::remove_dir_all(&test_dir);
        }

        let dir1 = test_dir.join("dir1");
        let dir2 = test_dir.join("dir2");

        fs::create_dir_all(&dir1).unwrap();
        fs::create_dir_all(&dir2).unwrap();
        
        (test_dir, dir1, dir2)
    }

    // Write file, ensuring parent directories exist
    fn write_file(dir: &Path, relative_path: &str, content: &str) {
        let file_path = dir.join(relative_path);
        if let Some(parent) = file_path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        File::create(&file_path).unwrap().write_all(content.as_bytes()).unwrap();
    }

    fn run_comparison(dir1: &Path, dir2: &Path, ignore_pattern: Option<&str>) -> (bool, String) {
        let dir1_str = dir1.to_str().unwrap();
        let dir2_str = dir2.to_str().unwrap();
    
        match compare_dirs(dir1_str, dir2_str, ignore_pattern) {
            Ok((matches, output)) => (matches, output),
            Err(e) => (false, format!("Error: {}", e)),
        }
    }

    #[test]
    fn test_identical_content() {
        let (test_dir, dir1, dir2) = setup_test_dirs("identical");

        // Create identical files
        write_file(&dir1, "file.txt", "same content");
        write_file(&dir2, "file.txt", "same content");

        // Test comparison
        let (success, output) = run_comparison(&dir1, &dir2, None);

        assert!(success, "Identical files should match");
        assert!(output.contains("Content matches"), "Output should indicate matching content");
        
        let _ = fs::remove_dir_all(test_dir);
    }

    #[test]
    fn test_different_content() {
        let (test_dir, dir1, dir2) = setup_test_dirs("different");

        // Create files with different content
        write_file(&dir1, "file.txt", "content A");
        write_file(&dir2, "file.txt", "content B");

        // Test comparison
        let (success, output) = run_comparison(&dir1, &dir2, None);

        assert!(!success, "Different files should not match");
        assert!(output.contains("Content diffs"), "Output should indicate content differences");

        // Check that all paths in output are actual files
        for path_str in output.lines()
            .filter(|line| line.starts_with("- "))
            .map(|line| line.split_whitespace().nth(1).unwrap())
        {
            // At least one of the directories should have this as a file
            assert!(
                (dir1.join(path_str).exists() && dir1.join(path_str).is_file()) || 
                (dir2.join(path_str).exists() && dir2.join(path_str).is_file()),
                "Path should be a file: {}", path_str
            );
        }

        let _ = fs::remove_dir_all(test_dir);
    }

    #[test]
    fn test_ignore_pattern_ignored() {
        let (test_dir, dir1, dir2) = setup_test_dirs("ignore_pattern");

        // Create identical regular files
        write_file(&dir1, "regular.txt", "same content");
        write_file(&dir2, "regular.txt", "same content");

        // Create different build-info files
        write_file(&dir1, "build-info/metadata", "version 1");
        write_file(&dir2, "build-info/metadata", "version 2");
        
        // Test comparison with build-info ignored
        let (success, output) = run_comparison(&dir1, &dir2, Some("build-info"));

        assert!(success, "Should match when build-info differences are ignored");
        assert!(output.contains("Content matches"), "Output should indicate matching content");
        
        let _ = fs::remove_dir_all(test_dir);
    }

    #[test]
    fn test_ignore_pattern_with_other_diffs() {
        let (test_dir, dir1, dir2) = setup_test_dirs("ignore_pattern_with_other_diffs");

        // Create different files in both ignored and non-ignored paths
        write_file(&dir1, "build-info/metadata", "version 1");
        write_file(&dir2, "build-info/metadata", "version 2");
        write_file(&dir1, "src/main.rs", "fn main() {}");
        write_file(&dir2, "src/main.rs", "fn main() { println!(\"Hello\"); }");

        // Test comparison with build-info ignored
        let (success, output) = run_comparison(&dir1, &dir2, Some("build-info"));

        assert!(!success, "Should not match when non-ignored differences exist");
        assert!(output.contains("Content diffs"), "Output should indicate content differences");
        // Verify that the ignored pattern is not in the output
        assert!(!output.contains("build-info"), "Output should not contain the ignored pattern");

        let _ = fs::remove_dir_all(test_dir);
    }

    #[test]
    fn test_multiple_differences() {
        let (test_dir, dir1, dir2) = setup_test_dirs("multiple");

        // Create mix of identical and different files
        write_file(&dir1, "same.txt", "identical");
        write_file(&dir2, "same.txt", "identical");
        write_file(&dir1, "diff1.txt", "version A");
        write_file(&dir2, "diff1.txt", "version B");
        write_file(&dir1, "diff2.txt", "foo");
        write_file(&dir2, "diff2.txt", "bar");

        // Test comparison
        let (success, output) = run_comparison(&dir1, &dir2, None);

        assert!(!success, "Different files should not match");
        assert!(output.contains("Content diffs"), "Output should indicate content differences");
        assert!(!output.contains("same.txt"), "Output should not mention same.txt");

        assert!(output.contains("diff1.txt"), "Output should mention diff1.txt");
        assert!(output.contains("diff2.txt"), "Output should mention diff2.txt");
        
        let _ = fs::remove_dir_all(test_dir);
    }
}
