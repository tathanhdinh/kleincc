module codegen

import parse
import tokenize

// Push the given node address to the stack.
fun gen-addr( node : node ) : <console, exn> () {
  match (node) {
    Node(NdVar, name = Just(name)) -> {
      val (var-name, _) = name.next().unjust()
      val offset = ((var-name - 'a').int() + 1) * 8
      println(
        "  lea rax, [rbp - " ++ offset.show() ++ "]\n" ++
        "  push rax"
      )
    }

    _ -> error("not a lvalue")
  }
}

fun load() : <console> () {
  println(
    "  pop rax\n" ++
    "  mov rax, [rax]\n" ++
    "  push rax"
  )
}

fun store() : <console> () {
  println(
    "  pop rdi\n" ++
    "  pop rax\n" ++
    "  mov [rax], rdi\n" ++
    "  push rdi"
  )
}

// Generate code for a given node.
fun gen( node : node ) : <console, div, exn> () {
  match (node) {
    Node(NdNum, lhs = _, rhs = _, name = _, value = Just(value)) ->
      println(
        "  push " ++ value.show()
      )

    Node(NdExprStmt, lhs = Just(lhs)) -> {
      gen(lhs)

      // Discard the last stored result.
      println(
        "  add rsp, 8"
      )
    }

    Node(NdVar, _) -> {
      gen-addr(node)
      load()
    }

    Node(NdAssign, lhs = Just(lhs), rhs = Just(rhs), name = _, value = _) -> {
      gen-addr(lhs)
      gen(rhs)
      store()
    }

    Node(NdReturn, lhs = Just(lhs), rhs = _, name = _, value = _) -> {
      gen(lhs)

      // Pop the stored result.
      println(
        "  pop rax\n" ++
        "  jmp .L.return"
      )
    }

    Node(kind, lhs = Just(lhs), rhs = Just(rhs), name = _, value = _) -> {
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

public fun codegen( nodes : list<node> ) : <console, div, exn> () {
  println(
    "global main\n" ++
    "section .smc alloc write exec align=16\n" ++
    "main:"
  )

  // Prologue
  println(
    "  push rbp\n" ++
    "  mov rbp, rsp\n" ++
    "  sub rsp, 208"  // 208 = 26 * 8
  )

  nodes.foreach fn(node) { gen(node) }

  // Epilogue
  println(
    ".L.return:\n" ++
    "  mov rsp, rbp\n" ++
    "  pop rbp"
  )

  // The result has been poped into RAX,
  // so move it to RDI to make it the program exit code.
  // Then pass 60 to RAX to invoke sys_exit
  println(
    "  mov rdi, rax\n" ++
    "  mov rax, 60\n" ++
    "  syscall"
  )
}