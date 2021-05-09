import std/os/env

effect control continue<a>() : a

fun unjust-or-continue( m : maybe<a> ) : continue a {
  match (m) {
    Just(v) -> v
    _ -> continue()
  }
}

// Reports an error
fun error( msg : string ) : exn a {
  throw("error: " ++ msg)
}

// Report an error with location information.
fun error-at( literal : sslice, msg : string ) : exn a {
  val before-ltr = literal.before()
  val input = before-ltr.before().after()
  val error-msg = input.string() ++ "\n" ++ " ".repeat(before-ltr.count()) ++ "^ error: " ++ msg
  throw(error-msg)
}

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

// Consume the current token if it matches `op`
fun consume( op : string, tokens : list<token> ) : <console> maybe<list<token>> {
  match (tokens) {
    Cons(Token(TokReserved, literal = Just(literal), value = _), next-tokens) -> {
      if (op == literal.string()) then Just(next-tokens) else Nothing
    }
    _ -> Nothing
  }
}

// Ensure that the current token is `op`
fun expect( op : string, tokens : list<token> ) : <exn> list<token> {
  match (tokens) {
    Cons(Token(TokReserved, literal = Just(literal), value = _), next-tokens) ->
        if (op == literal.string()) then next-tokens else error-at(literal, "expected " ++ op)
    Cons(Token(kind = _, literal = Just(literal), value = _), _) -> error-at(literal, "expected " ++ op)
  }
}

