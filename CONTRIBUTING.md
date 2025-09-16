# Contributing to Workshop: Streamlining Agentic AI with Confluent and Databricks

Thank you for your interest in contributing to this educational workshop! This project helps data engineers learn real-time AI-powered marketing pipelines using Confluent Cloud and Databricks. We welcome contributions that improve the learning experience for workshop participants.

## 🎯 Project Mission

This workshop demonstrates how to build a complete **real-time AI-powered marketing pipeline** for the hospitality industry. Our goal is to provide hands-on experience with cutting-edge streaming technologies in a practical, industry-relevant scenario.

## 🤝 Types of Contributions Welcome

We encourage the following types of contributions:

### 📚 **Documentation & Content**

- Fix typos, grammar, or unclear instructions
- Improve code comments and explanations
- Add troubleshooting guides and FAQ sections
- Enhance existing lab instructions with better clarity
- Translate content (contact maintainers first)

### 🐛 **Bug Fixes**

- Fix issues with Terraform infrastructure deployment
- Resolve data generation or processing problems
- Correct broken links or missing images
- Fix compatibility issues with updated cloud services

### ✨ **Feature Enhancements**

- Add support for new cloud regions or providers
- Improve error handling and user experience
- Add new optional lab exercises or advanced scenarios
- Enhance monitoring and observability features

### 🧪 **Testing & Validation**

- Test workshop instructions in different environments
- Add validation scripts for workshop prerequisites
- Improve end-to-end testing coverage
- Document test procedures and validation steps

### 🔧 **Infrastructure Improvements**

- Optimize cloud resource costs
- Improve deployment reliability
- Add automation for common maintenance tasks
- Enhance security configurations

## 🚀 Getting Started

### Prerequisites for Contributors

Before contributing, ensure you have:

1. **Development Environment**:
   - Git
   - Terraform >= 1.0
   - AWS CLI configured
   - Text editor or IDE
   - Python 3.8+ (for testing scripts)

2. **Cloud Accounts** (for testing):
   - AWS account with admin permissions
   - Confluent Cloud account
   - Databricks account (optional, for full testing)

3. **Knowledge Requirements**:

   - Basic understanding of cloud platforms
   - Familiarity with Infrastructure as Code (Terraform)
   - SQL and basic streaming concepts
   - Markdown for documentation

### Setting Up Development Environment

1. **Clone**:

   ```sh
   git clone https://github.com/[your-username]/workshop-tableflow-databricks
   cd workshop-tableflow-databricks
   ```

2. **Create a Feature Branch**:

   ```sh
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

3. **Test Your Changes**:
   - For infrastructure changes: Test Terraform deployment in an isolated environment
   - For documentation: Verify all links and instructions work
   - For content: Ensure technical accuracy and clarity

## 📝 Contribution Guidelines

### Code Style and Standards

#### **Terraform**

- Use consistent indentation (2 spaces)
- Include comments for complex resource configurations
- Follow [Terraform best practices](https://learn.hashicorp.com/tutorials/terraform/best-practices)
- Use meaningful resource names with consistent naming conventions
- Include appropriate tags for cloud resources

```hcl
# Good example
resource "aws_instance" "oracle_instance" {
  ami           = data.aws_ami.oracle_linux.id
  instance_type = var.oracle_instance_type

  tags = {
    Name        = "${local.resource_prefix}-oracle-instance"
    Environment = var.environment
    Workshop    = "tableflow-databricks"
  }

  # Configure Oracle XE for workshop
  user_data = templatefile("${path.module}/scripts/oracle-setup.sh", {
    admin_password = var.oracle_admin_password
  })
}
```

#### **Documentation**

- Use clear, concise language appropriate for intermediate-level learners
- Include step-by-step instructions with expected outcomes
- Add screenshots for complex UI interactions (update `images/`)
- Use consistent Markdown formatting
- Include code blocks with proper syntax highlighting

#### **SQL Queries**

- Use consistent indentation and formatting
- Include comments explaining complex logic
- Use meaningful aliases and table names
- Follow SQL best practices for readability

```sql
-- Create denormalized booking data with interval joins
SET 'client.statement-name' = 'denormalized-hotel-bookings';

