///|
priv enum SpriteDrawLineStyle {
  LineNone
  LineLight
  LineHeavy
  LineDouble
} derive(Eq)

///|
priv struct SpriteDrawLines {
  up : SpriteDrawLineStyle
  right : SpriteDrawLineStyle
  down : SpriteDrawLineStyle
  left : SpriteDrawLineStyle
}

///|
fn sprite_draw_lines(
  up? : SpriteDrawLineStyle = LineNone,
  right? : SpriteDrawLineStyle = LineNone,
  down? : SpriteDrawLineStyle = LineNone,
  left? : SpriteDrawLineStyle = LineNone,
) -> SpriteDrawLines {
  { up, right, down, left }
}

///|
fn draw2500_257f(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(width)
  ignore(height)

  match cp {
    0x2500 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineLight, right=LineLight),
      )
    0x2501 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineHeavy, right=LineHeavy),
      )
    0x2502 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, down=LineLight),
      )
    0x2503 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, down=LineHeavy),
      )
    0x2504 =>
      dash_horizontal(
        metrics,
        canvas,
        3U,
        ThicknessLight.height(metrics.box_thickness),
        @cmp.maximum(4U, ThicknessLight.height(metrics.box_thickness)),
      )
    0x2505 =>
      dash_horizontal(
        metrics,
        canvas,
        3U,
        ThicknessHeavy.height(metrics.box_thickness),
        @cmp.maximum(4U, ThicknessLight.height(metrics.box_thickness)),
      )
    0x2506 =>
      dash_vertical(
        metrics,
        canvas,
        3U,
        ThicknessLight.height(metrics.box_thickness),
        @cmp.maximum(4U, ThicknessLight.height(metrics.box_thickness)),
      )
    0x2507 =>
      dash_vertical(
        metrics,
        canvas,
        3U,
        ThicknessHeavy.height(metrics.box_thickness),
        @cmp.maximum(4U, ThicknessLight.height(metrics.box_thickness)),
      )
    0x2508 =>
      dash_horizontal(
        metrics,
        canvas,
        4U,
        ThicknessLight.height(metrics.box_thickness),
        @cmp.maximum(4U, ThicknessLight.height(metrics.box_thickness)),
      )
    0x2509 =>
      dash_horizontal(
        metrics,
        canvas,
        4U,
        ThicknessHeavy.height(metrics.box_thickness),
        @cmp.maximum(4U, ThicknessLight.height(metrics.box_thickness)),
      )
    0x250A =>
      dash_vertical(
        metrics,
        canvas,
        4U,
        ThicknessLight.height(metrics.box_thickness),
        @cmp.maximum(4U, ThicknessLight.height(metrics.box_thickness)),
      )
    0x250B =>
      dash_vertical(
        metrics,
        canvas,
        4U,
        ThicknessHeavy.height(metrics.box_thickness),
        @cmp.maximum(4U, ThicknessLight.height(metrics.box_thickness)),
      )
    0x250C =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, right=LineLight),
      )
    0x250D =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, right=LineHeavy),
      )
    0x250E =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineHeavy, right=LineLight),
      )
    0x250F =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineHeavy, right=LineHeavy),
      )
    0x2510 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, left=LineLight),
      )
    0x2511 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, left=LineHeavy),
      )
    0x2512 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineHeavy, left=LineLight),
      )
    0x2513 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineHeavy, left=LineHeavy),
      )
    0x2514 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, right=LineLight),
      )
    0x2515 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, right=LineHeavy),
      )
    0x2516 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, right=LineLight),
      )
    0x2517 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, right=LineHeavy),
      )
    0x2518 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, left=LineLight),
      )
    0x2519 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, left=LineHeavy),
      )
    0x251A =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, left=LineLight),
      )
    0x251B =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, left=LineHeavy),
      )
    0x251C =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, down=LineLight, right=LineLight),
      )
    0x251D =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, down=LineLight, right=LineHeavy),
      )
    0x251E =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, right=LineLight, down=LineLight),
      )
    0x251F =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineHeavy, right=LineLight, up=LineLight),
      )
    0x2520 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, down=LineHeavy, right=LineLight),
      )
    0x2521 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, right=LineHeavy, up=LineHeavy),
      )
    0x2522 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, right=LineHeavy, down=LineHeavy),
      )
    0x2523 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, down=LineHeavy, right=LineHeavy),
      )
    0x2524 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, down=LineLight, left=LineLight),
      )
    0x2525 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, down=LineLight, left=LineHeavy),
      )
    0x2526 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, left=LineLight, down=LineLight),
      )
    0x2527 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineHeavy, left=LineLight, up=LineLight),
      )
    0x2528 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, down=LineHeavy, left=LineLight),
      )
    0x2529 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, left=LineHeavy, up=LineHeavy),
      )
    0x252A =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, left=LineHeavy, down=LineHeavy),
      )
    0x252B =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, down=LineHeavy, left=LineHeavy),
      )
    0x252C =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, left=LineLight, right=LineLight),
      )
    0x252D =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineHeavy, right=LineLight, down=LineLight),
      )
    0x252E =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(right=LineHeavy, left=LineLight, down=LineLight),
      )
    0x252F =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, left=LineHeavy, right=LineHeavy),
      )
    0x2530 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineHeavy, left=LineLight, right=LineLight),
      )
    0x2531 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(right=LineLight, left=LineHeavy, down=LineHeavy),
      )
    0x2532 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineLight, right=LineHeavy, down=LineHeavy),
      )
    0x2533 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineHeavy, left=LineHeavy, right=LineHeavy),
      )
    0x2534 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, left=LineLight, right=LineLight),
      )
    0x2535 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineHeavy, right=LineLight, up=LineLight),
      )
    0x2536 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(right=LineHeavy, left=LineLight, up=LineLight),
      )
    0x2537 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, left=LineHeavy, right=LineHeavy),
      )
    0x2538 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, left=LineLight, right=LineLight),
      )
    0x2539 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(right=LineLight, left=LineHeavy, up=LineHeavy),
      )
    0x253A =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineLight, right=LineHeavy, up=LineHeavy),
      )
    0x253B =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, left=LineHeavy, right=LineHeavy),
      )
    0x253C =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineLight,
          down=LineLight,
          left=LineLight,
          right=LineLight,
        ),
      )
    0x253D =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          left=LineHeavy,
          right=LineLight,
          up=LineLight,
          down=LineLight,
        ),
      )
    0x253E =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          right=LineHeavy,
          left=LineLight,
          up=LineLight,
          down=LineLight,
        ),
      )
    0x253F =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineLight,
          down=LineLight,
          left=LineHeavy,
          right=LineHeavy,
        ),
      )
    0x2540 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineHeavy,
          down=LineLight,
          left=LineLight,
          right=LineLight,
        ),
      )
    0x2541 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          down=LineHeavy,
          up=LineLight,
          left=LineLight,
          right=LineLight,
        ),
      )
    0x2542 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineHeavy,
          down=LineHeavy,
          left=LineLight,
          right=LineLight,
        ),
      )
    0x2543 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          left=LineHeavy,
          up=LineHeavy,
          right=LineLight,
          down=LineLight,
        ),
      )
    0x2544 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          right=LineHeavy,
          up=LineHeavy,
          left=LineLight,
          down=LineLight,
        ),
      )
    0x2545 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          left=LineHeavy,
          down=LineHeavy,
          right=LineLight,
          up=LineLight,
        ),
      )
    0x2546 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          right=LineHeavy,
          down=LineHeavy,
          left=LineLight,
          up=LineLight,
        ),
      )
    0x2547 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          down=LineLight,
          up=LineHeavy,
          left=LineHeavy,
          right=LineHeavy,
        ),
      )
    0x2548 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineLight,
          down=LineHeavy,
          left=LineHeavy,
          right=LineHeavy,
        ),
      )
    0x2549 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          right=LineLight,
          left=LineHeavy,
          up=LineHeavy,
          down=LineHeavy,
        ),
      )
    0x254A =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          left=LineLight,
          right=LineHeavy,
          up=LineHeavy,
          down=LineHeavy,
        ),
      )
    0x254B =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineHeavy,
          down=LineHeavy,
          left=LineHeavy,
          right=LineHeavy,
        ),
      )
    0x254C =>
      dash_horizontal(
        metrics,
        canvas,
        2U,
        ThicknessLight.height(metrics.box_thickness),
        ThicknessLight.height(metrics.box_thickness),
      )
    0x254D =>
      dash_horizontal(
        metrics,
        canvas,
        2U,
        ThicknessHeavy.height(metrics.box_thickness),
        ThicknessHeavy.height(metrics.box_thickness),
      )
    0x254E =>
      dash_vertical(
        metrics,
        canvas,
        2U,
        ThicknessLight.height(metrics.box_thickness),
        ThicknessHeavy.height(metrics.box_thickness),
      )
    0x254F =>
      dash_vertical(
        metrics,
        canvas,
        2U,
        ThicknessHeavy.height(metrics.box_thickness),
        ThicknessHeavy.height(metrics.box_thickness),
      )
    0x2550 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineDouble, right=LineDouble),
      )
    0x2551 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, down=LineDouble),
      )
    0x2552 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, right=LineDouble),
      )
    0x2553 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineDouble, right=LineLight),
      )
    0x2554 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineDouble, right=LineDouble),
      )
    0x2555 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, left=LineDouble),
      )
    0x2556 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineDouble, left=LineLight),
      )
    0x2557 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineDouble, left=LineDouble),
      )
    0x2558 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, right=LineDouble),
      )
    0x2559 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, right=LineLight),
      )
    0x255A =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, right=LineDouble),
      )
    0x255B =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, left=LineDouble),
      )
    0x255C =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, left=LineLight),
      )
    0x255D =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, left=LineDouble),
      )
    0x255E =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, down=LineLight, right=LineDouble),
      )
    0x255F =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, down=LineDouble, right=LineLight),
      )
    0x2560 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, down=LineDouble, right=LineDouble),
      )
    0x2561 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, down=LineLight, left=LineDouble),
      )
    0x2562 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, down=LineDouble, left=LineLight),
      )
    0x2563 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, down=LineDouble, left=LineDouble),
      )
    0x2564 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineLight, left=LineDouble, right=LineDouble),
      )
    0x2565 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineDouble, left=LineLight, right=LineLight),
      )
    0x2566 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(down=LineDouble, left=LineDouble, right=LineDouble),
      )
    0x2567 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, left=LineDouble, right=LineDouble),
      )
    0x2568 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, left=LineLight, right=LineLight),
      )
    0x2569 =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineDouble, left=LineDouble, right=LineDouble),
      )
    0x256A =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineLight,
          down=LineLight,
          left=LineDouble,
          right=LineDouble,
        ),
      )
    0x256B =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineDouble,
          down=LineDouble,
          left=LineLight,
          right=LineLight,
        ),
      )
    0x256C =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(
          up=LineDouble,
          down=LineDouble,
          left=LineDouble,
          right=LineDouble,
        ),
      )
    0x256D..=0x2573 => abort("box drawing arc and diagonal codepoint deferred")
    0x2574 => lines_char(metrics, canvas, sprite_draw_lines(left=LineLight))
    0x2575 => lines_char(metrics, canvas, sprite_draw_lines(up=LineLight))
    0x2576 => lines_char(metrics, canvas, sprite_draw_lines(right=LineLight))
    0x2577 => lines_char(metrics, canvas, sprite_draw_lines(down=LineLight))
    0x2578 => lines_char(metrics, canvas, sprite_draw_lines(left=LineHeavy))
    0x2579 => lines_char(metrics, canvas, sprite_draw_lines(up=LineHeavy))
    0x257A => lines_char(metrics, canvas, sprite_draw_lines(right=LineHeavy))
    0x257B => lines_char(metrics, canvas, sprite_draw_lines(down=LineHeavy))
    0x257C =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineLight, right=LineHeavy),
      )
    0x257D =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineLight, down=LineHeavy),
      )
    0x257E =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(left=LineHeavy, right=LineLight),
      )
    0x257F =>
      lines_char(
        metrics,
        canvas,
        sprite_draw_lines(up=LineHeavy, down=LineLight),
      )
    _ => abort("unreachable box drawing")
  }
}

