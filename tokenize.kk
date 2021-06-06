module tokenize

import support

// Reports an error
public fun error( msg : string ) : exn a {
  throw("error: " ++ msg)
}

// Report an error with location information.
public fun error-at( literal : sslice, msg : string ) : exn a {
  val before-ltr = literal.before()
  val input = before-ltr.before().after()
  val error-msg = input.string() ++ "\n" ++ " ".repeat(before-ltr.count()) ++ "^ error: " ++ msg
  throw(error-msg)
}

// Token
public type token-kind {
  TokReserved     // keywords or punctuators
  TokIdent        // identifiers
  TokNumber       // integer literals
  TokEof          // end-of-file markers
}

// Token type
public struct token {
  kind : token-kind
  value : maybe<int> = Nothing
  literal : maybe<sslice> = Nothing
}

public fun show( tok : token, indent : int = 0 ) : <console> string {
  val kind = match (tok.kind) {
    TokReserved -> "reserved"
    TokIdent -> "identifier"
    TokNumber -> "number"
    TokEof -> "eof"
  }

  val value = tok.value.maybe(
    onNothing = "nothing",
    onJust = fn(n) { n.show() }
  )

  val literal = tok.literal.maybe(
    onNothing = "nothing",
    onJust = fn (s) { s.show() }
  )

  "Token { kind : " ++ kind ++ ", value : " ++ value ++ ", literal : " ++ literal ++ " }"
}

// Tokenize input and returns tokens
public fun tokenize( input : string ) : <console, div, exn> list<token> {
  fun first-of-length( slice, n ) {
    val input-head = input.first(n)
    val to-slice-distance = slice.before().count()
    input-head.advance(to-slice-distance)
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

  fun starts-with-keyword( slice : sslice, keyword : string ) {
    slice.starts-with(keyword).maybe(
      onNothing = Nothing,
      onJust = fn ((pre, suf)) {
        suf.starts-with-char-predicate(fn (c) { !c.is-alpha-num() && c != '_' })
           .map(fn (_) { (pre, suf) })
      }
    )
  }

  fun starts-with-reserved( slice : sslice ) {
    with control continue() {
      val ops = Cons("==", Cons("!=", Cons("<=", Cons(">=", Nil))))
      ops.foreach-while(fn (op) { slice.starts-with(op) })
    }

    val keywords = Cons("while", Cons("return", Cons("if", Cons("else", Nil))))
    keywords.foreach-while(fn (kw) { slice.starts-with-keyword(kw) }).just-or-continue()
  }

  fun starts-with-identifier( slice : sslice ) {
    fun parse( s, n ) {
      s.starts-with-char-predicate(is-alpha-num).maybe(
        onNothing = n,
        onJust = fn ((_, pre)) { parse(pre, n + 1) }
      )
    }

    slice.starts-with-char-predicate(is-alpha).map(fn ((_, pre)) {
      val ident-len = parse(pre, 1)
      val ident = slice.first-of-length(ident-len)
      (ident, ident.after())
    })
  }

  fun is-punct( c ) {
    if (c == '+' || c == '-' || c == '*' || c == '/' || c == '(' || c == ')') then True
    elif (c == '<' || c == '>' || c == ';' || c == '=') then True
    else False
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
    match (slice.starts-with-char-predicate(is-white)) {
      Just((_, s)) -> return tokenize-internal(s, tokens)

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

    // Identifier
    match (slice.starts-with-identifier()) {
      Just((ident, suf)) -> {
        val ident-tok = Token(TokIdent, literal = Just(ident))
        return tokenize-internal(suf, Cons(ident-tok, tokens))
      }

      _ -> ()
    }

    // Single-letter punctuators
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
