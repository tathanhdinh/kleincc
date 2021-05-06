import std/os/env

//
// Tokenizer
//

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
fun error-at( msg : string, optional-literal : ?sslice ) : exn a {
  val error-msg = match (optional-literal) {
    None -> "error: " ++ msg
    Optional(literal) -> {
      val before-ltr = literal.before()
      val input = before-ltr.before().after() // before of before is an empty, after this empty is the slice of the entire string
      input.string() ++ "\n" ++ " ".repeat(before-ltr.count()) ++ "^ error: " ++ msg
    }
  }

  throw(error-msg)
}

// Consume the current token if it maches `op`
fun consume( op : char, tokens : list<token> ) : maybe<list<token>> {
  match (tokens) {
    Cons(Token(TokReserved, literal = Just(literal), value = _), next-tokens) ->
      if (op.string() == literal.string()) then Just(next-tokens) else Nothing
    _ -> Nothing
  }
}

// Ensure that the current token is `op`
fun expect( op : char, tokens : list<token> ) : <exn> list<token> {
  val op-str = op.string()
  match (tokens) {
    Cons(Token(TokReserved, literal = Just(literal), value = _), next-tokens) ->
        if (op-str == literal.string()) then next-tokens else error-at("expected " ++ op-str, literal)
    Cons(Token(kind = _, literal = Just(literal), value = _), _) -> error-at("expected " ++ op-str, literal)
  }
}

// Ensure that the current token is TokNumber
fun expect-number( tokens : list<token> ) : <exn> (int, list<token>) {
  match (tokens) {
    Cons(Token(TokNumber, value = Just(num), literal = Just(_)), next-tokens) -> (num, next-tokens)
    Cons(Token(kind = _, value = _, literal = Just(literal)), _) -> error-at("expected a number", literal)
  }
}

fun at-eof( tokens : list<token> ) : bool {
  match (tokens) {
    Cons(Token(TokEof, value = _, literal = _), _) -> True
    Cons(_) -> False
    _ -> True
  }
}

fun is-punct( c : char ) : bool {
  c== '+' || c == '-' || c == '*' || c == '/' || c == '(' || c == ')'
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
        elif (c.is-punct() || c.is-white()) {
          if (num-tok-len > 0) {
            val tok-ltr = input.first(num-tok-len).advance(curr-pos - num-tok-len)
            val num-tok = Token(TokNumber, Just(num-tok-val), Just(tok-ltr))
            tokens := Cons(num-tok, tokens)
          }

          // Punctuator
          if (c.is-punct()) {
            val tok-ltr = input.first(1).advance(curr-pos)
            val punc-tok = Token(TokReserved, literal = Just(tok-ltr))
            tokens := Cons(punc-tok, tokens)
          }

          num-tok-len := 0
          num-tok-val := 0
        }
        else {
          error-at("invalid token", input.last(input.count() - curr-pos))
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

//
// Parser
//

type node-kind {
  NdAdd
  NdSub
  NdMul
  NdDiv
  NdNum
}

// AST node type
struct node {
  kind : node-kind
  lhs : maybe<node> = Nothing
  rhs : maybe<node> = Nothing
  value : maybe<int> = Nothing
}

// expr = mul-or-div ('+' mul-or-div | '-' mul-or-div)
fun expr( tokens : list<token> ) : <div, exn, console> (node, list<token>) {
  val (lhs-md-node, tmp-tokens) = mul-or-div(tokens)
  var next-tokens := tmp-tokens
  var new-node := lhs-md-node

  var neither-add-nor-sub := False
  while { !neither-add-nor-sub && !at-eof(next-tokens) } {
    match (consume('+', next-tokens)) {
      Just(toks) -> {
        val (rhs-md-node, toks) = mul-or-div(toks)
        next-tokens := toks
        new-node := Node(NdAdd, lhs = Just(new-node), rhs = Just(rhs-md-node))
      }

      _ -> match (consume('-', next-tokens)) {
        Just(toks) -> {
          val (rhs-md-node, toks) = mul-or-div(toks)
          next-tokens := toks
          new-node := Node(NdSub, lhs = Just(new-node), rhs = Just(rhs-md-node))
        }

        _ -> neither-add-nor-sub := True
      }
    }
  }

  (new-node, next-tokens)
}

// mul-or-div = primary ('*' primary | '/' primary)
fun mul-or-div( tokens : list<token> ) : <div, exn, console> (node, list<token>) {
  val (lhs-prim-node, toks) = primary(tokens)
  var next-tokens := toks
  var new-node := lhs-prim-node

  var neither-mul-nor-div := False
  while { !neither-mul-nor-div && !at-eof(next-tokens) } {
    match (consume('*', next-tokens)) {
      Just(toks) -> {
        val (rhs-prim-node, toks) = primary(toks)
        next-tokens := toks
        new-node := Node(NdMul, lhs = Just(new-node), rhs = Just(rhs-prim-node))
      }

      _ -> match (consume('/', next-tokens)) {
        Just(toks) -> {
          val (rhs-prim-node, toks) = primary(toks)
          next-tokens := toks
          new-node := Node(NdDiv, lhs = Just(new-node), rhs = Just(rhs-prim-node))
        }

        _ -> neither-mul-nor-div := True
      }
    }
  }

  (new-node, next-tokens)
}

// primary = '(' expr ')' | num
fun primary( tokens : list<token> ) : <div, exn, console> (node, list<token>) {
  match (consume('(', tokens)) {
    Just(toks) -> {
      val (expr-node, toks) = expr(toks)
      (expr-node, expect(')', toks))
    }

    _ -> {
      val (num, toks) = expect-number(tokens)
      val num-node = Node(NdNum, value = Just(num))
      (num-node, toks)
    }
  }
}

//
// Code generator
//

fun gen( nd : node ) : <console> () {
  match (nd) {
    Node(NdNum, value = Just(value)) -> println("  push " ++ value.show())
    Node(kind, lhs = Just(lhs), rhs = Just(rhs)) -> {
      gen(lhs)
      gen(rhs)

      println("  pop rdi"); // rhs
      println("  pop rax"); // lhs

      match (kind) {
        NdAdd -> println("  add rax, rdi")
        NdSub -> println("  sub rax, rdi")
        NdMul -> println("  imul rax, rdi")
        NdDiv -> {
          println("  cqo")
          println("  idiv rdi")
        }
        _ -> ()
      }

      println("  push rax") // store the result
    }
    _ -> ()
  }
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

    try {
      // Tokenize and parse.
      val tokens = tokenize(input)
      val (node, _) = expr(tokens)

      // Print out the first half of assembly.
      println(".intel_syntax noprefix")
      println(".global main")
      println("main:")

      // Traverse the AST to emit assembly.
      gen(node)

      // The result is at the top of the stack,
      // so pop it to RAX to make it the program exit code
      println("  pop rax")
      println("  ret")
    } fn (exn) { println(exn.message) }

    0
}