///|
fn lines_char(
  metrics : Metrics,
  canvas : SpriteCanvas,
  lines : SpriteDrawLines,
) -> Unit {
  let light_px = ThicknessLight.height(metrics.box_thickness)
  let heavy_px = ThicknessHeavy.height(metrics.box_thickness)

  let h_light_top = saturating_sub_uint(metrics.cell_height, light_px) / 2U
  let h_light_bottom = saturating_add_uint(h_light_top, light_px)

  let h_heavy_top = saturating_sub_uint(metrics.cell_height, heavy_px) / 2U
  let h_heavy_bottom = saturating_add_uint(h_heavy_top, heavy_px)

  let h_double_top = saturating_sub_uint(h_light_top, light_px)
  let h_double_bottom = saturating_add_uint(h_light_bottom, light_px)

  let v_light_left = saturating_sub_uint(metrics.cell_width, light_px) / 2U
  let v_light_right = saturating_add_uint(v_light_left, light_px)

  let v_heavy_left = saturating_sub_uint(metrics.cell_width, heavy_px) / 2U
  let v_heavy_right = saturating_add_uint(v_heavy_left, heavy_px)

  let v_double_left = saturating_sub_uint(v_light_left, light_px)
  let v_double_right = saturating_add_uint(v_light_right, light_px)

  let up_bottom = if lines.left == LineHeavy || lines.right == LineHeavy {
    h_heavy_bottom
  } else if lines.left != lines.right || lines.down == lines.up {
    if lines.left == LineDouble || lines.right == LineDouble {
      h_double_bottom
    } else {
      h_light_bottom
    }
  } else if lines.left == LineNone && lines.right == LineNone {
    h_light_bottom
  } else {
    h_light_top
  }

  let down_top = if lines.left == LineHeavy || lines.right == LineHeavy {
    h_heavy_top
  } else if lines.left != lines.right || lines.up == lines.down {
    if lines.left == LineDouble || lines.right == LineDouble {
      h_double_top
    } else {
      h_light_top
    }
  } else if lines.left == LineNone && lines.right == LineNone {
    h_light_top
  } else {
    h_light_bottom
  }

  let left_right = if lines.up == LineHeavy || lines.down == LineHeavy {
    v_heavy_right
  } else if lines.up != lines.down || lines.left == lines.right {
    if lines.up == LineDouble || lines.down == LineDouble {
      v_double_right
    } else {
      v_light_right
    }
  } else if lines.up == LineNone && lines.down == LineNone {
    v_light_right
  } else {
    v_light_left
  }

  let right_left = if lines.up == LineHeavy || lines.down == LineHeavy {
    v_heavy_left
  } else if lines.up != lines.down || lines.right == lines.left {
    if lines.up == LineDouble || lines.down == LineDouble {
      v_double_left
    } else {
      v_light_left
    }
  } else if lines.up == LineNone && lines.down == LineNone {
    v_light_left
  } else {
    v_light_right
  }

  match lines.up {
    LineNone => ()
    LineLight =>
      canvas.box(
        v_light_left.reinterpret_as_int(),
        0,
        v_light_right.reinterpret_as_int(),
        up_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    LineHeavy =>
      canvas.box(
        v_heavy_left.reinterpret_as_int(),
        0,
        v_heavy_right.reinterpret_as_int(),
        up_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    LineDouble => {
      let left_bottom = if lines.left == LineDouble {
        h_light_top
      } else {
        up_bottom
      }
      let right_bottom = if lines.right == LineDouble {
        h_light_top
      } else {
        up_bottom
      }
      canvas.box(
        v_double_left.reinterpret_as_int(),
        0,
        v_light_left.reinterpret_as_int(),
        left_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
      canvas.box(
        v_light_right.reinterpret_as_int(),
        0,
        v_double_right.reinterpret_as_int(),
        right_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    }
  }

  match lines.right {
    LineNone => ()
    LineLight =>
      canvas.box(
        right_left.reinterpret_as_int(),
        h_light_top.reinterpret_as_int(),
        metrics.cell_width.reinterpret_as_int(),
        h_light_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    LineHeavy =>
      canvas.box(
        right_left.reinterpret_as_int(),
        h_heavy_top.reinterpret_as_int(),
        metrics.cell_width.reinterpret_as_int(),
        h_heavy_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    LineDouble => {
      let top_left = if lines.up == LineDouble {
        v_light_right
      } else {
        right_left
      }
      let bottom_left = if lines.down == LineDouble {
        v_light_right
      } else {
        right_left
      }
      canvas.box(
        top_left.reinterpret_as_int(),
        h_double_top.reinterpret_as_int(),
        metrics.cell_width.reinterpret_as_int(),
        h_light_top.reinterpret_as_int(),
        SpriteColor::on(),
      )
      canvas.box(
        bottom_left.reinterpret_as_int(),
        h_light_bottom.reinterpret_as_int(),
        metrics.cell_width.reinterpret_as_int(),
        h_double_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    }
  }

  match lines.down {
    LineNone => ()
    LineLight =>
      canvas.box(
        v_light_left.reinterpret_as_int(),
        down_top.reinterpret_as_int(),
        v_light_right.reinterpret_as_int(),
        metrics.cell_height.reinterpret_as_int(),
        SpriteColor::on(),
      )
    LineHeavy =>
      canvas.box(
        v_heavy_left.reinterpret_as_int(),
        down_top.reinterpret_as_int(),
        v_heavy_right.reinterpret_as_int(),
        metrics.cell_height.reinterpret_as_int(),
        SpriteColor::on(),
      )
    LineDouble => {
      let left_top = if lines.left == LineDouble {
        h_light_bottom
      } else {
        down_top
      }
      let right_top = if lines.right == LineDouble {
        h_light_bottom
      } else {
        down_top
      }
      canvas.box(
        v_double_left.reinterpret_as_int(),
        left_top.reinterpret_as_int(),
        v_light_left.reinterpret_as_int(),
        metrics.cell_height.reinterpret_as_int(),
        SpriteColor::on(),
      )
      canvas.box(
        v_light_right.reinterpret_as_int(),
        right_top.reinterpret_as_int(),
        v_double_right.reinterpret_as_int(),
        metrics.cell_height.reinterpret_as_int(),
        SpriteColor::on(),
      )
    }
  }

  match lines.left {
    LineNone => ()
    LineLight =>
      canvas.box(
        0,
        h_light_top.reinterpret_as_int(),
        left_right.reinterpret_as_int(),
        h_light_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    LineHeavy =>
      canvas.box(
        0,
        h_heavy_top.reinterpret_as_int(),
        left_right.reinterpret_as_int(),
        h_heavy_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    LineDouble => {
      let top_right = if lines.up == LineDouble {
        v_light_left
      } else {
        left_right
      }
      let bottom_right = if lines.down == LineDouble {
        v_light_left
      } else {
        left_right
      }
      canvas.box(
        0,
        h_double_top.reinterpret_as_int(),
        top_right.reinterpret_as_int(),
        h_light_top.reinterpret_as_int(),
        SpriteColor::on(),
      )
      canvas.box(
        0,
        h_light_bottom.reinterpret_as_int(),
        bottom_right.reinterpret_as_int(),
        h_double_bottom.reinterpret_as_int(),
        SpriteColor::on(),
      )
    }
  }
}

///|
fn dash_horizontal(
  metrics : Metrics,
  canvas : SpriteCanvas,
  count : UInt,
  thick_px : UInt,
  desired_gap : UInt,
) -> Unit {
  guard count >= 2U && count <= 4U else {
    abort("box horizontal dash count outside supported range")
  }

  let gap_count = count
  if metrics.cell_width < count + gap_count {
    hline_middle(metrics, canvas, ThicknessLight)
    return
  }

  let gap_width = @cmp.minimum(desired_gap, metrics.cell_width / (2U * count)).reinterpret_as_int()
  let count_int = count.reinterpret_as_int()
  let gap_count_int = gap_count.reinterpret_as_int()
  let total_gap_width = gap_count_int * gap_width
  let total_dash_width = metrics.cell_width.reinterpret_as_int() -
    total_gap_width
  let dash_width = total_dash_width / count_int
  let remaining = total_dash_width % count_int

  guard dash_width * count_int + gap_width * gap_count_int + remaining ==
    metrics.cell_width.reinterpret_as_int() else {
    abort("box horizontal dash width invariant failed")
  }

  let y = (saturating_sub_uint(metrics.cell_height, thick_px) / 2U).reinterpret_as_int()
  let mut x = gap_width / 2
  let mut extra = remaining

  for _ in 0..<count_int {
    let mut x1 = x + dash_width
    if extra > 0 {
      extra -= 1
      x1 += 1
    }
    hline(canvas, x, x1, y, thick_px)
    x = x1 + gap_width
  }
}

///|
fn dash_vertical(
  metrics : Metrics,
  canvas : SpriteCanvas,
  count : UInt,
  thick_px : UInt,
  desired_gap : UInt,
) -> Unit {
  guard count >= 2U && count <= 4U else {
    abort("box vertical dash count outside supported range")
  }

  let gap_count = count
  if metrics.cell_height < count + gap_count {
    vline_middle(metrics, canvas, ThicknessLight)
    return
  }

  let gap_height = @cmp.minimum(desired_gap, metrics.cell_height / (2U * count)).reinterpret_as_int()
  let count_int = count.reinterpret_as_int()
  let gap_count_int = gap_count.reinterpret_as_int()
  let total_gap_height = gap_count_int * gap_height
  let total_dash_height = metrics.cell_height.reinterpret_as_int() -
    total_gap_height
  let dash_height = total_dash_height / count_int
  let remaining = total_dash_height % count_int

  guard dash_height * count_int + gap_height * gap_count_int + remaining ==
    metrics.cell_height.reinterpret_as_int() else {
    abort("box vertical dash height invariant failed")
  }

  let x = (saturating_sub_uint(metrics.cell_width, thick_px) / 2U).reinterpret_as_int()
  let mut y = 0
  let mut extra = remaining

  for _ in 0..<count_int {
    let mut y1 = y + dash_height
    if extra > 0 {
      extra -= 1
      y1 += 1
    }
    vline(canvas, y, y1, x, thick_px)
    y = y1 + gap_height
  }
}