CREATE TABLE DENORMALIZED_HOTEL_BOOKINGS AS (
  SELECT
    h.`NAME` AS `HOTEL_NAME`,
    h.`DESCRIPTION` AS `HOTEL_DESCRIPTION`,
    h.`CLASS` AS `HOTEL_CLASS`,
    -- Convert epoch timestamps to readable format
    to_timestamp_ltz(b.`CREATED_AT`, 3) AS `BOOKING_DATE`,
    b.`BOOKING_ID`
  FROM `bookings` b
    -- Interval join with snapshot table for CDC compatibility
    JOIN `CUSTOMER_SNAPSHOT` c
      ON c.`EMAIL` = b.`CUSTOMER_EMAIL`
      AND c.`$rowtime` BETWEEN b.`$rowtime` - INTERVAL '7' DAY AND b.`$rowtime` + INTERVAL '7' DAY
);
```

### Testing Requirements

#### **Infrastructure Testing**

1. **Pre-deployment validation**:

   ```bash
   terraform fmt -check
   terraform validate
   terraform plan
   ```

2. **Deployment testing**:
   - Test in a clean AWS account/region
   - Verify all resources deploy successfully
   - Validate connectivity between components
   - Test teardown process (`terraform destroy`)

3. **Workshop flow testing**:
   - Follow lab instructions step-by-step
   - Verify expected outputs and results
   - Test troubleshooting scenarios

#### **Documentation Testing**

- Verify all links work correctly
- Test code samples and SQL queries
- Ensure screenshots are current and accurate
- Validate prerequisites and setup instructions

### Commit Message Guidelines

Use conventional commit format for clear change history:

```text
type(scope): brief description

Detailed explanation if needed

Fixes #issue-number
```

**Types:**

- `feat`: New feature or enhancement
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code formatting (no functional changes)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```text
feat(terraform): add support for us-west-1 region

Add AMI data sources and configuration for us-west-1 to expand
workshop availability to more AWS regions.

Fixes #42

---

docs(lab2): clarify temporal join configuration steps

Add more detailed explanation of cleanup.policy requirements
and include troubleshooting section for common errors.

Fixes #38

---

fix(oracle): resolve XStream connector primary key issues

Pre-create Oracle tables with explicit primary key constraints
to ensure CDC properly captures key metadata for Flink temporal joins.

Fixes #45
```

## 🔄 Pull Request Process

### Before Submitting

1. **Self-review your changes**:
   - Test all modified functionality
   - Verify documentation accuracy
   - Check for typos and formatting issues
   - Ensure compliance with style guidelines

2. **Update relevant documentation**:
   - Update CHANGELOG.md for significant changes
   - Modify README.md if prerequisites or setup change
   - Update troubleshooting guides for new known issues

3. **Test in isolation**:
   - Deploy infrastructure changes in a clean environment
   - Verify workshop flows work end-to-end
   - Test with fresh cloud accounts when possible

### Pull Request Template

Use this template for your PR description:

```markdown
## Description
Brief summary of changes and their purpose.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Infrastructure improvement

## Testing Performed
- [ ] Terraform deployment tested
- [ ] Workshop instructions validated
- [ ] Documentation links verified
- [ ] SQL queries tested in Flink

## Screenshots (if applicable)
Include before/after screenshots for UI changes.

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my changes
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings or errors
- [ ] I have tested my changes in a clean environment

