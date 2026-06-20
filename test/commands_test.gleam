import command.{parse}

pub fn parse_ehlo_test() {
  let out =
    "EHLO www.bradcypert.com"
    |> parse()

  assert out == command.Ehlo("www.bradcypert.com")
}

pub fn parse_helo_test() {
  let out =
    "HELO www.bradcypert.com"
    |> parse()

  assert out == command.Helo("www.bradcypert.com")
}

pub fn parse_mail_test() {
  let out =
    "MAIL FROM: hello@bradcypert.com"
    |> parse()

  assert out == command.MailFrom("hello@bradcypert.com")
}

pub fn parse_rcpt_test() {
  let out =
    "RCPT TO: hello@bradcypert.com"
    |> parse()

  assert out == command.RcptTo("hello@bradcypert.com")
}

pub fn parse_data_test() {
  let out =
    "DATA"
    |> parse()

  assert out == command.Data
}

pub fn parse_quit_test() {
  let out =
    "QUIT"
    |> parse()

  assert out == command.Quit
}

pub fn unstuff_double_dot_test() {
  assert command.unstuff("..foo") == ".foo"
}

pub fn unstuff_plain_line_unchanged_test() {
  assert command.unstuff("foo") == "foo"
}
