# ExAcme Changelog

## 0.5.0 (2025-03-03)

- Switch to using `Req` instead of `Finch` directly. This change improves the reliability of the library by picking up automatic retries and cleans up request encoding and response parsing.
- Fix a number of bugs and improve error handling.

## 0.4.1 (2025-03-02)

- Fix mistake with config values

## 0.4.0 (2025-03-02)

- Added support for handling external account binding (https://datatracker.ietf.org/doc/html/rfc8555#section-7.3.4)
- Added ZeroSSL as a named directory URL.

## 0.3.0 (2025-03-01)

- Substantial API refactoring to reduce duplication and improve maintainability.
- Support for account key rotation (https://datatracker.ietf.org/doc/html/rfc8555#section-7.3.5)
- Support for account deactivation (https://datatracker.ietf.org/doc/html/rfc8555#section-7.3.6)
- Support for certificate revocation (https://datatracker.ietf.org/doc/html/rfc8555#section-7.6)

## 0.2.0 (2025-02-25)

- Removed restrictions on keys for `ExAcme.start_link/1` to allow process to be named during supervision.

## 0.1.0 (2025-02-25)

- Initial release of ExAcme.
