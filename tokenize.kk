module tokenize

import kleincc

public noinline val remained-tokens = unsafe-total { ref(Nil) }

// Reports an error
public fun error( msg : string ) : exn a {
  throw("error: " ++ msg)
}

// Report an error with location information then exit.
public fun error-at( literal : sslice, msg : string ) : exn a {
  val before-ltr = literal.before()
  val input = before-ltr.before().after()
  val error-msg = input.string() ++ "\n" ++ " ".repeat(before-ltr.count()) ++ "^ error: " ++ msg
  throw(error-msg)
}

// Report an error with location information then exit.
public fun error-token( token : token, msg : string ) : <console, exn> a {
  match (token.literal) {
    Nothing -> error(msg)

    Just(ss) -> error-at(ss, msg)
  }
}

fun consume-current( token, tokens ) : <write<global>> maybe<token> {
  last-consumed-token := Just(token)
  remained-tokens := tokens
  Just(token)
}

// Consume the current token if it matches `op`.
public fun consume( op : string ) : <console> maybe<token> {
  match (!remained-tokens) {
    Cons(token, tokens) -> {
      match (token) {
        Token(TokReserved, literal = Just(literal)) ->
          if (op == literal.string())
          then {
            consume-current(token, tokens)
          }
          else Nothing

        _ -> Nothing
      }
    }

    _ -> Nothing
  }
}

// Return true if the current token matches `op`.
public fun peek( op : string ) : <console> maybe<token> {
  match (!remained-tokens) {
    Cons(token) -> {
      match (token) {
        Token(TokReserved, literal = Just(literal)) -> {
          if (op == literal.string()) then Just(token)
          else Nothing
        }

        _ -> Nothing
      }
    }

    _ -> Nothing
  }
}

// Peek a token if exists
public fun blicken() : <console> maybe<token> {
  match (!remained-tokens) {
    Cons(token) -> Just(token)

    _ -> Nothing
  }
}

// Consume the current token if it is an identifier.
public fun consume-ident() : <console> maybe<token> {
  match (!remained-tokens) {
    Cons(token, tokens) -> {
      match (token) {
        Token(TokIdent) -> {
          consume-current(token, tokens)
        }

        _ -> Nothing
      }
    }

    _ -> Nothing
  }
}

// Consume the current token if it is a string literal.
public fun consume-string-literal() : <console> maybe<token> {
  match (!remained-tokens) {
    Cons(token, tokens) -> {
      match (token) {
        Token(TokStr) -> {
          consume-current(token, tokens)
        }

        _ -> Nothing
      }
    }

    _ -> Nothing
  }
}

// Ensure that the current token is `op`.
public fun expect( op : string ) : <console, exn> () {
  val msg = "expected " ++ op
  match (!remained-tokens) {
    Cons(token, tokens) -> {
      match (peek(op)) {
        Just(_) -> {
          consume-current(token, tokens)
          ()
        }

        _ -> error-token(token, msg)
      }
    }
  }
}

// Ensure that the current token is TokNumber.
public fun expect-number() : <console, exn> int {
  match (!remained-tokens) {
    Cons(token, tokens) -> {
      match (token) {
        Token(TokNumber, value = Just(num)) -> {
          consume-current(token, tokens)
          num
        }

        _ -> error-token(token, "expected a number")
      }
    }
  }
}

// Ensure that the current token is TokIdent.
public fun expect-ident() : <console, exn> sslice {
  match (!remained-tokens) {
    Cons(token, tokens) -> {
      match (token) {
        Token(TokIdent, literal = Just(ident)) -> {
          consume-current(token, tokens)
          ident
        }

        _ -> error-token(token, "expected an identifier")
      }
    }
  }
}

public fun at-eof() : bool {
  match (!remained-tokens) {
    Cons(Token(TokEof)) -> True

    Cons(_) -> False

    _ -> True
  }
}

