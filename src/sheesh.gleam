import command
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/io
import gleam/option.{None}
import gleam/string
import glisten.{Packet}
import response
import session

pub fn main() -> Nil {
  io.println("Hello from sheesh!")

  let assert Ok(_) =
    glisten.new(
      fn(conn) {
        let assert Ok(_) =
          conn_send_string(
            conn,
            // TODO: Pull out the localhost to an env var or similar
            response.render(response.ServiceReady("localhost")),
          )
        #(session.new(), None)
      },
      loop,
    )
    |> glisten.start(3000)

  process.sleep_forever()
}

fn loop(state: session.SmtpSession, msg, conn) {
  case msg {
    Packet(bits) -> {
      session.print_session(state)
      let assert Ok(text) = bit_array.to_string(bits)
      io.println("recieved message: " <> text)
      process_lines(state.buffer <> text, state, conn)
    }
    _ -> glisten.continue(state)
  }
}

fn process_lines(buffer: String, state: session.SmtpSession, conn) {
  io.println("\n" <> buffer <> "\n")
  case state.state {
    session.Quit -> glisten.stop()
    _ -> process_lines_inner(buffer, state, conn)
  }
}

fn process_lines_inner(buffer: String, state: session.SmtpSession, conn) {
  case string.split_once(buffer, "\r\n") {
    Error(_) -> {
      // No complete line, keep buffering
      glisten.continue(session.SmtpSession(..state, buffer: buffer))
    }
    Ok(#(line, rest)) -> {
      let next_state =
        handle_line(line, session.SmtpSession(..state, buffer: rest), conn)
      process_lines(rest, next_state, conn)
    }
  }
}

fn handle_line(
  line: String,
  state: session.SmtpSession,
  conn,
) -> session.SmtpSession {
  case state.state {
    session.Data -> handle_data_line(line, state, conn)
    _ -> {
      case state.state, command.parse(line) {
        _, command.Ehlo(domain:) | _, command.Helo(domain:) -> {
          send(conn, response.Ehlo(domain, ["8BITMIME"]))
          session.reset_transaction(state)
        }
        session.Ready, command.MailFrom(address:) -> {
          send(conn, response.Ok)
          session.SmtpSession(
            ..state,
            state: session.MailFrom,
            from: option.Some(address),
          )
        }
        session.MailFrom, command.RcptTo(address:)
        | session.RcptTo, command.RcptTo(address:)
        -> {
          send(conn, response.Ok)
          session.SmtpSession(..state, state: session.RcptTo, to: [
            address,
            ..state.to
          ])
        }
        session.RcptTo, command.Data -> {
          send(conn, response.StartMailInput)
          session.SmtpSession(..state, state: session.Data)
        }
        _, command.Quit -> {
          send(conn, response.Bye)
          session.SmtpSession(..state, state: session.Quit)
        }
        _, command.Unknown(_) -> {
          send(conn, response.UnknownCommand)
          state
        }
        _, _ -> {
          send(conn, response.BadSequence)
          state
        }
      }
    }
  }
}

fn handle_data_line(
  line: String,
  state: session.SmtpSession,
  conn: glisten.Connection(a),
) -> session.SmtpSession {
  case line {
    "." -> {
      // end of message, deliver it!
      // TODO: "queued as ${messageID}"
      send(conn, response.Queued("..."))
      // TODO: ACTUALLY SEND/QUEUE IT
      session.reset_transaction(state)
    }
    _ -> {
      // RFC 5321 4.5.2: a leading '.' on a body line was stuffed by the sender, strip one back off.
      let content = command.unstuff(line)
      // TODO: list.reverse data lines when performing delivery. Much faster to prepend for now, but need to reverse when sending
      session.SmtpSession(..state, data_lines: [content, ..state.data_lines])
    }
  }
}

fn send(conn, response: response.SmtpResponse) {
  let assert Ok(_) = conn_send_string(conn, response.render(response))
  Nil
}

fn conn_send_string(conn, string: String) {
  glisten.send(conn, bytes_tree.from_string(string))
}
