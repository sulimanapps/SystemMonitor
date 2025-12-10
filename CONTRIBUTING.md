# Contributing to SystemMonitor Pro

Thank you for your interest in contributing to SystemMonitor Pro! This document provides guidelines for contributing to the project.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/yourusername/SystemMonitor.git
   cd SystemMonitor
   ```
3. **Create a branch** for your feature or fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9

### Building
```bash
# Open in Xcode
open SystemMonitor.xcodeproj

# Or build from command line
xcodebuild -scheme SystemMonitor -configuration Debug build
```

## Code Style Guidelines

### Swift Style
- Use Swift's standard naming conventions (camelCase for variables/functions, PascalCase for types)
- Keep functions focused and small
- Use meaningful variable and function names
- Add comments for complex logic

### SwiftUI Best Practices
- Extract reusable views into separate files
- Use `@State` for local view state
- Use `@ObservedObject` for shared state
- Keep views focused on presentation

### File Organization
```
SystemMonitor/
├── App/              # App entry and controllers
├── Views/            # SwiftUI views
├── Models/           # Data models
├── Managers/         # Business logic
├── Theme/            # UI theming
└── Utilities/        # Helper functions
```

## Submitting Changes

### Pull Request Process

1. **Update documentation** if you're changing functionality
2. **Test your changes** thoroughly on macOS
3. **Ensure the build succeeds** without warnings
4. **Write a clear PR description** explaining:
   - What changes you made
   - Why you made them
   - How to test them

### Commit Messages

Use clear, descriptive commit messages:
```
feat: Add network speed monitoring
fix: Resolve memory leak in chart view
docs: Update installation instructions
refactor: Simplify cache manager logic
```

### PR Title Format
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `style:` Formatting changes
- `test:` Adding tests

## Reporting Issues

### Bug Reports
Include:
- macOS version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots if applicable

### Feature Requests
Include:
- Clear description of the feature
- Use case / why it's needed
- Any implementation suggestions

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## Questions?

Feel free to open an issue for any questions about contributing.

---

Thank you for contributing to SystemMonitor Pro!
