import std/os/env

import tokenize
import parse
import codegen

fun main() : <console, div, ndet, read<global>, write<global>> int {
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
    val programm = parse/program(tokens)

    // Assign offsets to local variables.
    val locals = programm.locals.map-indexed(fn (i, v) { v(offset = Just(i * 8)) })
    val programm = programm(locals = locals)

    // Traverse the AST to emit assembly.
    codegen/codegen(programm)

    0
  } fn (exn) {
    println(exn.message)
    1
  }
}
