///|
/// Re-export the render row/cell iterator from its leaf package. The types'
/// definitions now live in `terminal/render_row_iterator`, but they remain a
/// documented part of the public host render API (`RenderState::row_iterator`
/// hands them out). This `pub using` keeps existing host code that names
/// `@terminal.RenderRowIterator` / `@terminal.RenderRowCells` compiling
/// unchanged, and lets this package's own files refer to them without the
/// `@render_row_iterator.` prefix.
pub using @render_row_iterator {type RenderRowIterator, type RenderRowCells}
