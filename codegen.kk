module codegen

import parse

fun gen( node : node ) : <console, div> () {
  match (node) {
    Node(NdNum, value = Just(value)) -> println("  push " ++ value.show())
    Node(kind, lhs = Just(lhs), rhs = Just(rhs)) -> {
      gen(lhs)
      gen(rhs)

      println(
        "  pop rdi\n" ++ // rhs
        "  pop rax"      // lhs
      );

      match (kind) {
        NdAdd -> println(
          "  add rax, rdi"
        )
        NdSub -> println(
          "  sub rax, rdi"
        )
        NdMul -> println(
          "  imul rax, rdi"
        )
        NdDiv -> println(
          "  cqo\n" ++
          "  idiv rdi"
        )
        NdEq -> println(
          "  cmp rax, rdi\n" ++
          "  sete al\n" ++
          "  movzx rax, al"
        )
        NdNe -> println(
          "  cmp rax, rdi\n" ++
          "  setne al\n" ++
          "  movzx rax, al"
        )
        NdLt -> println(
          "  cmp rax, rdi\n" ++
          "  setl al\n" ++
          "  movzx rax, al"
        )
        NdLe -> println(
          "  cmp rax, rdi\n" ++
          "  setle al\n" ++
          "  movzx rax, al"
        )
        _ -> ()
      }

      println("  push rax") // store the result
    }
    _ -> ()
  }
}

public fun codegen( node : node ) : <console, div> () {
  println(
    "global main\n" ++
    "section .smc write exec align=16\n" ++
    "main:"
  )

  gen(node)

  // The result is at the top of the stack,
  // so pop it to RDI to make it the program exit code
  println(
    "  pop rdi"
  )

  // Pass 60 to RAX to invoke sys_exit
  println(
    "  mov rax, 60\n" ++
    "  syscall"
  )
}