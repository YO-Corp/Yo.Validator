# Contributing to YOMLM Network Validator

Thank you for your interest in contributing to the YOMLM Network Validator project! This document provides guidelines for contributing to our codebase.

## 🚀 Getting Started

### Prerequisites
- Basic understanding of blockchain technology
- Knowledge of Docker and containerization
- Familiarity with shell scripting
- Understanding of EVMOS and Cosmos SDK (helpful but not required)

### Development Environment Setup
```bash
# Clone the repository
git clone https://github.com/YO-Corp/Yo.Validator.git
cd Yo.Validator

# Make scripts executable
chmod +x *.sh scripts/*.sh

# Test the setup
./check-status.sh
```

## 📋 How to Contribute

### 1. Fork the Repository
1. Fork the repository on GitHub
2. Clone your fork locally
3. Create a new branch for your feature/bugfix

### 2. Make Changes
1. Follow our coding standards (see below)
2. Write clear, concise commit messages
3. Add tests if applicable
4. Update documentation as needed

### 3. Submit a Pull Request
1. Push your changes to your fork
2. Create a pull request against the main branch
3. Provide a clear description of your changes
4. Wait for review and address feedback

## 🛠️ Coding Standards

### Shell Scripts
- Use `#!/bin/bash` shebang
- Include error handling with `set -e`
- Add comments for complex operations
- Use meaningful variable names
- Follow bash best practices

### Documentation
- Update README.md for new features
- Include inline comments in scripts
- Provide examples where applicable
- Keep documentation up to date

### Configuration Files
- Validate JSON/TOML syntax
- Include comments explaining parameters
- Follow existing formatting patterns
- Test configurations before submitting

## 🧪 Testing

### Testing Your Changes
```bash
# Test validator setup
./setup-validator.sh --test-mode

# Test validator operations
./start-validator.sh
./check-status.sh
./stop-validator.sh

# Test health monitoring
./scripts/health-check.sh
```

### CI/CD Pipeline
- All PRs must pass automated tests
- Code is automatically checked for syntax errors
- Security scans are performed on all changes

## 📝 Issue Reporting

### Bug Reports
When reporting bugs, please include:
- Operating system and version
- Docker version (if applicable)
- Steps to reproduce the issue
- Expected vs actual behavior
- Relevant log outputs
- Configuration details (without sensitive information)

### Feature Requests
For feature requests, please provide:
- Clear description of the proposed feature
- Use case and benefits
- Potential implementation approach
- Impact on existing functionality

## 🔐 Security

### Security Issues
- Report security vulnerabilities privately to security@yochain.club
- Do not create public issues for security vulnerabilities
- Allow time for the team to address the issue before disclosure

### Best Practices
- Never commit sensitive information (keys, passwords, etc.)
- Use environment variables for configuration
- Follow principle of least privilege
- Validate all inputs

## 📚 Resources

### Documentation
- [EVMOS Documentation](https://docs.evmos.org/)
- [Cosmos SDK Documentation](https://docs.cosmos.network/)
- [Docker Documentation](https://docs.docker.com/)

### Community
- [YOMLM Telegram](https://t.me/yochainofficial)
- [GitHub Discussions](https://github.com/YO-Corp/Yo.Validator/discussions)

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be acknowledged in:
- CONTRIBUTORS.md file
- Release notes for significant contributions
- Project documentation where applicable

Thank you for helping make the YOMLM Network Validator better! 🎉
