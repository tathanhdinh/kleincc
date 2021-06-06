module parse

import support
import tokenize

// Local variable
public struct variable {
  name : string
  offset : maybe<int> = Nothing
}

// AST node
public type node-kind {
  NdAdd       // +
  NdSub       // -
  NdMul       // *
  NdDiv       // /
  NdEq        // ==
  NdNe        // !=
  NdLt        // <
  NdLe        // <=
  NdAssign    // =
  NdReturn    // "return"
  NdIf        // "if"
  NdWhile     // "while"
  NdFor       // "for"
  NdExprStmt  // expression statement
  NdVar       // variable
  NdNum       // Integer
}

// AST node type.
public struct node {
  kind : node-kind

  lhs : maybe<node> = Nothing
  rhs : maybe<node> = Nothing

  // "if", "while" or "for" statement
  wenn : maybe<node> = Nothing          // condition expression
  dann : maybe<node> = Nothing          // then statement
  sonst : maybe<node> = Nothing         // else statement
  init : maybe<node> = Nothing          // initial statement
  inc : maybe<node> = Nothing           // increment statement

  variable : maybe<variable> = Nothing  // used if kind is NdVar
  value : maybe<int> = Nothing          // used if kind is NdNum
}

// For debugging.
public fun show( n : node, indent : int = 0) : <div, console> string {
  val kind = match (n.kind) {
    NdAdd -> "+"
    NdSub -> "-"
    NdMul -> "*"
    NdDiv -> "/"
    NdEq -> "=="
    NdNe -> "!="
    NdLt -> "<"
    NdLe -> "<="
    NdAssign -> "assignment"
    NdReturn -> "return keyword"
    NdIf -> "if statement"
    NdWhile -> "while statement"
    NdFor -> "for statement"
    NdExprStmt -> "expression statement"
    NdVar -> "identifier"
    NdNum -> "integer"
  }

  val linke-seite = match (n.lhs) {
    Just(lhs) -> lhs.show(indent + " lhs : Node {".count())
    _ -> "nothing"
  }

  val rechte-seite = match (n.rhs) {
    Just(rhs) -> rhs.show(indent + " rhs : Node {".count())
    _ -> "nothing"
  }

  val value = match (n.value) {
    Just(v) -> v.show()
    _ -> "nothing"
  }

  val indent-str = " ".repeat(indent + "Node { ".count())
  val node-str = "Node { kind : " ++ kind ++ ",\n" ++
    indent-str ++       "lhs : " ++ linke-seite ++ ",\n" ++
    indent-str ++       "rhs : " ++ rechte-seite ++ ",\n" ++
    indent-str ++       "value : " ++ value ++ " }"
  node-str
}

public struct funktion {
  nodes : list<node>
  locals : list<variable>
  stack-size : int
}

private noinline val remained-tokens = unsafe-total { ref(Nil) }
private noinline val local-variables = unsafe-total { ref(Nil) }

fun find-variable( token : token ) : <read<global>> maybe<variable> {
  val vars = !local-variables
  vars.find(fn (v) {
    token.literal.maybe(
      onNothing = False,
      onJust = fn (l) { l.string() == v.name })
  })
}

// program = stmt*
public fun program( tokens : list<token> ) : <console, div, exn, read<global>, write<global>> funktion {
  fun parse( nodes ) {
    if (at-eof()) then nodes else parse(Cons(stmt(), nodes))
  }

  remained-tokens := tokens
  val nodes = parse(Nil)
  Funktion(nodes.reverse(), locals = (!local-variables).reverse(), stack-size = 0)
}

// stmt = "return" expr ";"
//      | "if" "(" expr ")" stmt ("else" stmt)?
//      | "while" "(" expr ")" stmt
//      | "for" "(" expr? ";" expr? ";" expr? ")" stmt
//      | expr ";"
fun stmt() : <console, div, exn, read<global>, write<global>> node {
  with control continue() {
    val lhs = expr()
    val node = Node(NdExprStmt, lhs = Just(lhs)); expect(";")
    node
  }

  // parse "for" statement
  with override control continue() {
    consume("for").unjust-or-continue(); expect("(")

    val init-stmt = consume(";").map(
      fn (_) { Nothing }
    ).unjust-or({
      val node = Node(NdExprStmt, lhs = Just(expr())); expect(";")
      Just(node)
    })

    val cond-expr = consume(";").map(
      fn (_) { Nothing }
    ).unjust-or({
      val node = expr(); expect(";")
      Just(node)
    })

    val inc-stmt = consume(")").map(
      fn (_) { Nothing }
    ).unjust-or({
      val node = Node(NdExprStmt, lhs = Just(expr())); expect(")")
      Just(node)
    })

    Node(NdFor, init = init-stmt, wenn = cond-expr, inc = inc-stmt, dann = Just(stmt()))
  }

  // parse "while" statement
  with override control continue() {
    consume("while").unjust-or-continue(); expect("(")
    val cond-expr = expr(); expect(")")
    Node(NdWhile, wenn = Just(cond-expr), dann = Just(stmt()))
  }

  // parse "if" statement
  with override control continue() {
    consume("if").unjust-or-continue(); expect("(")
    val cond-expr = expr(); expect(")")
    val then-stmt = stmt()
    val else-stmt = consume("else").map(fn (_) { stmt() })
    Node(NdIf, wenn = Just(cond-expr), dann = Just(then-stmt), sonst = else-stmt)
  }

  consume("return").unjust-or-continue()
  val node = Node(NdReturn, lhs = Just(expr())); expect(";")
  node
}

// expr = assign
fun expr( ) : <console, div, exn, read<global>, write<global>> node {
  match (!remained-tokens) {
    Cons(_) -> assign()
  }
}

