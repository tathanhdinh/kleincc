import std/os/env

import kleincc
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
    val programm = {
      val prog = parse/program(tokens)
      prog.map(fn (fk) {
        fk(
          stacksize = fk.locals.length() * 8,
          locals = fk.locals.map-indexed(fn (i, v) { v(offset = Just((i + 1) * 8)) }),
          params = fk.params.map-indexed(fn (i, v) { v(offset = Just((i + 1) * 8)) })
        )
      })
    }

    // Traverse the AST to emit assembly.
    codegen/codegen(programm)

    0
  } fn (exn) {
    println(exn.message)
    1
  }
}
