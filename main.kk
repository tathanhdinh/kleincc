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
        fun compute-offset( vars : list<variable>, init : int = 0) {
          match (vars) {
            Cons(h-var, tl-vars) -> {
              val offset = init + h-var.ty.unjust().size
              Cons(h-var(offset = Just(offset)), compute-offset(tl-vars, offset))
            }

            _ -> Nil
          }
        }

        fk(
          stacksize = fk.locals.foldl(0, fn (i, v) { i + v.ty.unjust.size() }),
          locals = fk.locals.compute-offset(),
          params = fk.params.compute-offset()
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
