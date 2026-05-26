import gleam/string

pub type SmtpCommand {
  Ehlo(domain: String)
  Helo(domain: String)
  MailFrom(address: String)
  RcptTo(address: String)
  Data
  Quit
  Unknown(raw: String)
}

pub fn parse(line: String) -> SmtpCommand {
  let cmd = string.uppercase(string.slice(line, 0, 4))
  let args = string.trim(string.drop_start(line, 4))
  case cmd {
    "EHLO" -> Ehlo(args)
    "HELO" -> Helo(args)
    "MAIL" -> MailFrom(clean_recipient(string.drop_start(args, 5)))
    "RCPT" -> RcptTo(clean_recipient(string.drop_start(args, 3)))
    "DATA" -> Data
    "QUIT" -> Quit
    _ -> Unknown(line)
  }
}

fn clean_recipient(recipient: String) {
  recipient
  |> string.replace("<", "")
  |> string.replace(">", "")
  |> string.trim()
}
