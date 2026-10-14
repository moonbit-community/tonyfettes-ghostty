///|
pub(all) enum SizeReportStyle {
  Csi14t
  Csi16t
  Csi18t
  Csi21t
} derive(Eq, Debug)

///|
pub extend SizeReportStyle with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SizeReportStyle with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SizeReportStyle with @debug.Debug::{to_repr}
