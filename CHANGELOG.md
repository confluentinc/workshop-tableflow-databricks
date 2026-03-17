# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2026-03-17

### Added

- **Confluent Flink Statements Module**: Terraform-managed ALTER TABLE statements for changelog mode and watermarks on CDC topics, replacing manual CTAS
- **Hotel Streaming Generator**: Added `hotel_generator_streaming` to workshop config and `shadowtraffic.tf` provisioner for hotel dimension watermark advancement

### Changed

- **Lab Renumbering**: Stream processing → LAB3, Tableflow → LAB4, analytics/AI → LAB5, wrap-up → LAB6; removed former LAB3 catalog integration
- **Historical Generators**: Compressed time spans (booking: 200 events over ~6–12h; review: 200 events over ~6–12h; hotel streaming: every 25s). Added `min()` cap on `clickstream_created_at`

### Fixed

- **Stalled Temporal Join Watermarks**: Resolved denormalized bookings CTAS watermark stall via reduced backlog and hotel streaming (see `FIXING_STALLED_WATERMARKS.md`)

## [0.8.0] - 2026-03-11

### Added

- **WSA Orchestration Support**: Added `wsa-spec-aws.yaml` and `wsa-spec-azure.yaml` for automated provisioning of up to 95 workshop accounts via `wsa build`/`wsa clean`
- **Instructor-Led Lab Track**: Restructured labs into `labs/instructor-led/` (LAB1-LAB7) optimized for guided workshops with pre-provisioned infrastructure

### Changed

- **Notebook Configuration (LAB6)**: Updated `river_hotel_marketing_agent.ipynb` Step 1.2 to direct instructor-led participants to their workshop email for `catalog`, `schema`, and `warehouse_id` values, with `terraform output` fallback for self-service users

## [0.7.0] - 2026-01-20

### Added

- **Tableflow DLQ Error Handling**: Added optional [Step 3](./labs/LAB4_tableflow/LAB4.md#step-3-configure-error-handling-optional) to LAB4 documenting Dead Letter Queue (DLQ) configuration for handling materialization failures, including comparison with Data Contract DLQ

## [0.6.0] - 2025-12-16

### Added

- **Streaming Generators**: Split data generators into historical and streaming variants for customers and hotels (`customer_generator_streaming.json`, `hotel_generator_streaming.json`)
- **Stream Processing Guide**: Created comprehensive `stream-processing-insights.md` documenting temporal joins, changelog modes, state TTL, and windowed aggregations

### Changed

- **Temporal Joins Implementation**: Migrated LAB5 from regular joins to temporal joins with snapshot dimension tables (`customer_snapshot`, `hotel_snapshot`) for point-in-time CDC lookups
- **Data Generator Updates**: Adjusted booking, clickstream, and review generators with improved timestamp handling and data schemas
- **Shadow Traffic Configuration**: Updated to support new historical/streaming generator split with proper scheduling stages

### Removed

- **flink-joins.md**: Consolidated content into `stream-processing-insights.md`

### Fixed

- **PostgreSQL Timestamp Error**: Resolved `column "created_at" is of type timestamp with time zone but expression is of type character varying` by using proper timestamp serialization in streaming generators
- **Agent Code Restoration**: Re-added agent creation code to the Databricks notebook

## [0.5.0] - 2025-12-09

### Added

- **Windows/WSL Documentation**: Setup instructions for Windows users with WSL 2 and Ubuntu
- **Docker Cross-Platform Fixes**: CRLF line ending conversion and `aws-config/.gitkeep` for Windows compatibility

### Changed

- **PostgreSQL Replaces Oracle**: Migrated database infrastructure from Oracle to PostgreSQL with modularized Terraform
- **ShadowTraffic Upgrade**: Updated to version 1.11.13
- **Agent Notebook**: Added manual steps for publishing agent serving endpoint
- **Implemented Feedback**: Applied suggestions and requests from an esteemed colleague

### Fixed

- **Windows Permission Errors**: Resolved Docker volume mount issues via WSL filesystem documentation

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
