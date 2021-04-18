import std/os/env

fun main() : <console, ndet> int {
    val input = match (get-argv()) {
        Cons(prog, args) -> {
            match (args) {
                Cons(input, Nil) -> input
                _ -> {
                    println(prog ++ ": invalid number of arguments");
                    return 1
                }
            }
        }

        _ -> return 1
    }

    println(".intel_syntax noprefix")
    println(".global main")
    println("main:")
    println("  xor rax, rax")

    input.split("+").foreach fn(term) {
        match (term.split("-")) {
            Cons(term, terms) -> {
                println("  add rax, " ++ term)
                with term = terms.foreach
                println("  sub rax, " ++ term)
            }
            _ -> ()
        }
    }

    println("  ret")
    0
}