import Config

config :ex_acme,
  named_directory_urls: %{
    lets_encrypt: "https://acme-v02.api.letsencrypt.org/directory",
    lets_encrypt_staging: "https://acme-staging-v02.api.letsencrypt.org/directory",
    zerossl: "https://acme.zerossl.com/v2/DV90"
  },
  reason_codes: %{
    unspecified: 0,
    key_compromise: 1,
    affiliation_changed: 3,
    superseded: 4,
    cessation_of_operation: 5
  }

config :mix_test_watch,
  clear: true,
  tasks: [
    "test",
    "credo"
  ]