// assign = equality ("=" assign)?
fun assign() : <console, div, exn, read<global>, write<global>> node {
  val lhs = equality()
  consume("=").maybe(
    onNothing = lhs,
    onJust = fn (_) {
      Node(kind = NdAssign, lhs = Just(lhs), rhs = Just(assign()))
    }
  )
}

// equality = relational ("==" relational | "!=" relational)
fun equality() : <console, div, exn, read<global>, write<global>> node {
  fun parse( lhs ) : <console, div, exn, read<global>, write<global>> node {
    fun consume-then-parse( rhs-literal, rhs-kind ) {
      consume(rhs-literal).unjust-or-continue()
      val node = Node(kind = rhs-kind, lhs = Just(lhs), rhs = Just(relational()))
      parse(node)
    }

    with control continue() { lhs }

    with override control continue() {
      consume-then-parse("!=", NdNe)
    }

    consume-then-parse("==", NdEq)
  }

  parse(relational())
}

// relational = add-or-sub ("<" add-or-sub | "<=" add-or-sub | ">" add | ">=" add)*
fun relational() : <console, div, exn, read<global>, write<global>> node {
  fun parse( node ) : <console, div, exn, read<global>, write<global>> node {
    fun consume-then-parse( literal, kind, switch ) {
      consume(literal).unjust-or-continue()
      val other-node = add-or-sub()
      val new-node = if switch then Node(kind, lhs = Just(other-node), rhs =  Just(node))
                               else Node(kind, lhs = Just(node), rhs = Just(other-node))
      parse(new-node)
    }

    with control continue() { node }

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

  parse(add-or-sub())
}

// add-or-sub = mul-or-div ("+" mul-or-div | "-" mul-or-div)*
fun add-or-sub() : <console, div, exn, read<global>, write<global>> node {
  fun parse( lhs ) : <console, div, exn, read<global>, write<global>> node {
    fun consume-then-parse( rhs-literal, rhs-kind ) {
      consume(rhs-literal).unjust-or-continue()
      val node = Node(kind = rhs-kind, lhs = Just(lhs), rhs = Just(mul-or-div()))
      parse(node)
    }

    with control continue() { lhs }

    with override control continue() {
      consume-then-parse("-", NdSub)
    }

    consume-then-parse("+", NdAdd)
  }

  parse(mul-or-div())
}

// mul-or-div = unary ('*' unary | '/' unary)
fun mul-or-div() : <console, div, exn, read<global>, write<global>> node {
  fun parse( lhs ) : <console, div, exn, read<global>, write<global>> node {
    fun consume-then-parse( rhs-literal, rhs-kind ) {
      consume(rhs-literal).unjust-or-continue()
      val node = Node(kind = rhs-kind, lhs = Just(lhs), rhs = Just(unary()))
      parse(node)
    }

    with control continue() { lhs }

    with override control continue() {
      consume-then-parse("/", NdDiv)
    }

    consume-then-parse("*", NdMul)
  }

  parse(unary())
}

// unary = ('+' | '-')? unary
//       | primary
fun unary ( ) : <console, div, exn, read<global>, write<global>> node {
  with control continue() {
    primary()
  }

  with override control continue() {
    consume("-").unjust-or-continue()
    Node(NdSub, lhs = Just(Node(NdNum, value = Just(0))), rhs = Just(unary()))
  }

  consume("+").unjust-or-continue()
  unary()
}

// primary = '(' expr ')' | ident | num
fun primary() : <console, div, exn, read<global>, write<global>> node {
  with control continue() {
    Node(NdNum, value = Just(expect-number()))
  }

  with override control continue() {
    val token = consume-ident().unjust-or-continue()
    val new-or-existing-var = try { find-variable(token).unjust } fn (_) {
      val v = Variable(name = token.literal.unjust().string())
      local-variables := Cons(v, !local-variables)
      v
    }

    Node(NdVar, variable = Just(new-or-existing-var))
  }

  consume("(").unjust-or-continue()
  val node = expr(); expect(")")
  node
}

// Consume the current token if it matches `op`.
fun consume( op : string ) : <console> maybe<()> {
  match (!remained-tokens) {
    Cons(Token(TokReserved, literal = Just(literal)), tokens) ->
      if (op == literal.string())
      then {
        remained-tokens := tokens
        Just(())
      }
      else Nothing

    _ -> Nothing
  }
}

// Consume the current token if it is an identifier
fun consume-ident() : <console> maybe<token> {
  try {
    match (!remained-tokens) {
      Cons(token, tokens) -> {
        match (token) {
          Token(TokIdent) -> {
            remained-tokens := tokens
            Just(token)
          }
        }
      }
    }
  } fn (_) { Nothing }
}

// Ensure that the current token is TokNumber.
fun expect-number() : <exn> int {
  match (!remained-tokens) {
    Cons(Token(TokNumber, value = Just(num), literal = Just(_)), tokens) -> {
      remained-tokens := tokens
      num
    }

    Cons(Token(literal = Just(literal))) -> error-at(literal, "expected a number")
  }
}

// Ensure that the current token is `op`.
fun expect( op : string ) : <exn> () {
  match (!remained-tokens) {
    Cons(Token(TokReserved, literal = Just(literal)), tokens) ->
        if (op == literal.string())
        then remained-tokens := tokens
        else error-at(literal, "expected " ++ op)

    Cons(Token(literal = Just(literal))) -> error-at(literal, "expected " ++ op)
  }
}

fun at-eof() : bool {
  match (!remained-tokens) {
    Cons(Token(TokEof)) -> True

    Cons(_) -> False

    _ -> True
  }
}
