# ExAcme Changelog

## Unreleased

- Substantial API refactoring to reduce duplication and improve maintainability.
- Support for account key rotation (https://datatracker.ietf.org/doc/html/rfc8555#section-7.3.5)
- Support for account deactivation (https://datatracker.ietf.org/doc/html/rfc8555#section-7.3.6)
- Support for certificate revocation (https://datatracker.ietf.org/doc/html/rfc8555#section-7.6)

## 0.2.0 (2025-02-25)

- Removed restrictions on keys for `ExAcme.start_link/1` to allow process to be named during supervision.

## 0.1.0 (2025-02-25)

- Initial release of ExAcme.
