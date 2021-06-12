module codegen

import parse
import tokenize

private noinline val label-seq = unsafe-total { ref(0) }
private noinline val arg-reg = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"]

private noinline val local-variables = unsafe-total { ref(Nil) }

// Push the given node address to the stack.
fun gen-addr( node : node ) : <console, exn> () {
  val locals = !local-variables

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
fun gen( node : node ) : <console, div, exn> () {
  match (node) {
    Node(NdNum, value = Just(value)) ->
      println(
        "  push " ++ value.show()
      )

    Node(NdExprStmt, lhs = Just(linke-seite)) -> {
      gen(linke-seite)

      // Discard the last stored result.
      println(
        "  add rsp, 8"
      )
    }

    Node(NdVar) -> {
      gen-addr(node); load()
    }

    Node(NdAssign, lhs = Just(linke-seite), rhs = Just(rechte-seite)) -> {
      gen-addr(linke-seite); gen(rechte-seite); store()
    }

    Node(NdIf, wenn = Just(wenn), dann = Just(dann)) -> {
      val seq = !label-seq
      label-seq := seq + 1

      val end-label = ".L.end." ++ seq.show()
      val else-label = ".L.else." ++ seq.show()

      // if condition
      gen(wenn)
      println(
        "  pop rax\n" ++
        "  test rax, rax"
      )

      match (node.sonst) {
        Nothing -> {
          println(
            "  jz " ++ end-label
          )

          // then branch
          gen(dann)
        }

        Just(sonst) -> {
          println(
            "  jz " ++ else-label
          )

          // then branch
          gen(dann)
          println(
            " jmp " ++ end-label
          )

          // else branch
          println(else-label ++ ":")
          gen(sonst)
          println(
            " jmp " ++ end-label
          )
        }
      }
      println(end-label ++ ":")
    }

    Node(NdFor, dann = Just(dann)) -> {
      val seq = !label-seq
      label-seq := seq + 1

      val begin-label = ".L.begin." ++ seq.show()
      val end-label = ".L.end." ++ seq.show()

      // Generate the initialization statement
      node.init.maybe(
        onNothing = (),
        onJust = gen
      )
      println(begin-label ++ ":")

      // Generate the conditional expression
      node.wenn.maybe(
        onNothing = (),
        onJust = fn (wenn) {
          gen(wenn)
          println(
            "  pop rax\n" ++
            "  test rax, rax\n" ++
            "  jz " ++ end-label
          )
        }
      )

      // Generate the body statement
      gen(dann)

      // Generate the increment statement
      node.inc.maybe(
        onNothing = (),
        onJust = gen
      )
      println(
        "  jmp " ++ begin-label ++ "\n" ++
        end-label ++ ":"
      )
    }

    Node(NdWhile, wenn = Just(wenn), dann = Just(dann)) -> {
      val seq = !label-seq
      label-seq := seq + 1

      val begin-label = ".L.begin." ++ seq.show()
      val end-label = ".L.end." ++ seq.show()

      println(begin-label ++ ":")
      gen(wenn)
      println(
        "  pop rax\n" ++
        "  test rax, rax\n" ++
        "  jz " ++ end-label
      )
      gen(dann)
      println(
        "  jmp " ++ begin-label ++ "\n" ++
        end-label ++ ":"
      )
    }

    Node(NdBlock, body = Just(body)) -> {
      body.foreach(gen)
    }

    Node(NdFunCall, fcname = Just(fcname), fcargs = Just(fcargs)) -> {
      if (!fcargs.is-empty()) {
        fcargs.foreach(gen)
        val args-idx-bound = fcargs.length() - 1
        fcargs.foreach-indexed(fn (i, _) {
          println(
            "  pop " ++ arg-reg[args-idx-bound - i].unjust()
          )
        })
      }

      // Align RSP to a 16 byte boundary before calling a function: x86-64 ABI
      // https://stackoverflow.com/questions/9592345
      println(
        "  push rsp\n" ++
        "  push rsp\n" ++
        "  and rsp, -0x10\n" ++
        "extern " ++ fcname ++ "\n" ++
        "  call " ++ fcname ++ "\n" ++
        "  mov rsp, [rsp+0x8]\n" ++
        "  push rax"
      )
    }

    Node(NdReturn, lhs = Just(lhs)) -> {
      gen(lhs)

      // Pop the stored result.
      println(
        "  pop rax\n" ++
        "  jmp .L.return"
      )
    }

    Node(kind, lhs = Just(linke-seite), rhs = Just(rechte-seite)) -> {
      gen(linke-seite)
      gen(rechte-seite)

      println(
        "  pop rdi\n" ++ // rechte seite
        "  pop rax"      // linke seite
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

  local-variables := prog.locals
  prog.nodes.foreach(gen)

  // Epilogue
  println(
    ".L.return:\n" ++
    "  mov rsp, rbp\n" ++
    "  pop rbp"
  )

  // The result has been popped into RAX,
  // so move it to RDI to make it the program exit code.
  // Then pass 60 to RAX to invoke sys_exit
  println(
    "  mov rdi, rax\n" ++
    "  mov rax, 60\n" ++
    "  syscall"
  )
}
