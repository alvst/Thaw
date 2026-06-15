# Security Policy

Thank you for helping keep Thaw secure. We take the security of our users and their data seriously. 

## Supported Versions

Since Thaw is a macOS menu bar manager, we primarily support security updates for the latest stable release. Please ensure you are running the most recent version of Thaw before submitting a vulnerability report.

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| Older   | :x:                |

## Scope of Security Reports

As a macOS application, Thaw may interact with local system APIs and require certain permissions (like Accessibility or Screen Recording, depending on features). 

**We consider the following in-scope for security reports:**
- Privilege escalation (e.g., escaping the app sandbox if applicable, or unauthorized root access).
- Unauthorized access to local user data managed by the app.
- Execution of arbitrary code via malicious input or crafted configuration files.

**The following are generally out of scope:**
- Bugs that crash the application without a viable exploit path (e.g., standard Null Pointer Dereferences).
- Issues requiring physical access to the user's unlocked Mac.
- Issues related to third-party macOS libraries, unless there is a specific mitigation Thaw needs to implement.

## Reporting a Vulnerability

Please **do not** report security vulnerabilities through public GitHub issues. 

Instead, please report them using [GitHub's Private Vulnerability Reporting](https://github.com/stonerl/Thaw/security/advisories/new) if it is enabled for this repository. 

If private vulnerability reporting is not enabled, please reach out privately by contacting the maintainer directly or checking the maintainer's GitHub profile for a public email address. 

Please include the following in your report:
- A detailed description of the vulnerability.
- Steps to reproduce the issue.
- Your macOS version and the version of Thaw you are testing against.
- Any potential impact on the user.

We will try to acknowledge your report within 48 hours and provide an estimated timeline for a fix. We ask that you keep the vulnerability confidential until we have released an update that mitigates the issue.
