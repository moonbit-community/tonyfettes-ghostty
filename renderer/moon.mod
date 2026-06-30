name = "tonyfettes/ghostty-renderer"

version = "0.1.0"

license = "Apache-2.0"

repository = "https://github.com/moonbit-community/tonyfettes-ghostty"

keywords = [ ]

description = "CPU-side cell renderer: terminal RenderState -> GPU instance data."

import {
  "tonyfettes/ghostty-terminal@0.3.0",
  "tonyfettes/ghostty-font@0.1.0",
}

warnings = "+unnecessary_annotation+unnecessary_view_op+prefer_readonly_array+prefer_fixed_array+ambiguous_range_direction+deprecated_for_in_method+unqualified_local_using+lexmatch_longest_match"
