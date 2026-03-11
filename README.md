# mcp-redhat-manpage-data

Pre-extracted RHEL man pages for [mcp-redhat-manpage](https://github.com/shonstephens/mcp-redhat-manpage). Contains rendered plain-text man pages from RHEL 8, 9, and 10 UBI container images.

This package is a data dependency — install [mcp-redhat-manpage](https://github.com/shonstephens/mcp-redhat-manpage) to use it.

## Contents

Man pages are extracted from the following packages and stored as plain text:

| Category | Packages |
|------|-------------|
| SSSD / Identity | sssd-common, sssd-ad, sssd-ldap, sssd-krb5, sssd-tools, sssd-client |
| Kerberos | krb5-workstation, krb5-libs |
| AD Integration | adcli, realmd |
| Auth Stack | authselect |
| Crypto | crypto-policies, crypto-policies-scripts |
| System Services | chrony, systemd |
| Network | NetworkManager, bind-utils |
| Core | man-db, man-pages, coreutils, shadow-utils |
| PAM | pam |

## How it's built

A [GitHub Actions workflow](.github/workflows/extract.yml) pulls UBI container images, installs the target packages, renders all man pages to plain text, and publishes updated content to npm. The workflow runs monthly or on manual trigger.

Source images:

| Version | Image |
|------|-------------|
| RHEL 8 | `registry.access.redhat.com/ubi8/ubi:latest` |
| RHEL 9 | `registry.access.redhat.com/ubi9/ubi:latest` |
| RHEL 10 | `registry.access.redhat.com/ubi10/ubi:latest` |

## Related MCP Servers

- [mcp-redhat-manpage](https://github.com/shonstephens/mcp-redhat-manpage) - MCP server that serves this data
- [mcp-redhat-knowledge](https://github.com/shonstephens/mcp-redhat-knowledge) - Knowledge Base search
- [mcp-redhat-support](https://github.com/shonstephens/mcp-redhat-support) - Support case management
- [mcp-redhat-account](https://github.com/shonstephens/mcp-redhat-account) - Account management
- [mcp-redhat-subscription](https://github.com/shonstephens/mcp-redhat-subscription) - Subscription management

## License

MIT