// Tokenize input and returns tokens
public fun tokenize( input : string ) : <console, div, exn> list<token> {
  fun first-of-length( slice, n ) {
    input.first(n).advance(slice.before().count())
  }

  fun starts-with( slice : sslice, pre : string ) {
    fun compare( s, p ) {
      match (s.next(), p.next()) {
        (Just((cs, ss)), Just((cp, sp))) -> if (cs != cp) then Nothing else compare(ss, sp)

        (_, Nothing) -> Just(s)

        _ -> Nothing
      }
    }

    compare(slice, pre.first(pre.count())).map(
      fn (s) { (slice.first-of-length(pre.count()), s) }
    )
  }

  fun starts-with-char-predicate( slice : sslice, pred : (char) -> bool) {
    slice.next().maybe(
      onNothing = Nothing,

      onJust = fn ((c, s)) {
        if (c.pred()) then Just((slice.first-of-length(1), s)) else Nothing
      }
    )
  }

  fun starts-with-string-literal( slice : sslice ) {
    fun parse ( s, n ) {
      match (s.next()) {
        Just((c, sn)) -> {
          if (c != '"') then parse(sn, n + 1)
          else Just((slice.advance(1).first-of-length(n), sn))
        }

        _ -> Nothing
      }

      s.next().maybe(
        onNothing = Nothing,

        onJust = fn ((c, sn)) {
          if (c != '"') then parse(sn, n + 1)
          else Just((slice.advance(1).first-of-length(n), sn))
        }
      )
    }

    slice.next().maybe(
      onNothing = Nothing,

      onJust = fn ((c, ts)) {
        if (c != '"') then Nothing
        else {
          val result = parse(ts, 0)
          if (result.bool()) then result
          else error-at(slice, "unclosed string literal")
        }
      }
    )
  }

  fun starts-with-keyword( slice : sslice, keyword : string ) {
    slice.starts-with(keyword).maybe(
      onNothing = Nothing,
      onJust = fn ((pre, suf)) {
        suf.next().maybe(
          onNothing = Just((pre, suf)),

          onJust = fn ((c, _)) {
            if (!c.is-alpha-num() && c != '_') then Just((pre, suf))
            else Nothing
          }
        )
      }
    )
  }

  fun starts-with-reserved( slice : sslice ) {
    val keywords = ["return", "if", "else", "while", "for", "int", "sizeof", "char"]
    val maybe-keyword = keywords.foreach-while(fn (kw) { slice.starts-with-keyword(kw) })

    if (maybe-keyword.bool())
    then maybe-keyword
    else {
      val ops = [">=", "<=", "!=", "=="]
      ops.foreach-while(fn (op) { slice.starts-with(op) })
    }
  }

  fun starts-with-identifier( slice : sslice ) {
    fun parse ( s, n ) {
      val get-ident = fn () { slice.first-of-length(n) }

      match (s.next()) {
        Nothing -> Just((get-ident(), s))

        Just((c, ts)) -> {
          if (c.is-alpha-num() || c == '_') then parse(ts, n + 1)
          else Just((get-ident(), s))
        }
      }
    }

    slice.next().maybe(
      onNothing = Nothing,

      onJust = fn ((c, s)) {
        if (c.is-alpha() || c == '_') then parse(s, 1)
        else Nothing
      }
    )
  }

  fun is-punct( c ) {
    c == '+' || c == '-' || c == '*' || c == '/' || c == '(' || c == ')' ||
      c == '<' || c == '>' || c == '=' || c == '{' || c == '}' || c == ';' ||
      c == ',' || c == '&' || c == '[' || c == ']'
  }

  fun starts-with-number( slice ) {
    fun parse-number ( s, accum ) {
      s.next().maybe(
        onNothing = (s, accum),

        onJust = fn((c, ss)) {
          if (c.is-digit()) {
            val num = match (accum) { Just(n) -> n; _ -> 0 }
            parse-number(ss, Just(num * 10 + (c - '0').int()))
          }
          else (s, accum)
        }
      )
    }

    val (s, n) = parse-number(slice, Nothing)
    n.map(
      fn (num) {
        val num-len = slice.count() - s.count()
        (num, (slice.first-of-length(num-len), s))
      }
    )
  }

  fun tokenize-internal( slice : sslice, tokens : list<token> ) {
    if (slice.is-empty()) then {
      val eof-tok = Token(TokEof, literal = Just(slice))
      return Cons(eof-tok, tokens)
    }

    // Skip white space characters.
    match (slice.next()) {
      Just((c, s)) -> {
        if (c.is-white()) then return tokenize-internal(s, tokens)
        else ()
      }

      _ -> ()
    }

    // String literal.
    match (slice.starts-with-string-literal()) {
      Just((str, suf)) -> {
        val str-tok = Token(
          TokStr,
          literal = Just(slice.first-of-length(slice.count() - suf.count())),
          contents = Just(str.string())
        )
        return tokenize-internal(suf, Cons(str-tok, tokens))
      }

      _ -> ()
    }

    // Keywords or multi-letter punctuators.
    match (slice.starts-with-reserved()) {
      Just((resv, suf)) -> {
        val resv-tok = Token(TokReserved, literal = Just(resv))
        return tokenize-internal(suf, Cons(resv-tok, tokens))
      }

      _ -> ()
    }

    // Identifier.
    match (slice.starts-with-identifier()) {
      Just((ident, suf)) -> {
        val ident-tok = Token(TokIdent, literal = Just(ident))
        return tokenize-internal(suf, Cons(ident-tok, tokens))
      }

      _ -> ()
    }

    // Single-letter punctuators.
    match (slice.starts-with-char-predicate(is-punct)) {
      Just((pre, suf)) -> {
        val punct-tok = Token(TokReserved, literal = Just(pre))
        return tokenize-internal(suf, Cons(punct-tok, tokens))
      }

      _ -> ()
    }

    // Integer literals
    match (slice.starts-with-number()) {
      Just((n, (pre, suf))) -> {
        val num-tok = Token(TokNumber, literal = Just(pre), value = Just(n))
        return tokenize-internal(suf, Cons(num-tok, tokens))
      }

      _ -> ()
    }

    error-at(slice, "invalid token")
  }

  val tokens = tokenize-internal(input.first(input.count()), Nil)
  tokens.reverse()
}
