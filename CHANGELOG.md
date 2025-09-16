# Change Log

## v0.3.0 - 2025-09-16

### New Features

- **Unity Catalog**: Added steps for configuring a streamlined integration Tableflow with Databricks via Unity Catalog
- **Tableflow Upsert Support**: Shifted `hotel_stats` left into Confluent Cloud Flink now that *upsert* changelog format is supported by Tableflow

### Workshop Standardization and User Experience

- **Lab Consistency**: Standardized all labs with unified intro/outro formats, mermaid workflow diagrams, and navigation links
- **Documentation Quality**: Restructured `flink-joins.md` from troubleshooting guide to comprehensive discovery journey with experiment results and context-specific recommendations
- **Content Reorganization**: Split the labs into smaller, more feature-specific files
- **Visual Learning**: Added workflow diagrams to labs for to improve concept visualization

### Technical Improvements

- **Streaming Joins**: Migrated to snapshot tables + interval joins for reliable CDC processing with hybrid timestamp strategy
- **Oracle Infrastructure**: Pre-created tables with proper primary key constraints and enhanced Terraform configuration for XStream CDC
- **Data Generation**: Optimized data volumes (1,000 customers, 400 bookings) and fixed duplicate booking ID issues for better workshop performance
- **Troubleshooting**: Updated guides with proven working solutions and removed outdated advice that caused failures

## v0.2.0 - 2025-07-15

- Updated AI marketing agent documentation to reflect notebook functionality (hotel selection, review analysis, customer targeting)
- Removed Flink Native Inference for now
- Improved content clarity and streamlined language for better readability
- Standardized style, product naming conventions, and markdown formatting
- Fixed spelling errors and formatting inconsistencies across all markdown files

## v0.1.0 - 2025-06-12

- Initial release
