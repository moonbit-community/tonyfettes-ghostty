name = "tonyfettes/ghostty"

version = "0.3.0"

readme = "README.md"

repository = "https://github.com/moonbit-community/tonyfettes-ghostty"

license = "Apache-2.0"

keywords = [ ]

description = ""

import {
  "moonbit-community/harfbuzz@0.1.0",
}

warnings = "+unnecessary_annotation+unnecessary_view_op+prefer_readonly_array+prefer_fixed_array+ambiguous_range_direction+deprecated_for_in_method+unqualified_local_using+lexmatch_longest_match"

options(
  exclude: [ "upstream" ],
)
