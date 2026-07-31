# Credo configuration for the Localize input libraries.
#
# Mirrors the Localize policy: strict, with `Design.AliasUsage` disabled.
# Component and validator code fully qualifies many calls because module
# names such as `Localize.Inputs.ValidationError` and `Localize.Number`
# read more clearly at the call site than an alias, and because trailing
# segments such as `Number`, `Format` and `List` shadow other modules
# when aliased. Alias Localize submodules opportunistically where the
# trailing segment does not clash, never as a bulk conversion.
%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "test/"]
      },
      checks: %{
        disabled: [
          {Credo.Check.Design.AliasUsage, []}
        ]
      }
    }
  ]
}
