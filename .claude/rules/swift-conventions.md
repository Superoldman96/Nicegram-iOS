---
paths:
  - "Nicegram/**/*.swift"
  - "submodules/**/Nicegram/**/*.swift"
---

# Swift conventions (Nicegram code)

Applies to **our** Swift code — the `Nicegram/**` modules and new Nicegram files
inside Telegram submodules (and, where reasonable, new Nicegram marker blocks
added to upstream files). Do NOT restyle surrounding upstream Telegram code.

## Style

- Pick the narrowest access modifier that works, widening only as needed:
  `private -> internal -> package -> public`.
- Mark all classes `final`, no exceptions.
- Don't hand-write boilerplate initializers — use the synthesized memberwise init
  (or `@MemberwiseInit` / `@Init` where the macros are available).
- Keep function bodies readable top to bottom: extract steps into small private
  helpers.
- Define a type's stored properties + init in the type; put functions in an
  `extension` with the appropriate access modifier.
- Don't add protocols by default — only for real abstractions or genuine
  polymorphism.

## Formatting

- More than one parameter → one per line, in both the declaration and the call
  site. Same for passing more than one closure (labeled, one per line — not a
  trailing closure).
- A single closure argument: trailing closure when its purpose is obvious,
  otherwise a labeled argument on its own line.
- Keep declarations alphabetical: `import` statements, build-target dependency
  lists, and a type's stored properties.

```swift
// more than one parameter -> one per line
func update(
    isEnabled: Bool,
    subtitle: String,
    title: String
) { ... }

// multiple closures -> labeled, one per line (no trailing closure)
initialize(
    onFailure: { error in handle(error) },
    onSuccess: { proceed() }
)
```

## Polymorphism

- "Value is one of N types" → an `enum` with associated values.
- Variants with different behavior → a protocol, one implementation per variant,
  plus a sealed `enum` (an id/kind) with a `toX()` conversion so callers switch
  safely.

## Errors & optionals

In code that can import the assistant's `NGCore` (e.g. `NGUtils`, bridge
implementations), reuse its shared error types instead of inventing new ones, and
unwrap optionals with the helper rather than force-unwrapping:

- `UnexpectedError` — generic fallback.
- `NotAuhorizedError` — auth/permission failures (the spelling is intentional).
- `MessageError(message:)` — user-facing message (`LocalizedError`).

```swift
let user = try getCurrentUser().unwrap(orThrow: NotAuhorizedError())
```
