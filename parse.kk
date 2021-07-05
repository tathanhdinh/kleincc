module parse

import kleincc
import tokenize
import typen

/* ==============================================================================================
  Types, globals, etc.
============================================================================================== */
public struct funktion {
  name : string
  params : list<ref-variable>
  nodes : list<node>
  locals : list<ref-variable> = unsafe-total { !local-vars }
  stack-size : int = 0
}

public struct programm {
  functions : list<funktion> = Nil
  globals : list<ref-variable> = unsafe-total { !global-vars }
}

alias zerteilen = <console, div, exn, ndet, st<global>>

public noinline val local-vars : ref<global, list<ref-variable>> = unsafe-total { ref(Nil) }
public noinline val global-vars : ref<global, list<ref-variable>> = unsafe-total { ref(Nil) }

public noinline val defined-func-names : ref<global, list<string>> = unsafe-total { ref(Nil) }
public noinline val used-func-names : ref<global, list<string>> = unsafe-total { ref(Nil) }

/* ==============================================================================================
  Codes
============================================================================================== */

fun find-variable( token : token ) : <read<global>, div> maybe<ref-variable> {
  val look-at = fn (vars : list<ref-variable>) {
    vars.find(fn (v) {
      token.literal.maybe(
        onNothing = False,
        onJust = fn (l) { unsafe-total { l.string() == (!v).name } })
    })
  }

  val found-var = look-at(!local-vars)
  if (found-var.bool()) then found-var
  else look-at(!global-vars)
}

// Determine if the next top-level item is a function or a global variable
// by looking ahead input tokens
fun is-function() {
  val tokens = !remained-tokens
  base-type()
  val is-func = if (consume-ident().bool()) then consume("(").bool() else False
  remained-tokens := tokens
  is-func
}

/* ----------------------------------------------------------------------------
  program = (function | global-variable)*
---------------------------------------------------------------------------- */
public fun program( tokens : list<token> ) : zerteilen programm {
  remained-tokens := tokens

  var funktionen := Nil
  while { !at-eof() } {
    if (is-function())
    then funktionen := Cons(eine-funktion(), funktionen)
    else global-variable()
  }

  Programm(funktionen.reverse())
}

/* ----------------------------------------------------------------------------
  base-type = ("char" | "int") "*"*
---------------------------------------------------------------------------- */
fun base-type() {
  var ty := if (consume("char").bool()) then Typ(TyChar, size = 1) else {
    expect("int")
    Typ(TyInt)
  }

  while { consume("*").bool() } {
    ty := Typ(TyPtr, base = Just(ty))
  }
  ty
}

fun type-suffix( base : typ ) {
  if (consume("[").bool()) then {
    val len = expect-number()
    expect("]")
    val array-base = type-suffix(base)
    Typ(TyArray, array-base.size * len, Just(array-base), Just(len))
  }
  else base
}

fun func-param() {
  val (ty, name) = {
    val ty = base-type()
    val name = expect-ident().string()
    (type-suffix(ty), name)
  }
  Variable(name, ty = Just(ty))
}

fun func-params() {
  if (consume(")").bool())
  then Nil
  else {
    var params := [ref(func-param())]
    while { !consume(")").bool() } {
      expect(",")
      val param = ref(func-param())
      params := Cons(param, params)
    }
    local-vars := params
    params
  }
}

/* ----------------------------------------------------------------------------
  function = base-type ident "(" params? ")" "{" stmt* "}"
  params   = param ("," param)*
  param    = base-type ident
---------------------------------------------------------------------------- */
fun eine-funktion() {
  // reset local variables
  local-vars := Nil

  // parse function return type
  base-type()

  // parse function parameters
  val name = expect-ident().string()
  expect("(")
  val params = func-params()

  // parse function body
  val nodes = {
    expect("{")
    var stmt-nodes := Nil
    while { !consume("}").bool() } {
      stmt-nodes := Cons(stmt(), stmt-nodes)
    }
    stmt-nodes.reverse()
  }

  defined-func-names := Cons(name, !defined-func-names)
  Funktion(name, params, nodes)
}

