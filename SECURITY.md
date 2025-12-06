# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability within SystemMonitor Pro, please follow these steps:

### Do NOT

- Do not open a public GitHub issue for security vulnerabilities
- Do not disclose the vulnerability publicly before it's fixed

### Do

1. **Email us directly** at: **xsuliman@gmail.com**
2. Include the following information:
   - Type of vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes (optional)

### What to Expect

- **Response Time**: We will acknowledge your report within 48 hours
- **Updates**: We will keep you informed about the progress
- **Fix Timeline**: Critical vulnerabilities will be addressed within 7 days
- **Credit**: With your permission, we will credit you in the release notes

## Security Best Practices

SystemMonitor Pro follows these security principles:

1. **No Network Access**: The app works entirely offline - no data is sent anywhere
2. **No Data Collection**: We don't collect any user data or analytics
3. **Trash-Based Deletion**: Files are moved to Trash, not permanently deleted
4. **System Protection**: System apps and files are protected from modification
5. **Open Source**: All code is publicly auditable

## Third-Party Dependencies

SystemMonitor Pro uses only Apple's native frameworks:
- SwiftUI
- AppKit
- Combine
- IOKit
- Darwin

No third-party libraries are used, minimizing supply chain risks.
