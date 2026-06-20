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
    "MAIL" -> MailFrom(extract_address(args))
    "RCPT" -> RcptTo(extract_address(args))
    "DATA" -> Data
    "QUIT" -> Quit
    _ -> Unknown(line)
  }
}

// args looks like "FROM:<a@b> BODY=8BITMIME SIZE=2048" or the lenient "TO: a@b".
// Drop the FROM/TO keyword, then take just the address token (the contents of
// <...> if present, otherwise the first whitespace-delimited word), discarding
// any trailing ESMTP parameters.
fn extract_address(args: String) -> String {
  let after_colon = case string.split_once(args, ":") {
    Ok(#(_keyword, rest)) -> rest
    Error(_) -> args
  }
  let trimmed = string.trim(after_colon)

  case string.split_once(trimmed, "<") {
    Ok(#(_, rest)) ->
      case string.split_once(rest, ">") {
        Ok(#(addr, _params)) -> addr
        Error(_) -> rest
      }
    Error(_) ->
      case string.split_once(trimmed, " ") {
        Ok(#(addr, _params)) -> addr
        Error(_) -> trimmed
      }
  }
}

pub fn unstuff(line: String) -> String {
  case string.starts_with(line, ".") {
    True -> string.drop_start(line, 1)
    False -> line
  }
}
