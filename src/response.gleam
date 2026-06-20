import gleam/int
import gleam/list
import gleam/string

pub type SmtpResponse {
  ServiceReady(domain: String)
  Ok
  // Multiline EHLO capability replies
  Ehlo(domain: String, capabilities: List(String))
  StartMailInput
  Queued(message_id: String)
  Bye
  BadSequence
  UnknownCommand
  SyntaxError
}

pub fn render(response: SmtpResponse) -> String {
  case response {
    ServiceReady(domain) -> line(220, domain <> " ESMTP sheesh")
    Ok -> line(250, "OK")
    StartMailInput -> line(354, "End data with <CR><LF>.<CR><LF>")
    Queued(id) -> line(250, "OK: queued as " <> id)
    Bye -> line(221, "Bye")
    BadSequence -> line(503, "Bad sequence of commands")
    UnknownCommand -> line(500, "Unknown command")
    SyntaxError -> line(501, "Syntax error in parameters or arguments")
    Ehlo(domain, capabilities) -> render_multiline(domain, capabilities)
  }
}

fn line(code: Int, text: String) -> String {
  int.to_string(code) <> " " <> text <> "\r\n"
}

fn render_multiline(domain: String, capabilities: List(String)) -> String {
  let lines = [domain, ..capabilities]
  let count = list.length(lines)
  lines
  |> list.index_map(fn(text, i) {
    let sep = case i == count - 1 {
      True -> " "
      False -> "-"
    }
    "250" <> sep <> text <> "\r\n"
  })
  |> string.concat
}
