# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2025-10-28

### Added

- **Data Governance Lab**: New optional lab exploring Schema Registry, Data Contracts, Business Metadata, and governance tags with guest service request schema
- **Agent Deployment to Unity Catalog**: the Agent is now accessible via AI Playground

### Changed

- **Agent Configuration**: Updated notebook to leverage Databricks Unity Catalog and Mosaic AI functionality
- **Resource Discovery**: Implemented automatic detection of LLM endpoints, catalogs, databases, and warehouses with priority-based selection
- **Terraform Naming**: Shortened project name (`tableflow-databricks` → `tfdb`) and removed redundant suffixes to stay within Databricks 64-character function name limit
- **Image Organization**: Reorganized images from generic `assets/images/` to specific `labs/LABX/images/` directories for better structure
- **Error Messaging**: Enhanced configuration validation with clearer instructions for missing or incomplete setup

### Fixed

- **Step Numbering**: Fixed inconsistent and redundant step numbering in agent notebook after multiple reorganizations

### Removed

- **Duplicate and Unused Images**: Deleted `confluent_environment_catalog_management copy.png` and other redundant image files
- **Redundant Documentation**: Consolidated repetitive sections in Data Governance lab (reduced "What You'll Learn" + "Key Technologies" into single "What You'll Explore" section)

## [0.3.0] - 2025-09-16

### Added

- **Unity Catalog Integration**: Steps for configuring streamlined Tableflow integration with Databricks via Unity Catalog
- **Tableflow Upsert Support**: Shifted `hotel_stats` processing into Confluent Cloud Flink using new upsert changelog format
- **Lab Navigation**: Standardized all labs with unified intro/outro formats, mermaid workflow diagrams, and navigation links
- **Visual Learning Aids**: Workflow diagrams added to labs for improved concept visualization

### Changed

- **Documentation Structure**: Restructured `flink-joins.md` from troubleshooting guide to comprehensive discovery journey with experiment results and context-specific recommendations
- **Content Organization**: Split labs into smaller, more feature-specific files for better modularity
- **Streaming Joins Strategy**: Migrated to snapshot tables + interval joins for reliable CDC processing with hybrid timestamp strategy
- **Oracle Infrastructure**: Enhanced Terraform configuration with pre-created tables, proper primary key constraints for XStream CDC
- **Data Generation Volumes**: Optimized to 1,000 customers and 400 bookings for better workshop performance

### Fixed

- **Duplicate Booking IDs**: Resolved issue causing duplicate booking ID generation in data generation
- **Troubleshooting Content**: Updated guides with proven working solutions and removed outdated advice that caused failures

## [0.2.0] - 2025-07-15

### Changed

- **AI Agent Documentation**: Updated to accurately reflect notebook functionality (hotel selection, review analysis, customer targeting)
- **Content Clarity**: Improved language for better readability and streamlined explanations
- **Naming Conventions**: Standardized product naming and markdown formatting across all files

### Removed

- **Flink Native Inference**: Removed feature (temporarily)

### Fixed

- **Spelling and Formatting**: Corrected errors and inconsistencies across all markdown files

## [0.1.0] - 2025-06-12

### Added

- Initial workshop release with Labs 1-7
- Oracle XStream CDC integration
- Confluent Tableflow configuration
- Databricks AI agent notebook
- ShadowTraffic data generation
- Multi-cloud Terraform infrastructure
