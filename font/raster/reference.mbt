///|
/// Brute-force ground-truth renderer (the oracle).
///
/// Each pixel is point-sampled at `samples * samples` sub-positions; coverage is
/// the fraction of sub-samples inside the path. Slow, but unambiguously correct:
/// it converges to the true area coverage as `samples` grows, and it shares no
/// code path with `render`, so agreement between the two is a real signal.
pub fn render_supersampled(
  path : Path,
  width : Int,
  height : Int,
  rule : FillRule,
  samples? : Int = 12,
) -> Coverage {
  let cov = Coverage::new(width, height)
  let inv = 1.0 / samples.to_double()
  let weight = 1.0 / (samples * samples).to_double()
  for py in 0..<height {
    for px in 0..<width {
      let mut inside = 0
      for sy in 0..<samples {
        let y = py.to_double() + (sy.to_double() + 0.5) * inv
        for sx in 0..<samples {
          let x = px.to_double() + (sx.to_double() + 0.5) * inv
          if path.point_inside(x, y, rule) {
            inside += 1
          }
        }
      }
      cov.data[py * width + px] = inside.to_double() * weight
    }
  }
  cov
}
