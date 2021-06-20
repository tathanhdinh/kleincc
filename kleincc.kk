module kleincc

// Token
public type token-kind {
  TokReserved     // keywords or punctuators
  TokIdent        // identifiers
  TokNumber       // integer literals
  TokEof          // end-of-file markers
}

// Token type.
public struct token {
  kind : token-kind
  value : maybe<int> = Nothing
  literal : maybe<sslice> = Nothing
}

// For debugging.
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

// Local variable.
public struct variable {
  name : string                   // variable name
  ty : maybe<typ> = Nothing       // type
  offset : maybe<int> = Nothing   // offset from the base pointer
}

// AST node.
public type node-kind {
  NdAdd       // num + num
  NdPtrAdd    // ptr + num oder num + ptr
  NdSub       // num - num
  NdPtrSub    // ptr - num
  NdPtrDiff   // ptr - ptr
  NdMul       // *
  NdDiv       // /
  NdEq        // ==
  NdNe        // !=
  NdLt        // <
  NdLe        // <=
  NdAssign    // =
  NdAddr      // unary &
  NdDeref     // unary *
  NdReturn    // "return"
  NdIf        // "if"
  NdWhile     // "while"
  NdFor       // "for"
  NdBlock     // { ... }
  NdFunCall   // function call
  NdExprStmt  // expression statement
  NdVar       // variable
  NdNum       // integer
  NdNull      // empty statement
}

public noinline val last-consumed-token = unsafe-total { ref(Nothing) }

// AST node type.
public struct node {
  kind : node-kind                                                  // node kind
  token : token = unsafe-total { (!last-consumed-token).unjust() }  // representative token
  ty : maybe<typ> = Nothing                                         // type, e.g. int of pointer to int

  lhs : maybe<node> = Nothing                                       // rechte seite
  rhs : maybe<node> = Nothing                                       // linke seite

  // "if", "while" or "for"
  wenn : maybe<node> = Nothing                                      // condition expression
  dann : maybe<node> = Nothing                                      // then statement
  sonst : maybe<node> = Nothing                                     // else statement
  init : maybe<node> = Nothing                                      // initial statement
  inc : maybe<node> = Nothing                                       // increment statement

  body: maybe<list<node>> = Nothing                                 // statement block

  fcname : maybe<string> = Nothing                                  // function call
  fcargs : maybe<list<node>> = Nothing                              // function call arguments (I want to distinguish
                                                                    // Nothing from Nil: Nothing is used when the node
                                                                    // is not a function call, Nil is used when the node
                                                                    // is a function call, but with no argument)

  variable : maybe<variable> = Nothing                              // used if kind is NdVar
  value : maybe<int> = Nothing                                      // used if kind is NdNum
}

// For debugging.
public fun show( n : node, indent : int = 0) : <div, console> string {
  val kind = match (n.kind) {
    NdAdd -> "integer addition"
    NdPtrAdd -> "pointer addition"
    NdSub -> "integer subtraction"
    NdPtrSub -> "pointer subtraction"
    NdPtrDiff -> "pointer difference"
    NdMul -> "*"
    NdDiv -> "/"
    NdEq -> "=="
    NdNe -> "!="
    NdLt -> "<"
    NdLe -> "<="
    NdAssign -> "assignment"
    NdAddr -> "address of"
    NdDeref -> "dereference"
    NdReturn -> "return keyword"
    NdIf -> "if statement"
    NdWhile -> "while statement"
    NdFor -> "for statement"
    NdBlock -> "block statement"
    NdFunCall -> "function call"
    NdExprStmt -> "expression statement"
    NdVar -> "identifier"
    NdNull -> "empty statement"
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

public type typ-art {
  TyInt
  TyPtr
}

public struct typ {
  kind : typ-art
  base : maybe<typ> = Nothing
}