/* ----------------------------------------------------------------------------
  global-variable = base-type ident ("[" num "]")* ";"
---------------------------------------------------------------------------- */
fun global-variable() {
  var ty := base-type()
  val name = expect-ident().string()
  ty := type-suffix(ty)
  expect(";")
  val new-var = ref(Variable(name, Just(ty), False))
  global-vars := Cons(new-var, !global-vars)
}

/* ----------------------------------------------------------------------------
  declaration = base-type ident ("[" num "]")* ("=expr") ";"
---------------------------------------------------------------------------- */
fun declaration() {
  val token = (!last-consumed-token).unjust()
  var ty := base-type()
  val name = expect-ident().string()
  ty := type-suffix(ty)

  val new-var = ref(Variable(name, ty = Just(ty)))
  local-vars := Cons(new-var, !local-vars)

  if (consume(";").bool())
  then Node(NdNull, token)
  else {
    expect("=")
    val lhs = Node(NdVar, token, variable = Just(new-var))
    val rhs = expr()
    expect(";")
    val node = Node(NdAssign, token, lhs = Just(lhs), rhs = Just(rhs))
    Node(NdExprStmt, token, lhs = Just(node))
  }
}

fun is-typename() {
  if (peek("char").bool()) then True
  else peek("int").bool()
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
       | declaration
       | expr ";"
---------------------------------------------------------------------------- */
fun untyped-stmt() {
  match (consume("return")) {
    Just(token) -> {
      val node = Node(NdReturn, token, lhs = Just(expr()))
      expect(";")
      return node
    }

    _ -> ()
  }

  match (consume("if")) {
    Just(token) -> {
      expect("(")
      val cond-expr = expr()
      expect(")")

      val then-stmt = stmt()
      val else-stmt = consume("else").map(fn (_) { stmt() })

      return Node(NdIf, token, wenn = Just(cond-expr), dann = Just(then-stmt), sonst = else-stmt)
    }

    _ -> ()
  }

  match (consume("while")) {
    Just(token) -> {
      expect("(")
      val cond-expr = expr()
      expect(")")

      return Node(NdWhile, token, wenn = Just(cond-expr), dann = Just(stmt()))
    }

    _ -> ()
  }

  match (consume("for")) {
    Just(token) -> {
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

      return Node(
        NdFor, token,
        init = init-stmt, wenn = cond-expr, inc = inc-stmt, dann = Just(stmt())
      )
    }

    _ -> ()
  }

  match (consume("{")) {
    Just(token) -> {
      var stmts := Nil
      while { !consume("}").bool() } {
        stmts := Cons(stmt(), stmts)
      }
      stmts := stmts.reverse()

      Node(NdBlock, token, body = Just(stmts))
    }

    _ -> {
      if (is-typename()) then declaration()
      else {
        val node = Node(NdExprStmt, lhs = Just(expr()))
        expect(";")
        node
      }
    }
  }
}

/* ----------------------------------------------------------------------------
  expr = assign
---------------------------------------------------------------------------- */
fun expr( ) {
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
  val lhs-typ = typed-lhs.ty.unjust()
  val rhs-typ = typed-rhs.ty.unjust()

  // linke und rechte Seite sind Integer
  if (is-integer(lhs-typ) && is-integer(rhs-typ))
  then Node(NdAdd, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // linke Seite ist ein Zeiger, rechte Seite ist eine Integer
  elif (lhs-typ.base.bool() && is-integer(rhs-typ))
  then Node(NdPtrAdd, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // linke Seite ist eine Integer, rechte Seite ist ein Zeiger
  elif (is-integer(lhs-typ) && rhs-typ.base.bool())
  then Node(NdPtrAdd, token, lhs = Just(typed-rhs), rhs = Just(typed-lhs))
  // sonst
  else error-token(token, "invalid operands")
}

fun typed-sub( lhs : node, rhs : node, token : token ) {
  val (typed-lhs, typed-rhs) = (add-type(lhs), add-type(rhs))
  val lhs-typ = typed-lhs.ty.unjust()
  val rhs-typ = typed-rhs.ty.unjust()

  // linke und rechte Seite sind Integern
  if (is-integer(lhs-typ) && is-integer(rhs-typ))
  then Node(NdSub, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // linke Seite est ein Zeiger, rechte Seite est ein Integer
  elif (lhs-typ.base.bool() && is-integer(rhs-typ))
  then Node(NdPtrSub, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // linke und rechte Seite sind Zeigern
  elif (lhs-typ.base.bool() && rhs-typ.base.bool())
  then Node(NdPtrDiff, token, lhs = Just(typed-lhs), rhs = Just(typed-rhs))
  // sonst
  else error-token(token, "invalid operands")
}

/* ----------------------------------------------------------------------------
  add-or-sub = mul-or-div ("+" mul-or-div | "-" mul-or-div)*
---------------------------------------------------------------------------- */
fun add-or-sub() : zerteilen node {
  fun parse( lhs ) : zerteilen node {
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
fun mul-or-div() {
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
        | postfix
---------------------------------------------------------------------------- */
fun unary() {
  if (consume("+").bool())
  then unary()
  elif (consume("-").bool())
  then Node(NdSub, lhs = Just(Node(NdNum, value = Just(0))), rhs = Just(unary()))
  elif (consume("*").bool())
  then Node(NdDeref, lhs = Just(unary()))
  elif (consume("&").bool())
  then Node(NdAddr, lhs = Just(unary()))
  else nachsilbe()
}

/* ----------------------------------------------------------------------------
  postfix = primary ("[" expr "]")*
---------------------------------------------------------------------------- */
fun nachsilbe() {
  fun parse( node : node ) {
    match (consume("[")) {
      Just(token) -> {
        // x[y] is short for *(x + y) or *(y + x)
        val lhs = typed-add(node, expr(), token)
        expect("]")
        parse(Node(NdDeref, token, lhs = Just(lhs)))
      }

      _ -> node
    }
  }
  parse(primary())
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
    expect(")")
    args
  }
}

/* ----------------------------------------------------------------------------
  primary = '(' expr ')' | "sizeof" unary | ident func-args? | str | num
  args = "(" ident ("," ident)* ")"
---------------------------------------------------------------------------- */
fun primary() {
  if (consume("(").bool())
  then {
    val node = expr(); expect(")")
    return node
  }

  match (consume("sizeof")) {
    Just(token) -> {
      val node = add-type(unary())
      return Node(NdNum, token, value = node.ty.map(fn (ty) { ty.size }))
    }

    _ -> ()
  }

  match (consume-ident()) {
    Just(token) -> {
      if (consume("(").bool())
      // Function call
      then {
        val fcname = token.literal.unjust().string()

        if (!(!used-func-names).find(fn (name) { name == fcname }).bool())
        then used-func-names := Cons(fcname, !used-func-names)

        return Node(NdFunCall, token, fcname = Just(fcname), fcargs = Just(func-args()))
      }
      // Variable
      else {
        match (find-variable(token)) {
          Just(a-var) -> return Node(NdVar, variable = Just(a-var))

          _ -> error-token(token, "undefined variable")
        }
      }
    }

    _ -> ()
  }

  match (consume-string-literal()) {
    Just(token) -> {
      val ty = {
        val base-ty = Typ(TyChar, 1)
        val contents-len = token.contents.unjust().count() + 1
        Typ(TyArray, base-ty.size * contents-len, Just(base-ty), Just(contents-len))
      }

      val name = ".L.data." ++ unique().show()

      val str-var = ref(Variable(name, ty = Just(ty), is-local = False, contents = token.contents))
      global-vars := Cons(str-var, !global-vars)

      return Node(NdVar, token, variable = Just(str-var))
    }

    _ -> ()
  }

  val token = blicken()
  match (token) {
    Just(Token(TokNumber)) -> Node(NdNum, token.unjust(), value = Just(expect-number()))

    _ -> error-token(token.unjust(), "expected expression")
  }
}
