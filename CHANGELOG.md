# ExAcme Changelog

## Unreleased

- Added `fetch_certificate_chains/3`, which returns the default certificate chain together with the alternate chains the server advertises via `Link: rel="alternate"` headers (RFC 8555 §7.4.2).
- Added a `:preferred_chain` option to `fetch_certificates/4` that selects the chain whose topmost certificate is issued by the given root, falling back to the default chain.
- Added `ExAcme.Request.link_urls/3` for extracting `Link` header targets by relation type.

## 0.8.0 (2026-07-26)

- Updated Req to 0.6.3 or later to address response decompression and multipart header injection vulnerabilities.
- Raised the minimum Elixir requirement to 1.18 and dropped Elixir and OTP versions that are no longer supported upstream.
- Updated development and test dependencies.

## 0.7.0 (2025-12-20)

### Breaking Changes

- `finalize_order/4` now accepts an `Order` struct instead of a finalize URL string (#12).
- `start_challenge_validation/3` now accepts a `Challenge` struct instead of a URL string (#12).

This aligns with idiomatic Elixir patterns and fixes an issue where `order.url` could be nil when the Location header was missing.

## 0.6.1 (2025-12-20)

- Fixed Pebble ACME server compatibility (#11).
- Fixed EC key generation for OTP 28.

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
