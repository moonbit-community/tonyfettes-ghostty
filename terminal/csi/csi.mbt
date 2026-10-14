///|
pub(all) enum SizeReportStyle {
  Csi14t
  Csi16t
  Csi18t
  Csi21t
} derive(Eq, Debug)

///|
pub extend SizeReportStyle with Eq::{not_equal, equal}

///|
pub extend SizeReportStyle with @debug.Debug::{to_repr}
