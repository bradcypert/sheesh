import gleam/io
import gleam/option.{type Option}
import gleam/string

pub type SmtpSession {
  SmtpSession(
    state: SessionState,
    buffer: String,
    from: Option(String),
    to: List(String),
    data_lines: List(String),
  )
}

pub type SessionState {
  Greeting
  // after EHLO/HELO
  Ready
  // after MAIL from
  MailFrom
  // After RCPT TO (can loop)
  RcptTo
  // Collecting Body lines
  Data
  // after QUIT
  Quit
}

fn session_state_to_string(state: SessionState) {
  case state {
    Greeting -> "Greeting"
    Ready -> "Ready"
    MailFrom -> "MailFrom"
    RcptTo -> "RcptTo"
    Data -> "Data"
    Quit -> "Quit"
  }
}

// TODO: Bufferpoool this?
pub fn new() -> SmtpSession {
  SmtpSession(
    state: Greeting,
    buffer: "",
    from: option.None,
    to: [],
    data_lines: [],
  )
}

pub fn print_session(session: SmtpSession) {
  let from = case session.from {
    option.None -> "None"
    option.Some(f) -> f
  }
  io.println("{")
  io.println("\tState: " <> session_state_to_string(session.state))
  io.println("\tBuffer: " <> session.buffer)
  io.println("\tFrom: " <> from)
  io.println("\tTo: [" <> string.join(session.to, with: ",") <> "]")
  io.println(
    "\tData Lines: [\n" <> string.join(session.data_lines, with: "\n") <> "]",
  )
  io.println("}")
}
