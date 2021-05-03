import std/os/env

type token-kind {
  TokReserved     // keywords or punctuators
  TokNumber       // integer literals
  TokEof          // end-of-file markers
}

// Token type
struct token {
  kind : token-kind
  value : maybe<int> = Nothing
  literal : maybe<sslice> = Nothing
}

// Reports an error
fun error( msg : string ) : exn a {
  throw("error: " ++ msg)
}

// Report an error with location information.
fun error_at( msg : string, literal : ?sslice ) : exn a {
  val msg = match (literal) {
    None -> "error: " ++ msg
    Optional(literal) -> {
      val before-ltr = literal.before()
      val input = before-ltr.before().after() // before of before is an empty, after this empty is the slice of the entire string
      input.string() ++ "\n" ++ " ".repeat(before-ltr.count()) ++ "^ error: " ++ msg
    }
  }

  throw(msg)
}

// Consume the current token if it maches `op`
fun consume( op : char, tokens : list<token> ) : (bool, list<token>) {
  match (tokens) {
    Cons(Token(TokReserved, literal = Just(literal), value = _), next-tokens) ->
      if (op.string() == literal.string()) then (True, next-tokens) else (False, tokens)
    _ -> (False, tokens)
  }
}

// Ensure that the current token is `op`
fun expect( op : char, tokens : list<token> ) : <exn> list<token> {
  val op = op.string()
  match (tokens) {
    Cons(Token(TokReserved, literal = Just(literal), value = _), next-tokens) ->
        if (op == literal.string()) then next-tokens else error_at("expected " ++ op, literal)
    Cons(Token(kind = _, literal = Just(literal), value = _), _) -> error_at("expected " ++ op, literal)
  }
}

// Ensure that the current token is TokNumber
fun expect-number( tokens : list<token> ) : <exn> (int, list<token>) {
  match (tokens) {
    Cons(Token(TokNumber, value = Just(value), literal = Just(_)), next-tokens) -> (value, next-tokens)
    Cons(Token(kind = _, value = _, literal = Just(literal)), _) -> error_at("expected a number", literal)
  }
}

fun at-eof( tokens : list<token> ) : bool {
  match (tokens) {
    Cons(Token(TokEof, value = _, literal = _), _) -> True
    Cons(_) -> False
    _ -> True
  }
}

// Tokenize input and returns tokens
fun tokenize( input : string ) : <div, exn> list<token> {
  var curr-pos := 0
  var num-tok-len := 0
  var num-tok-val := 0
  var tokens := Nil

  var rest-of-input := input.slice()
  while {
    match (rest-of-input.next()) {
      Just((c, s)) -> {
        // Integer literal
        if (c.is-digit()) {
          num-tok-val := num-tok-val * 10 + (c - '0').int()
          num-tok-len := num-tok-len + 1
        }
        elif (c == '+' || c == '-' || c == ' ') {
          if (num-tok-len > 0) {
            val tok-ltr = input.first(num-tok-len).advance(curr-pos - num-tok-len)
            val num-tok = Token(TokNumber, Just(num-tok-val), Just(tok-ltr))
            tokens := Cons(num-tok, tokens)
          }

          // Punctuator
          if (c == '-' || c == '+') {
            val tok-ltr = input.first(1).advance(curr-pos)
            val punc-tok = Token(TokReserved, literal = Just(tok-ltr))
            tokens := Cons(punc-tok, tokens)
          }

          num-tok-len := 0
          num-tok-val := 0
        }
        else {
          error_at("expected a number", input.last(input.count() - curr-pos))
        }

        rest-of-input := s
        curr-pos := curr-pos + 1

        True
      }

      _ -> {
        if (num-tok-len > 0) {
          val tok-ltr = input.first(num-tok-len).advance(curr-pos - num-tok-len)
          val num-tok = Token(TokNumber, Just(num-tok-val), Just(tok-ltr))
          tokens := Cons(num-tok, tokens)
        }

        val eof-tok = Token(kind = TokEof)
        tokens := Cons(eof-tok, tokens)

        False
      }
    }
  }
  {}

  tokens.reverse()
}

fun main() : <console, div, ndet> int {
    val input = match (get-argv()) {
        Cons(prog, args) -> {
            match (args) {
                Cons(input, Nil) -> input
                _ -> {
                    println(prog ++ ": invalid number of arguments")
                    return 1
                }
            }
        }
        _ -> return 1
    }

    println(".intel_syntax noprefix")
    println(".global main")
    println("main:")

    try {
        var tokens := tokenize(input)

        val (i, next-tokens) = expect-number(tokens)
        tokens := next-tokens
        println("  mov rax, " ++ i.show())

        while { !at-eof(tokens) } {
            val (is-add, next-tokens) = consume('+', tokens)
            tokens := next-tokens

            if (is-add) {
                val (i, next-tokens) = expect-number(tokens)
                tokens := next-tokens
                println("  add rax, " ++ i.show())
            }
            else {
                val next-tokens = expect('-', tokens)
                tokens := next-tokens

                val (i, next-tokens) = expect-number(tokens)
                tokens := next-tokens
                println("  sub rax, " ++ i.show())
            }
        }

        println("  ret")
    } fn (exn) { println(exn.message) }

    0
}