## Related Issues
Fixes #(issue number)
```

### Review Process

1. **Automated checks**: All PRs must pass automated formatting and validation checks
2. **Peer review**: At least one maintainer review required
3. **Testing validation**: Changes must be tested in representative environments
4. **Documentation review**: Technical accuracy and clarity assessment

### Merge Criteria

PRs will be merged when they meet these criteria:

- ✅ All automated checks pass
- ✅ Approved by at least one maintainer
- ✅ No outstanding change requests
- ✅ Documentation is current and accurate
- ✅ Changes tested in appropriate environment

## 🐛 Reporting Issues

### Before Creating an Issue

1. **Check existing issues**: Search for similar problems or requests
2. **Review troubleshooting docs**: Check `assets/labs/troubleshooting.md`
3. **Test in clean environment**: Verify issue isn't environment-specific

### Issue Template

**Bug Report:**

```markdown
## Bug Description
Clear description of what went wrong.

## Environment
- Cloud provider and region:
- Terraform version:
- Operating system:
- Browser (if applicable):

## Steps to Reproduce
1. Go to...
2. Click on...
3. Run command...
4. See error

## Expected Behavior
What should have happened.

## Actual Behavior
What actually happened.

## Error Messages

```text
Paste relevant error messages or logs here
```

## Additional Context

Any other relevant information.

**Feature Request:**

```markdown
## Feature Description
Clear description of the proposed feature.

## Use Case
Why would this feature be valuable?

## Proposed Solution
How should this feature work?

## Alternative Solutions
Other approaches you've considered.

## Additional Context
Any other relevant information.
```

## 📋 Project Structure

Understanding the project layout helps ensure contributions fit appropriately:

```text
workshop-tableflow-databricks/
├── assets/
│   ├── images/          # Screenshots and diagrams
│   └── labs/            # Lab instruction files
├── data/
│   ├── generators/      # ShadowTraffic data generators
│   ├── schemas/         # Avro schemas
│   └── connections/     # Database connection configs
├── terraform/           # Infrastructure as Code
├── tests/              # Validation and testing scripts
├── CHANGELOG.md        # Version history
├── CONTRIBUTING.md     # This file
├── LICENSE            # Apache 2.0 license
└── README.md          # Main project documentation
```

### Where to Make Changes

- **Lab instructions**: `assets/labs/*.md`
- **Infrastructure**: `terraform/*.tf`
- **Data generation**: `data/generators/*.json`
- **Documentation**: `*.md` files and `assets/images/`
- **Testing**: `tests/` directory

## 🏷️ Release Process

This project follows semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes to workshop structure or prerequisites
- **MINOR**: New features, labs, or significant enhancements
- **PATCH**: Bug fixes, documentation updates, minor improvements

Releases are tagged and documented in CHANGELOG.md.

## 📜 Code of Conduct

### Our Standards

We are committed to providing a welcoming and inclusive environment for all contributors:

- **Be respectful**: Treat all participants with respect and courtesy
- **Be constructive**: Provide helpful feedback and suggestions
- **Be collaborative**: Work together toward shared learning goals
- **Be patient**: Remember that everyone has different experience levels

### Unacceptable Behavior

- Harassment, discrimination, or hostile behavior
- Personal attacks or inflammatory language
- Spam, trolling, or off-topic discussions
- Sharing private information without permission

### Enforcement

Report any unacceptable behavior to the project maintainers. All reports will be handled confidentially and appropriately.

## 💬 Community and Support

### Getting Help

- **Documentation**: Check README.md and troubleshooting guides first
- **Issues**: Create detailed issue reports for bugs or problems
- **Discussions**: Use GitHub Discussions for questions and ideas

### Maintainer Response Time

- **Issues**: We aim to respond within 2-3 business days
- **Pull Requests**: Initial review within 3-4 business days
- **Security Issues**: Prioritized for immediate response

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## 🙏 Recognition

Contributors may be recognized in:

- GitHub contributors list
- CHANGELOG.md for significant contributions
- Special recognition for major improvements

---

**Questions?** Feel free to create an issue or start a discussion. We appreciate your interest in improving this educational workshop! 🚀
