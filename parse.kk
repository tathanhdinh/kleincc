module parse

import tokenize

effect control continue<a>() : a

fun unjust-or-continue( m : maybe<a> ) : continue a {
  match (m) {
    Just(v) -> v
    _ -> continue()
  }
}

public type node-kind {
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
public struct node {
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

// program = stmt*
public fun program( tokens : list<token> ) : <console, div, exn> list<node> {
  fun parse( tokens, nodes ) {
    if (at-eof(tokens)) then nodes
    else {
      val (node, tokens) = stmt(tokens)
      parse(tokens, Cons(node, nodes))
    }
  }

  val nodes = parse(tokens, Nil)
  nodes.reverse()
}

// stmt = expr ";"
fun stmt( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
  val (node, tokens) = expr(tokens)
  val tokens = expect(";", tokens)
  (node, tokens)
}

// expr = equality
fun expr( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
  match (tokens) {
    Cons(_) -> equality(tokens)
  }
}

// equality = relational ("==" relational | "!=" relational)
fun equality( tokens : list<token> ) : <console, div, exn> (node, list<token>) {
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

// Consume the current token if it matches `op`
fun consume( op : string, tokens : list<token> ) : <console> maybe<list<token>> {
  match (tokens) {
    Cons(Token(TokReserved, literal = Just(literal), value = _), next-tokens) ->
      if (op == literal.string()) then Just(next-tokens) else Nothing

    _ -> Nothing
  }
}

// Ensure that the current token is TokNumber
fun expect-number( tokens : list<token> ) : <exn> (int, list<token>) {
  match (tokens) {
    Cons(Token(TokNumber, value = Just(num), literal = Just(_)), next-tokens) -> (num, next-tokens)
    Cons(Token(kind = _, value = _, literal = Just(literal)), _) -> error-at(literal, "expected a number")
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

fun at-eof( tokens : list<token> ) : bool {
  match (tokens) {
    Cons(Token(TokEof, value = _, literal = _), _) -> True
    Cons(_) -> False
    _ -> True
  }
}
