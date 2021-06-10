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
  NdBlock     // { ... }
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

  // block
  body: maybe<list<node>> = Nothing     // statement block

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
    NdBlock -> "block statement"
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

alias zerteilen = <console, div, exn, read<global>, write<global>>

fun find-variable( token : token ) : <read<global>> maybe<variable> {
  val vars = !local-variables
  vars.find(fn (v) {
    token.literal.maybe(
      onNothing = False,
      onJust = fn (l) { l.string() == v.name })
  })
}

/*
 program = stmt*
 */
public fun program( tokens : list<token> ) : zerteilen funktion {
  fun parse( nodes ) {
    if (at-eof()) then nodes else parse(Cons(stmt(), nodes))
  }

  remained-tokens := tokens
  val nodes = parse(Nil)
  Funktion(nodes.reverse(), locals = (!local-variables).reverse(), stack-size = 0)
}

/*
stmt = "return" expr ";"
     | "if" "(" expr ")" stmt ("else" stmt)?
     | "while" "(" expr ")" stmt
     | "for" "(" expr? ";" expr? ";" expr? ")" stmt
     | "{" stmt* "}"
     | expr ";"
*/
fun stmt() : <console, div, exn, read<global>, write<global>> node {
  // "return" statement
  if (consume("return").bool()) {
    val node = Node(NdReturn, lhs = Just(expr())); expect(";")
    node
  }

  // "if" statement
  elif (consume("if").bool()) {
    expect("(")
    val cond-expr = expr()
    expect(")")
    val then-stmt = stmt()
    val else-stmt = consume("else").map(fn (_) { stmt() })
    Node(NdIf, wenn = Just(cond-expr), dann = Just(then-stmt), sonst = else-stmt)
  }

  // "while" statement
  elif (consume("while").bool()) {
    expect("(")
    val cond-expr = expr();
    expect(")")
    Node(NdWhile, wenn = Just(cond-expr), dann = Just(stmt()))
  }

  // "for" statement
  elif (consume("for").bool()) {
    expect("(")

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

  // parse block "{" ... "}" statement
  elif (consume("{").bool()) {
    var stmts := Nil
    while { !consume("}").bool() } {
      stmts := Cons(stmt(), stmts)
    }
    stmts := stmts.reverse()

    Node(NdBlock, body = Just(stmts))
  }

  // parse expression
  else {
    val node = Node(NdExprStmt, lhs = Just(expr()));
    expect(";")
    node
  }
}

/*
expr = assign
*/
fun expr( ) : zerteilen node {
  match (!remained-tokens) {
    Cons(_) -> assign()
  }
}

/*
assign = equality ("=" assign)?
*/
fun assign() : zerteilen node {
  val lhs = equality()
  if (consume("=").bool())
  then Node(NdAssign, lhs = Just(lhs), rhs = Just(assign()))
  else lhs
}

/*
equality = relational ("==" relational | "!=" relational)
*/
fun equality() : zerteilen node {
  fun parse( lhs ) {
    if (consume("==").bool())
    then parse(Node(NdEq, lhs = Just(lhs), rhs = Just(relational())))
    elif (consume("!=").bool())
    then parse(Node(NdNe, lhs = Just(lhs), rhs = Just(relational())))
    else lhs
  }
  parse(relational())
}

/*
relational = add-or-sub ("<" add-or-sub | "<=" add-or-sub | ">" add | ">=" add)*
*/
fun relational() : <console, div, exn, read<global>, write<global>> node {
  fun parse( node ) {
    if (consume("<").bool())
    then parse(Node(NdLt, lhs = Just(node), rhs = Just(add-or-sub())))
    elif (consume("<=").bool())
    then parse(Node(NdLe, lhs = Just(node), rhs = Just(add-or-sub())))
    elif (consume(">").bool())
    then parse(Node(NdLt, lhs = Just(add-or-sub()), rhs = Just(node)))
    elif (consume(">=").bool())
    then parse(Node(NdLe, lhs = Just(add-or-sub()), rhs = Just(node)))
    else node
  }
  parse(add-or-sub())
}

/*
add-or-sub = mul-or-div ("+" mul-or-div | "-" mul-or-div)*
*/
fun add-or-sub() : zerteilen node {
  fun parse ( lhs ) {
    if (consume("+").bool())
    then parse(Node(NdAdd, lhs = Just(lhs), rhs = Just(mul-or-div())))
    elif (consume("-").bool())
    then parse(Node(NdSub, lhs = Just(lhs), rhs = Just(mul-or-div())))
    else lhs
  }
  parse(mul-or-div())
}

/*
mul-or-div = unary ('*' unary | '/' unary)
*/
fun mul-or-div() : zerteilen node {
  fun parse( lhs ) : zerteilen node {
    if (consume("*").bool())
    then parse(Node(NdMul, lhs = Just(lhs), rhs = Just(unary())))
    elif (consume("/").bool())
    then parse(Node(NdDiv, lhs = Just(lhs), rhs = Just(unary())))
    else lhs
  }
  parse(unary())
}

/*
unary = ('+' | '-')? unary
      | primary
*/
fun unary ( ) : zerteilen node {
  if (consume("+").bool())
  then unary()
  elif (consume("-").bool())
  then Node(NdSub, lhs = Just(Node(NdNum, value = Just(0))), rhs = Just(unary()))
  else primary()
}

/*
primary = '(' expr ')' | ident | num
*/
fun primary() : zerteilen node {
  if (consume("(").bool())
  then {
    val node = expr()
    expect(")")
    node
  }
  else {
    match (consume-ident()) {
      Just(token) -> {
        val a-var = try { find-variable(token).unjust } fn (_) {
          val v = Variable(name = token.literal.unjust().string())
          local-variables := Cons(v, !local-variables)
          v
        }
        Node(NdVar, variable = Just(a-var))
      }

      _ -> Node(NdNum, value = Just(expect-number()))
    }
  }
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