// Ensure that the current token is TokNumber
fun expect-number( tokens : list<token> ) : <exn> (int, list<token>) {
  match (tokens) {
    Cons(Token(TokNumber, value = Just(num), literal = Just(_)), next-tokens) -> (num, next-tokens)
    Cons(Token(kind = _, value = _, literal = Just(literal)), _) -> error-at(literal, "expected a number")
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
fun tokenize( input : string ) : <console, div, exn> list<token> {
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

//
// Parser
//

type node-kind {
  NdAdd    // +
  NdSub    // -
  NdMul    // *
  NdDiv    // /
  NdEq     // ==
  NdNe     // !=
  NdLt     // <
  NdLe     // <=
  NdNum    // Integer
}

// AST node type
struct node {
  kind : node-kind
  lhs : maybe<node> = Nothing
  rhs : maybe<node> = Nothing
  value : maybe<int> = Nothing
}

fun show( n : node ) : <div, console> string {
  val kind = match (n.kind) {
    NdAdd -> "+"
    NdSub -> "-"
    NdMul -> "*"
    NdDiv -> "/"
    NdEq -> "=="
    NdNe -> "!="
    NdLt -> "<"
    NdLe -> "<="
    NdNum -> "Integer"
  }

  val lhs = match (n.lhs) {
    Just(lhs) -> lhs.show()
    _ -> "Nothing"
  }

  val rhs = match (n.rhs) {
    Just(rhs) -> rhs.show()
    _ -> "Nothing"
  }

  val value = match (n.value) {
    Just(n) -> n.show()
    _ -> "Nothing"
  }

  "Node { kind : " ++ kind ++ ", lhs : " ++ lhs ++ ", rhs : " ++ rhs ++ ", value : " ++ value ++ " }"
}

val equality = expr

// equality = relational ("==" relational | "!=" relational)
fun expr( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
  fun parse( node, tokens ) : <console, div, exn> (node, list<token>){
    fun consume-then-parse( rhs-literal, rhs-kind ) {
      val rhs-tokens = consume(rhs-literal, tokens).unjust-or-continue()
      val (rhs, tokens) = relational(rhs-tokens)
      val node = Node(kind = rhs-kind, lhs = Just(node), rhs = Just(rhs))
      parse(node, tokens)
    }

    with control continue() {
      (node, tokens)
    }

    with override control continue() {
      consume-then-parse("!=", NdNe)
    }

    consume-then-parse("==", NdEq)
  }

  val (lhs, rhs-tokens) = relational(tokens)
  parse(lhs, rhs-tokens)
}

// relational = add-or-sub ("<" add-or-sub | "<=" add-or-sub | ">" add | ">=" add)*
fun relational( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
  fun parse( node, tokens ) : <console, div, exn> (node, list<token>) {
    fun consume-then-parse( literal, kind, switch ) {
      val tokens = consume(literal, tokens).unjust-or-continue()
      val (new-node, tokens) = add-or-sub(tokens)
      val node = if switch then Node(kind, lhs = Just(new-node), rhs =  Just(node))
                           else Node(kind, lhs = Just(node), rhs = Just(new-node))
      parse(node, tokens)
    }

    with control continue() {
      (node, tokens)
    }

    with override control continue() {
      consume-then-parse(">=", NdLe, True)
    }

    with override control continue() {
      consume-then-parse(">", NdLt, True)
    }

    with override control continue() {
      consume-then-parse("<=", NdLe, False)
    }

    consume-then-parse("<", NdLt, False)
  }

  val (node, tokens) = add-or-sub(tokens)
  parse(node, tokens)
}

// add-or-sub = mul-or-div ("+" mul-or-div | "-" mul-or-div)*
fun add-or-sub( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
  fun parse( node, tokens ) : <console, div, exn> (node, list<token>) {
    fun consume-then-parse( rhs-literal, rhs-kind ) {
      val rhs-tokens = consume(rhs-literal, tokens).unjust-or-continue()
      val (rhs, tokens) = mul-or-div(rhs-tokens)
      val node = Node(kind = rhs-kind, lhs = Just(node), rhs = Just(rhs))
      parse(node, tokens)
    }

    with control continue() {
      (node, tokens)
    }

    with override control continue() {
      consume-then-parse("-", NdSub)
    }

    consume-then-parse("+", NdAdd)
  }

  val (node, tokens) = mul-or-div(tokens)
  parse(node, tokens)
}

// mul-or-div = unary ('*' unary | '/' unary)
fun mul-or-div( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
  fun parse( node, tokens ) : <console, div, exn> (node, list<token>) {
    fun consume-then-parse( rhs-literal, rhs-kind ) {
      val rhs-tokens = consume(rhs-literal, tokens).unjust-or-continue()
      val (rhs, tokens) = unary(rhs-tokens)
      val node = Node(kind = rhs-kind, lhs = Just(node), rhs = Just(rhs))
      parse(node, tokens)
    }

    with control continue() {
      (node, tokens)
    }

    with override control continue() {
      consume-then-parse("/", NdDiv)
    }

    consume-then-parse("*", NdMul)
  }

  val (lhs, rhs-tokens) = unary(tokens)
  parse(lhs, rhs-tokens)
}

// unary = ('+' | '-')? unary
//       | primary
fun unary ( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
  with control continue() {
    primary(tokens)
  }

  with override control continue() {
    val rhs-tokens = consume("-", tokens).unjust-or-continue()
    val (rhs, tokens) = unary(rhs-tokens)
    val node = Node(NdSub, lhs = Just(Node(NdNum, value = Just(0))), rhs = Just(rhs))
    (node, tokens)
  }

  val tokens = consume("+", tokens).unjust-or-continue()
  unary(tokens)
}

// primary = '(' expr ')' | num
fun primary( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
  with control continue() {
    val (num, tokens) = expect-number(tokens)
    val node = Node(NdNum, value = Just(num))
    (node, tokens)
  }

  val tokens = consume("(", tokens).unjust-or-continue()
  val (node, tokens) = expr(tokens)
  (node, expect(")", tokens))
}

//
// Code generator
//

fun gen( nd : node ) : <console, div> () {
  match (nd) {
    Node(NdNum, value = Just(value)) -> println("  push " ++ value.show())
    Node(kind, lhs = Just(lhs), rhs = Just(rhs)) -> {
      gen(lhs)
      gen(rhs)

      println(
        "  pop rdi\n" ++ // rhs
        "  pop rax"    // lhs
      ); // rhs

      match (kind) {
        NdAdd -> println(
          "  add rax, rdi"
        )
        NdSub -> println(
          "  sub rax, rdi"
        )
        NdMul -> println(
          "  imul rax, rdi"
        )
        NdDiv -> println(
          "  cqo\n" ++
          "  idiv rdi"
        )
        NdEq -> println(
          "  cmp rax, rdi\n" ++
          "  sete al\n" ++
          "  movzx rax, al"
        )
        NdNe -> println(
          "  cmp rax, rdi\n" ++
          "  setne al\n" ++
          "  movzx rax, al"
        )
        NdLt -> println(
          "  cmp rax, rdi\n" ++
          "  setl al\n" ++
          "  movzx rax, al"
        )
        NdLe -> println(
          "  cmp rax, rdi\n" ++
          "  setle al\n" ++
          "  movzx rax, al"
        )
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
      println(
        "global main\n" ++
        "section .smc write exec\n" ++
        "main:"
      )

      // Traverse the AST to emit assembly.
      gen(node)

      // The result is at the top of the stack,
      // so pop it to RAX to make it the program exit code
      println(
        "  pop rax\n" ++
        "  ret"
      )
    } fn (exn) { println(exn.message) }

    0
}
