module codegen

import parse
import tokenize

private noinline val label-seq = unsafe-total { ref(0) }

// Push the given node address to the stack.
fun gen-addr( node : node, locals : list<variable> ) : <console, exn> () {
  match (node) {
    Node(NdVar, variable = Just(Variable(name = var-name))) -> {
      val v = locals.find(fn (v) { v.name == var-name }).unjust()
      val offset = v.offset.unjust()
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
fun gen( node : node, locals : list<variable> ) : <console, div, exn> () {
  match (node) {
    Node(NdNum, value = Just(value)) ->
      println(
        "  push " ++ value.show()
      )

    Node(NdExprStmt, lhs = Just(lhs)) -> {
      gen(lhs, locals)

      // Discard the last stored result.
      println(
        "  add rsp, 8"
      )
    }

    Node(NdVar) -> {
      gen-addr(node, locals)
      load()
    }

    Node(NdAssign, lhs = Just(lhs), rhs = Just(rhs)) -> {
      gen-addr(lhs, locals)
      gen(rhs, locals)
      store()
    }

    Node(NdIf, wenn = Just(wenn), dann = Just(dann)) -> {
      val seq = !label-seq
      label-seq := seq + 1

      val end-label = ".L.end." ++ seq.show()
      val else-label = ".L.else." ++ seq.show()

      // if condition
      gen(wenn, locals)
      println(
        "  pop rax\n" ++
        "  test rax, rax"
      )

      match (node.sonst) {
        Nothing -> {
          println(
            "  je " ++ end-label
          )
          gen(dann, locals)
        }

        Just(sonst) -> {
          println(
            "  je " ++ else-label
          )

          // then branch
          gen(dann, locals)
          println(
            " jmp " ++ end-label
          )

          // else branch
          println(
            else-label ++ ":"
          )
          gen(sonst, locals)
          println(
            " jmp " ++ end-label
          )
        }
      }
      println(end-label ++ ":")
    }

    Node(NdReturn, lhs = Just(lhs)) -> {
      gen(lhs, locals)

      // Pop the stored result.
      println(
        "  pop rax\n" ++
        "  jmp .L.return"
      )
    }

    Node(kind, lhs = Just(lhs), rhs = Just(rhs)) -> {
      gen(lhs, locals)
      gen(rhs, locals)

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

public fun codegen( prog : funktion ) : <console, div, exn, read<global>> () {
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

  prog.nodes.foreach fn(node) { gen(node, prog.locals) }

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