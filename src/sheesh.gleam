import command
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/string
import glisten.{Packet}
import session

pub fn main() -> Nil {
  io.println("Hello from sheesh!")

  let assert Ok(_) =
    glisten.new(
      fn(conn) {
        let assert Ok(_) =
          conn_send_string(conn, "220 localhost ESMTP sheesh\r\n")
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
    session.Greeting -> {
      case command.parse(line) {
        command.Ehlo(_domain) | command.Helo(_domain) -> {
          let assert Ok(_) = conn_send_string(conn, "250 OK\r\n")
          session.SmtpSession(..state, state: session.Ready)
        }
        _ -> {
          let assert Ok(_) =
            conn_send_string(conn, "503 Bad sequence of commands\r\n")
          state
        }
      }
    }
    _ -> {
      case command.parse(line) {
        command.Ehlo(_domain) | command.Helo(_domain) -> {
          let assert Ok(_) = conn_send_string(conn, "250 OK\r\n")
          session.SmtpSession(..state, state: session.Ready)
        }
        command.MailFrom(address:) -> {
          let assert Ok(_) = conn_send_string(conn, "250 OK\r\n")
          session.SmtpSession(
            ..state,
            state: session.MailFrom,
            from: option.Some(address),
          )
        }
        command.RcptTo(address:) -> {
          let assert Ok(_) = conn_send_string(conn, "250 OK\r\n")
          session.SmtpSession(..state, state: session.RcptTo, to: [
            address,
            ..state.to
          ])
        }
        command.Data -> {
          let assert Ok(_) =
            conn_send_string(conn, "354 End data with <CR><LF>.<CR><LF>\r\n")
          session.SmtpSession(..state, state: session.Data)
        }
        command.Quit -> {
          let assert Ok(_) = conn_send_string(conn, "221 Bye\r\n")
          session.SmtpSession(..state, state: session.Quit)
        }
        _ -> {
          let assert Ok(_) = conn_send_string(conn, "500 Unknown Command\r\n")
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
      let assert Ok(_) = conn_send_string(conn, "250 OK: queued\r\n")
      // TODO: ACTUALLY SEND/QUEUE IT
      session.SmtpSession(..state, state: session.Ready, data_lines: [])
    }
    _ -> {
      session.SmtpSession(..state, data_lines: list.append(state.data_lines, [line]))
    }
  }
}

fn conn_send_string(conn, string: String) {
  glisten.send(conn, bytes_tree.from_string(string))
}
