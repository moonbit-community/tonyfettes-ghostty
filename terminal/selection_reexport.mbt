///|
/// Re-export `Selection` from its leaf package. The type's definition now lives
/// in `terminal/selection`, but it remains a documented part of the public host
/// API (`StreamTerminal::selection` / `untrack_selection`, `FormatterOptions`,
/// `KittyPlacement::rect`). This `pub using` keeps existing host code that names
/// or constructs `@terminal.Selection` compiling unchanged, so the extraction
/// stays a non-breaking refactor, and lets this package's own files refer to
/// `Selection` without the `@selection.` prefix.
pub using @selection {type Selection}
