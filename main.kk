import std/os/env

import kleincc
import tokenize
import parse
import codegen

fun align-to( n : int, align : int ) {
  if (n % align == 0) then n else ((n + align - 1) / align) * align
}

fun main() {
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
      val funktionen = prog.functions.map(fn (f) {
        var offset := 0
        f.locals.foreach(fn (rv) {
          val v = !rv
          offset := offset + v.ty.unjust().size
          rv := v(offset = Just(offset))
        })
        f(stack-size = align-to(offset, 8))
      })
      prog(functions = funktionen)
    }

    // Traverse the AST to emit assembly.
    codegen/codegen(programm)

    0
  } fn (exn) {
    println(exn.message)
    1
  }
}
