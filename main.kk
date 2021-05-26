import std/os/env

import tokenize
import parse
import codegen

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
    val tokens = tokenize/tokenize(input)
    val (node, _) = parse/expr(tokens)

    // Traverse the AST to emit assembly.
    codegen/codegen(node)

    0
  } fn (exn) {
    println(exn.message)
    1
  }
}
