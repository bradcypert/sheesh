import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp
import simplifile

// TODO: Env var???
const maildir = "./mail"

pub type DeliveryError {
  WriteFailed(simplifile.FileError)
}

pub fn setup() {
  let assert Ok(_) = simplifile.create_directory_all(maildir <> "/tmp")
  let assert Ok(_) = simplifile.create_directory_all(maildir <> "/new")
}

/// Assemble and persist one message
/// returns message ID on success
pub fn deliver(
  from: String,
  to: List(String),
  data_lines: List(String),
) -> Result(String, DeliveryError) {
  let id = message_id()
  let message = render_message(from, to, data_lines)
  let tmp_path = maildir <> "/tmp/" <> id <> ".eml"
  let new_path = maildir <> "/new/" <> id <> ".eml"

  // Write to tmp then rename into new is because rename is atomic
  use _ <- result.try(
    simplifile.write(tmp_path, message)
    |> result.map_error(WriteFailed),
  )

  simplifile.rename(tmp_path, new_path)
  |> result.map_error(WriteFailed)
  |> result.map(fn(_) { id })
}

pub fn render_message(
  from: String,
  to: List(String),
  data_lines: List(String),
) -> String {
  let body = data_lines |> list.reverse |> string.join("\r\n")

  "Return-Path: <"
  <> from
  <> ">\r\n"
  <> "Delivered-To: "
  <> string.join(to, ", ")
  <> "\r\n"
  <> body
}

fn message_id() -> String {
  let #(seconds, _nanos) =
    timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds()

  int.to_string(seconds)
  <> "."
  <> int.to_string(int.random(1_000_000))
  <> ".sheesh"
}
