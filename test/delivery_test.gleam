import delivery
import gleam/string

pub fn render_message_reverses_body_test() {
  // stored reversed (preprending during collection) but needs to render in proper order
  let msg =
    delivery.render_message("test@test.com", ["qa@qa.com"], ["line2", "line1"])
  assert string.contains(msg, "line1\r\nline2")
}

pub fn render_message_includes_envelope_test() {
  let msg = delivery.render_message("test@test.com", ["qa@qa.com"], [])
  assert string.contains(msg, "Return-Path: <test@test.com>")
}
