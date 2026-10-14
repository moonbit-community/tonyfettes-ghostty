///|
const BuildSimd : Bool = false

///|
const BuildKittyGraphics : Bool = true

///|
const BuildTmuxControlMode : Bool = false

///|
const BuildVersionMajor : UInt32 = 0U

///|
const BuildVersionMinor : UInt32 = 1U

///|
const BuildVersionPatch : UInt32 = 0U

///|
let current_build_version_pre : String? = None

///|
let current_build_version_build : String? = None

///|
pub(all) enum OptimizeMode {
  Debug
  ReleaseSafe
  ReleaseSmall
  ReleaseFast
} derive(Eq, Debug)

///|
struct BuildVersion {
  major : UInt32
  minor : UInt32
  patch : UInt32
  pre : String?
  build : String?
} derive(Eq, Debug)

///|
pub fn BuildVersion::major(self : BuildVersion) -> UInt32 {
  self.major
}

///|
pub fn BuildVersion::minor(self : BuildVersion) -> UInt32 {
  self.minor
}

///|
pub fn BuildVersion::patch(self : BuildVersion) -> UInt32 {
  self.patch
}

///|
pub fn BuildVersion::pre(self : BuildVersion) -> String? {
  self.pre
}

///|
pub fn BuildVersion::build(self : BuildVersion) -> String? {
  self.build
}

///|
pub fn BuildVersion::string(self : BuildVersion) -> String {
  let mut version = self.major.to_string() +
    "." +
    self.minor.to_string() +
    "." +
    self.patch.to_string()
  match self.pre {
    Some(pre) => version = version + "-" + pre
    None => ()
  }
  match self.build {
    Some(build) => version = version + "+" + build
    None => ()
  }
  version
}

///|
struct BuildInfo {
  simd : Bool
  kitty_graphics : Bool
  tmux_control_mode : Bool
  optimize : OptimizeMode
  version : BuildVersion
} derive(Eq, Debug)

///|
pub fn BuildInfo::simd(self : BuildInfo) -> Bool {
  self.simd
}

///|
pub fn BuildInfo::kitty_graphics(self : BuildInfo) -> Bool {
  self.kitty_graphics
}

///|
pub fn BuildInfo::tmux_control_mode(self : BuildInfo) -> Bool {
  self.tmux_control_mode
}

///|
pub fn BuildInfo::optimize(self : BuildInfo) -> OptimizeMode {
  self.optimize
}

///|
pub fn BuildInfo::version(self : BuildInfo) -> BuildVersion {
  self.version
}

///|
pub fn BuildInfo::version_string(self : BuildInfo) -> String {
  self.version.string()
}

///|
pub fn build_info() -> BuildInfo {
  {
    simd: BuildSimd,
    kitty_graphics: BuildKittyGraphics,
    tmux_control_mode: BuildTmuxControlMode,
    optimize: current_optimize_mode(),
    version: current_build_version(),
  }
}

///|
fn current_build_version() -> BuildVersion {
  {
    major: BuildVersionMajor,
    minor: BuildVersionMinor,
    patch: BuildVersionPatch,
    pre: current_build_version_pre,
    build: current_build_version_build,
  }
}

///|
pub extend OptimizeMode with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend OptimizeMode with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend OptimizeMode with @debug.Debug::{to_repr}

///|
pub extend BuildVersion with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend BuildVersion with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend BuildVersion with @debug.Debug::{to_repr}

///|
pub extend BuildInfo with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend BuildInfo with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend BuildInfo with @debug.Debug::{to_repr}
