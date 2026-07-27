[
  import_deps: [:assert_eventually],
  inputs: ["*.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Styler],
  styler: [minimum_supported_elixir_version: "1.18.0"]
]
