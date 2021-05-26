module tokenize

// Reports an error
fun error( msg : string ) : exn a {
  throw("error: " ++ msg)
}

// Report an error with location information.
public fun error-at( literal : sslice, msg : string ) : exn a {
  val before-ltr = literal.before()
  val input = before-ltr.before().after()
  val error-msg = input.string() ++ "\n" ++ " ".repeat(before-ltr.count()) ++ "^ error: " ++ msg
  throw(error-msg)
}

public type token-kind {
  TokReserved     // keywords or punctuators
  TokNumber       // integer literals
  TokEof          // end-of-file markers
}

// Token type
public struct token {
  kind : token-kind
  value : maybe<int> = Nothing
  literal : maybe<sslice> = Nothing
}

fun show( tok : token ) : <console> string {
  val kind = match (tok.kind) {
    TokReserved -> "TokReserved"
    TokNumber -> "TokNumber"
    TokEof -> "TokEof"
  }

  val value = match (tok.value) {
    Just(n) -> n.show()
    _ -> "Nothing"
  }

  val literal = match (tok.literal) {
    Just(s) -> s.show()
    _ -> "Nothing"
  }

  "Token { kind : " ++ kind ++ ", value : " ++ value ++ ", literal : " ++ literal ++ " }"
}

fun at-eof( tokens : list<token> ) : bool {
  match (tokens) {
    Cons(Token(TokEof, value = _, literal = _), _) -> True
    Cons(_) -> False
    _ -> True
  }
}

// Tokenize input and returns tokens
public fun tokenize( input : string ) : <console, div, exn> list<token> {
  fun first-of-length( slice, n ) {
    val input-head = input.first(n)
    val to-slice-distance = slice.before().count()
    input-head.advance(to-slice-distance)
  }

  fun starts-with( slice : sslice, pre : string ) {
    fun compare( slice, pre) {
      match (slice.next(), pre.next()) {
        (Just((cs, ss)), Just((cp, sp))) -> if (cs != cp) then Nothing else compare(ss, sp)
        (_, Nothing) -> Just(slice)
        _ -> Nothing
      }
    }

    match (compare(slice, pre.first(pre.count()))) {
      Just(s) -> Just((slice.first-of-length(pre.count()), s))
      _ -> Nothing
    }
  }

  fun starts-with-white( slice ) {
    match (slice.next()) {
      Just((c, s)) -> if (c.is-white()) then Just((slice.first-of-length(1), s)) else Nothing
      _ -> Nothing
    }
  }

  fun starts-with-punct( slice ) {
    fun is-punct( c ) {
      c == '+' || c == '-' || c == '*' || c == '/' || c == '(' || c == ')' || c == '<' || c == '>'
    }

    match (slice.next()) {
      Just((c, s)) -> if (c.is-punct()) then Just((slice.first-of-length(1), s)) else Nothing
      _ -> Nothing
    }
  }

  fun starts-with-number( slice ) {
    fun parse-number ( slice, accum ) {
      match (slice.next()) {
        Just((c, s)) -> if (c.is-digit()) {
          val num = match (accum) { Just(n) -> n; _ -> 0 }
          parse-number(s, Just(num * 10 + (c - '0').int()))
        }
        else (slice, accum)

        _ -> (slice, accum)
      }
    }

    val (s, n) = parse-number(slice, Nothing)
    match (n) {
      Just(num) -> {
        val num-len = slice.count() - s.count()
        Just((num, (slice.first-of-length(num-len), s)))
      }
      Nothing -> Nothing
    }
  }

  fun tokenize-internal( slice : sslice, tokens ) {
    if (slice.is-empty()) then {
      val eof-tok = Token(TokEof, literal = Just(slice))
      return Cons(eof-tok, tokens)
    }

    // Skip white space characters.
    match (slice.starts-with-white()) {
      Just((_, s)) -> return tokenize-internal(s, tokens)
      _ -> ()
    }

    // Multi-letter punctuators
    if (slice.starts-with("==").bool() || slice.starts-with("!=").bool() ||
        slice.starts-with("<=").bool() || slice.starts-with(">=").bool()) {
      val pre = slice.first-of-length(2)
      val punct-tok = Token(TokReserved, literal = Just(pre))
      return tokenize-internal(pre.after(), Cons(punct-tok, tokens))
    }

    // Single-letter punctuators
    match (slice.starts-with-punct()) {
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
