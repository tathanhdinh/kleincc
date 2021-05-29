module codegen

import parse

fun gen( node : node ) : <console, div> () {
  match (node) {
    Node(NdNum, value = Just(value)) ->
      println(
        "  push " ++ value.show()
      )

    Node(NdExprStmt, lhs = Just(lhs)) -> {
      gen(lhs)

      // Discard the last stored result
      println(
        "  add rsp, 8"
      )
    }

    Node(NdReturn, lhs = Just(lhs)) -> {
      gen(lhs)

      // Pop the stored result
      println(
        "  pop rax\n" ++
        "  jmp final"
      )
    }

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

      // Store the result
      println("  push rax")
    }

    _ -> ()
  }
}

public fun codegen( nodes : list<node> ) : <console, div> () {
  println(
    "global main\n" ++
    "section .smc alloc write exec align=16\n" ++
    "main:"
  )

  nodes.foreach fn(node) { gen(node) }

  // The result has been poped into RAX,
  // so move it to RDI to make it the program exit code.
  // Then pass 60 to RAX to invoke sys_exit
  println(
    "final:\n" ++
    "  mov rdi, rax\n" ++
    "  mov rax, 60\n" ++
    "  syscall"
  )
}