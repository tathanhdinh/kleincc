module parse

import kleincc
import tokenize
import typen

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

/* ----------------------------------------------------------------------------
  program = function*
---------------------------------------------------------------------------- */
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

/* ----------------------------------------------------------------------------
  function = ident "(" params? ")" "{" stmt* "}"
  params   = ident ("," ident)*
---------------------------------------------------------------------------- */
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

fun stmt() : zerteilen node {
  val node = untyped-stmt()
  add-type(node)
}

/* ----------------------------------------------------------------------------
  stmt = "return" expr ";"
      | "if" "(" expr ")" stmt ("else" stmt)?
      | "while" "(" expr ")" stmt
      | "for" "(" expr? ";" expr? ";" expr? ")" stmt
      | "{" stmt* "}"
      | expr ";"
---------------------------------------------------------------------------- */
fun untyped-stmt() : zerteilen node {
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

    val init-stmt = if (consume(";").bool()) then Nothing else {
      val node = Node(NdExprStmt, lhs = Just(expr())); expect(";")
      Just(node)
    }

    val cond-expr = if (consume(";").bool()) then Nothing else {
      val node = expr();
      expect(";")
      Just(node)
    }

    val inc-stmt = if (consume(")").bool()) then Nothing else {
      val node = Node(NdExprStmt, lhs = Just(expr())); expect(")")
      Just(node)
    }

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

/* ----------------------------------------------------------------------------
  expr = assign
---------------------------------------------------------------------------- */
fun expr( ) : zerteilen node {
  match (!remained-tokens) {
    Cons(_) -> assign()
  }
}

/* ----------------------------------------------------------------------------
  assign = equality ("=" assign)?
---------------------------------------------------------------------------- */
fun assign() : zerteilen node {
  val lhs = equality()
  if (consume("=").bool())
  then Node(NdAssign, lhs = Just(lhs), rhs = Just(assign()))
  else lhs
}

/* ----------------------------------------------------------------------------
  equality = relational ("==" relational | "!=" relational)
---------------------------------------------------------------------------- */
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

/* ----------------------------------------------------------------------------
  relational = add-or-sub ("<" add-or-sub | "<=" add-or-sub | ">" add | ">=" add)*
---------------------------------------------------------------------------- */
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

fun typed-add( lhs : node, rhs : node, token : token ) : zerteilen node {
  val (typed-lhs, typed-rhs) = (add-type(lhs), add-type(rhs))
  val linke-typ = typed-lhs.ty.unjust()
  val rechte-typ = typed-rhs.ty.unjust()

  // linke und sechte Seite sind Integer
  if (is-integer(linke-typ) && is-integer(rechte-typ))
  then Node(NdAdd, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // linke Seite ist ein Zeiger, sechte Seite ist eine Integer
  elif (linke-typ.base.bool() && is-integer(rechte-typ))
  then Node(NdPtrAdd, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // linke Seite ist ein Integer, sechte Seite ist ein Zeiger
  elif (is-integer(linke-typ) && rechte-typ.base.bool())
  then Node(NdPtrDiff, token, lhs = Just(typed-rhs), rhs = Just(typed-rhs))
  // sonst
  else error-token(token, "invalid operands")
}

fun typed-sub( lhs : node, rhs : node, token : token ) : zerteilen node {
  val (typed-lhs, typed-rhs) = (add-type(lhs), add-type(rhs))
  val linke-typ = typed-lhs.ty.unjust()
  val rechte-typ = typed-rhs.ty.unjust()

  // linke und sechte Seite sind Integern
  if (is-integer(linke-typ) && is-integer(rechte-typ))
  then Node(NdSub, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // linke Seite est ein Zeiger, sechte Seite est ein Integer
  elif (linke-typ.base.bool() && is-integer(rechte-typ))
  then Node(NdPtrSub, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // linke und sechte Seite sind Zeigern
  elif (linke-typ.base.bool() && rechte-typ.base.bool())
  then Node(NdPtrDiff, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // sonst
  else error-token(token, "invalid operands")
}

/* ----------------------------------------------------------------------------
  add-or-sub = mul-or-div ("+" mul-or-div | "-" mul-or-div)*
---------------------------------------------------------------------------- */
fun add-or-sub() : zerteilen node {
  fun parse ( lhs ) : zerteilen node {
    match (consume("+")) {
      Just(token) -> parse(typed-add(lhs, mul-or-div(), token))

      _ -> consume("-").maybe(
        onNothing = lhs,
        onJust = fn (token) { parse(typed-sub(lhs, mul-or-div(), token)) }
      )
    }
  }
  parse(mul-or-div())
}

/* ----------------------------------------------------------------------------
  mul-or-div = unary ('*' unary | '/' unary)
---------------------------------------------------------------------------- */
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

/* ----------------------------------------------------------------------------
  unary = ('+' | '-' | '*' | '&')? unary
        | primary
---------------------------------------------------------------------------- */
fun unary ( ) : zerteilen node {
  if (consume("+").bool())
  then unary()
  elif (consume("-").bool())
  then Node(NdSub, lhs = Just(Node(NdNum, value = Just(0))), rhs = Just(unary()))
  elif (consume("*").bool())
  then Node(NdDeref, lhs = Just(unary()))
  elif (consume("&").bool())
  then Node(NdAddr, lhs = Just(unary()))
  else primary()
}

/* ----------------------------------------------------------------------------
  func-args = "(" (assign (",", assign)*)? ")"
---------------------------------------------------------------------------- */
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

/* ----------------------------------------------------------------------------
primary = '(' expr ')' | ident func-args? | num
---------------------------------------------------------------------------- */
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
