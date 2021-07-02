module codegen

import kleincc
import parse
import tokenize

private val arg-reg = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"]

private noinline val label-seq = unsafe-total { ref(0) }
private noinline val func-name = unsafe-total { ref(Nothing) }

fun asm-directive( dirv : list<string> ) {
  if (!dirv.is-empty()) then {
    println(dirv.join("\n"))
  }
}

fun asm-instruction( code : list<string> ) {
  if (!code.is-empty()) then {
    val aligned-code = code.map(fn (c) { "  " ++ c })
    println(aligned-code.join("\n"))
  }
}

// Push the given node address to the stack.
fun gen-addr( node ) {
  match (node) {
    Node(NdVar, variable = Just(rv)) -> {
      val v = !rv
      if (v.is-local) then {
        asm-instruction([
          "lea rax, [rbp - " ++ v.offset.unjust().show() ++ "]",
          "push rax"
        ])
      }
      else {
        asm-instruction([
          "lea rax, [" ++ v.name ++"]",
          "push rax"
        ])
      }
    }

    Node(NdDeref, lhs = Just(lhs)) -> {
      gen(lhs)
    }

    _ -> error-token(node.token, "not a lvalue")
  }
}

fun gen-lvalue( node : node ) {
  match (node) {
    Node(_, token, Just(Typ(TyArray))) -> error-token(token, "not a lvalue")

    _ -> gen-addr(node)
  }
}

fun load() {
  asm-instruction([
    "pop rax",
    "mov rax, [rax]",
    "push rax"
  ])
}

fun store() {
  asm-instruction([
    "pop rdi",
    "pop rax",
    "mov [rax], rdi",
    "push rdi"
  ])
}

// Generate code for a given node.
fun gen( node : node ) {
  match (node) {
    Node(NdNum, value = Just(value)) ->
      println(
        "  push " ++ value.show()
      )

    Node(NdExprStmt, lhs = Just(s)) -> {
      gen(s)

      // Discard the last stored result.
      println(
        "  add rsp, 8"
      )
    }

    Node(NdVar) -> {
      gen-addr(node);
      match (node.ty) {
        Just(Typ(TyArray)) -> ()

        _ -> load()
      }
    }

    Node(NdAssign, lhs = Just(lhs), rhs = Just(rhs)) -> {
      gen-lvalue(lhs); gen(rhs); store()
    }

    Node(NdAddr, lhs = Just(lhs)) -> {
      gen-addr(lhs)
    }

    Node(NdDeref, lhs = Just(lhs)) -> {
      gen(lhs)
      match (node.ty) {
        Just(Typ(TyArray)) -> ()

        _ -> load()
      }
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
        fcargs.foreach-indexed(fn (i, _) {
          println(
            "  pop " ++ arg-reg[i].unjust()
          )
        })
      }

      // Align RSP to a 16 byte boundary before calling a function: x86-64 ABI
      // https://stackoverflow.com/questions/9592345
      println(
        "  push rsp\n" ++
        "  push qword [rsp]\n" ++
        "  and rsp, -0x10\n" ++
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
        "  jmp .L.return." ++ (!func-name).unjust()
      )
    }

    Node(kind, ty = Just(typ), lhs = Just(lhs), rhs = Just(rhs)) -> {
      gen(lhs)
      gen(rhs)

      println(
        "  pop rdi\n" ++ // rechte Seite
        "  pop rax"      // linke Seite
      );

      match (kind) {
        NdAdd -> println(
          "  add rax, rdi"
        )

        NdPtrAdd -> println(
          "  imul rdi, " ++ typ.base.unjust().size.show() ++ "\n" ++
          "  add rax, rdi"
        )

        NdSub -> println(
          "  sub rax, rdi"
        )

        NdPtrSub -> println(
          "  imul rdi, " ++ typ.base.unjust().size.show() ++ "\n" ++
          "  sub rax, rdi"
        )

        NdPtrDiff -> println(
          "  sub rax, rdi\n" ++
          "  cqo\n" ++
          "  mov rdi, " ++ lhs.ty.unjust().base.unjust().size.show() ++ "\n" ++
          "  idiv rdi"
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

fun emit-data( prog : programm ) {
  if (prog.globals.is-empty()) then return ()

  asm-directive([
    "section .data"
  ])

  prog.globals.foreach(fn (rv) {
    val v = !rv
    asm-directive([
      v.name ++ ":"
    ])
    asm-instruction([
      "db " ++ v.ty.unjust().size.show() ++ " dup (0)"
    ])
  })
}

fun emit-text( prog : programm ) {
  asm-directive([
    "section .text"
  ])

  // External names
  val extern-func-names = (!used-func-names).filter(fn (uname) {
    !(!defined-func-names).find(fn (dname) { dname == uname }).bool()
  })
  if (!extern-func-names.is-empty())
  then asm-directive([
    "extern " ++ extern-func-names.join(", ")
  ])

  // Constructor and destructor
  val constructor-label = "start"
  val destructor-label = "fini"

  // Constructor: push destructor's address so that it will be called by the last return,
  // then jump to main
  asm-directive([
    "global " ++ constructor-label,
    constructor-label ++ ":"
  ])
  asm-instruction([
    "lea rax, [" ++ destructor-label ++ "]",
    "push rax",
    "jmp main"
  ])

  // Destructor: the final result has been popped into rax, so move it to rdi to make it
  // the program exit code. Then pass 60 to rax to invoke sys_exit
  println(
    destructor-label ++ ":\n" ++
    "  mov rdi, rax\n" ++
    "  mov rax, 60\n" ++
    "  syscall"
  )

  // Code
  prog.functions.foreach(fn (f) {
    println(
      f.name ++ ":"
    )
    func-name := Just(f.name)

    // Prologue
    println(
      "  push rbp\n" ++
      "  mov rbp, rsp"
    )
    if (f.stack-size != 0) {
      println(
        "  sub rsp, " ++ f.stack-size.show()
      )
    }

    // Push arguments to the stack
    f.params.reverse().foreach-indexed(fn (i, v) {
      println(
        "  mov [rbp - " ++ (!v).offset.unjust().show() ++ "], " ++ arg-reg[i].unjust()
      )
    })

    // Emit code
    local-vars := f.locals
    f.nodes.foreach(gen)

    // Epilogue
    println(
      ".L.return." ++ f.name ++ ":\n" ++
      "  mov rsp, rbp\n" ++
      "  pop rbp\n" ++
      "  ret"
    )
  })
}

public fun codegen( prog : programm ) {
  asm-directive([
    "default rel"
  ])
  emit-data(prog)
  emit-text(prog)
}
