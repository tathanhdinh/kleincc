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
  NdFunCall   // function call
  NdExprStmt  // expression statement
  NdVar       // variable
  NdNum       // Integer
}

// AST node type.
public struct node {
  kind : node-kind
  token : token = unsafe-total { (!last-consumed-token).unjust() }

  lhs : maybe<node> = Nothing
  rhs : maybe<node> = Nothing

  // "if", "while" or "for"
  wenn : maybe<node> = Nothing                // condition expression
  dann : maybe<node> = Nothing                // then statement
  sonst : maybe<node> = Nothing               // else statement
  init : maybe<node> = Nothing                // initial statement
  inc : maybe<node> = Nothing                 // increment statement

  body: maybe<list<node>> = Nothing           // statement block

  fcname : maybe<string> = Nothing            // function call
  fcargs : maybe<list<node>> = Nothing        // function call arguments (I want to distinguish
                                              // Nothing from Nil: Nothing is used when the node
                                              // is not a function call, Nil is used when the node
                                              // is a function call, but with no argument)

  variable : maybe<variable> = Nothing        // used if kind is NdVar
  value : maybe<int> = Nothing                // used if kind is NdNum
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
    NdFunCall -> "function call"
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
  name : string
  params : list<variable>
  nodes : list<node>
  locals : list<variable>
  stacksize : int = 0
}

public noinline val local-vars : ref<global, list<variable>> = unsafe-total { ref(Nil) }
public noinline val defined-func-names : ref<global, list<string>> = unsafe-total { ref(Nil) }
public noinline val used-func-names : ref<global, list<string>> = unsafe-total { ref(Nil) }

alias zerteilen = <console, div, exn, read<global>, write<global>>

fun find-variable( token : token ) : <read<global>> maybe<variable> {
  (!local-vars).find(fn (v) {
    token.literal.maybe(
      onNothing = False,
      onJust = fn (l) { l.string() == v.name })
  })
}

/*
 program = function*
 */
public fun program( tokens : list<token> ) : zerteilen list<funktion> {
  remained-tokens := tokens

  var funktionen := Nil
  while { !at-eof() } {
    funktionen := Cons(eine-funktion(), funktionen)
  }
  funktionen.reverse()
}

fun func-params() : zerteilen list<variable> {
  if (consume(")").bool())
  then Nil
  else {
    var params := [Variable(expect-ident().string())]
    while { !consume(")").bool() } {
      expect(",")
      val param = Variable(expect-ident().string())
      params := Cons(param, params)
      local-vars := Cons(param, !local-vars)
    }
    params
  }
}

/*
function = ident "(" params? ")" "{" stmt* "}"
params   = ident ("," ident)*
*/
fun eine-funktion() : zerteilen funktion {
  // reset local variables
  local-vars := Nil

  val name = expect-ident().string(); expect("(")
  val params = func-params(); expect("{")

  var stmts := Nil
  while { !consume("}").bool() } {
    stmts := Cons(stmt(), stmts)
  }

  defined-func-names := Cons(name, !defined-func-names)
  Funktion(name, params, stmts.reverse(), !local-vars)
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
    val node = Node(NdReturn, lhs = Just(expr()))
    expect(";")
    node
  }

  // "if" statement
  elif (consume("if").bool()) {
    val token = (!last-consumed-token).unjust()

    expect("(")
    val cond-expr = expr()
    expect(")")

    val then-stmt = stmt()
    val else-stmt = consume("else").map(fn (_) { stmt() })

    Node(NdIf, token, wenn = Just(cond-expr), dann = Just(then-stmt), sonst = else-stmt)
  }

  // "while" statement
  elif (consume("while").bool()) {
    val token = (!last-consumed-token).unjust()

    expect("(")
    val cond-expr = expr()
    expect(")")

    Node(NdWhile, token, wenn = Just(cond-expr), dann = Just(stmt()))
  }

  // "for" statement
  elif (consume("for").bool()) {
    val token = (!last-consumed-token).unjust()

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

    Node(NdFor, token, init = init-stmt, wenn = cond-expr, inc = inc-stmt, dann = Just(stmt()))
  }

  // parse block "{" ... "}" statement
  elif (consume("{").bool()) {
    val token = (!last-consumed-token).unjust()

    var stmts := Nil
    while { !consume("}").bool() } {
      stmts := Cons(stmt(), stmts)
    }
    stmts := stmts.reverse()

    Node(NdBlock, token, body = Just(stmts))
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
fun relational() : zerteilen node {
  fun parse( node ) : zerteilen node {
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
  fun parse ( lhs ) : zerteilen node {
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
func-args = "(" (assign (",", assign)*)? ")"
*/
fun func-args() : zerteilen list<node> {
  if (consume(")").bool())
  then Nil
  else {
    var args := [assign()]
    while { consume(",").bool() } {
      args := Cons(assign(), args)
    }
    expect(")"); args := args.reverse()
    args
  }
}

/*
primary = '(' expr ')' | ident func-args? | num
*/
fun primary() : zerteilen node {
  if (consume("(").bool())
  then {
    val node = expr(); expect(")")
    node
  }
  else {
    match (consume-ident()) {
      Just(token) -> {
        if (consume("(").bool())
        // Function call
        then {
          val fcname = token.literal.unjust().string()

          if (!(!used-func-names).find(fn (name) { name == fcname}).bool())
          then used-func-names := Cons(fcname, !used-func-names)

          Node(NdFunCall, token, fcname = Just(fcname), fcargs = Just(func-args()))
        }
        // Variable
        else {
          val a-var = try { find-variable(token).unjust } fn (_) {
            val v = Variable(name = token.literal.unjust().string())
            local-vars := Cons(v, !local-vars)
            v
          }
          Node(NdVar, variable = Just(a-var))
        }
      }

      _ -> Node(NdNum, value = Just(expect-number()))
    }
  }
}
