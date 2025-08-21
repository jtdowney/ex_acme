# ExAcme Changelog

## 0.6.0 (2025-08-21)

- Added support for Retry-After headers in ACME responses to improve server interaction reliability.
- Enhanced nonce management concurrency to prevent blocking and races in high-traffic scenarios.
- Added OTP 28 support and worked around jose-erlang compatibility issues.
- Added validation for empty identifiers in OrderBuilder and Order.to_csr/2 to prevent invalid requests.
- Fixed atom exhaustion vulnerability in to_camel_case function and improved key mixing.
- Improved error handling and type specifications across various modules.
- Updated documentation with examples for handling retry_after responses.

## 0.5.2 (2025-03-06)

- Added sugar to `ExAcme.OrderBuilder.add_dns_identifier/2`, `ExAcme.RegistrationBuilder.contacts/2`, and improved `ExAcme.RevocationBuilder.certificate/2`.

## 0.5.1 (2025-03-06)

- Fixed a dialyzer warning about the return from `ExAcme.fetch_certificates/3`.

## 0.5.0 (2025-03-03)

- Switched to using `Req` instead of `Finch` directly. This change improves the reliability of the library by picking up automatic retries and cleans up request encoding and response parsing.
- Fixed a number of bugs and improved error handling.

## 0.4.1 (2025-03-02)

- Fixed a mistake with config values

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
