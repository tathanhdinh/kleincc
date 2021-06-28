module codegen

import kleincc
import parse
import tokenize

private val arg-reg = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"]

private noinline val label-seq = unsafe-total { ref(0) }
private noinline val func-name = unsafe-total { ref(Nothing) }

// Push the given node address to the stack.
fun gen-addr( node ) {
  match (node) {
    Node(NdVar, variable = Just(Variable(name = var-name))) -> {
      val v = (!local-vars).find(fn (v) { v.name == var-name }).unjust()

      val label = {
        var l := Nil
        repeat(2, fn () {
          l := Cons(".L." ++ unique().show(), l)
        })
        l.reverse().vector()
      }
      val smc = [
        "  lea rax, [rbp - " ++ v.offset.unjust().show() ++ "]",

        "  xor byte [" ++ label[0] ++ "], 0x9c",
        label[0] ++ ":",
        "  db 0xcc",                                           // original 0x50
        "  sub byte [" ++ label[0] ++ "], -0x7c",
      ]
      println(smc.join("\n"))

      // println(
      //   "  lea rax, [rbp - " ++ v.offset.unjust().show() ++ "]\n" ++
      //   "  push rax"
      // )
    }

    Node(NdDeref, lhs = Just(lhs)) ->{
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
  val l0 = ".L." ++ unique().show()
  val l1 = ".L." ++ unique().show()
  val l2 = ".L." ++ unique().show()
  val smc = [
    "  add byte [" ++ l0 ++ "], 0x23",
    // "  jmp " ++ l0,
    l0 ++ ":",
    "  db 0x35",
    "  sub word [" ++ l1 ++ " + 1], 0x0101",
    // "  jmp " ++ l1,
    l1 ++ ":",
    "  db 0x48, 0x8c, 0x01",
    "  sub byte [" ++ l2 ++ "], 0x0f",
    // "  jmp " ++ l2,
    l2 ++ ":",
    "  db 0x5f",
    "  xor byte [" ++ l0 ++ "], 0x6d",
    "  add word [" ++ l1 ++ " + 1], 0x0101",
    "  add byte [" ++ l2 ++ "], 0x0f",
  ]
  println(smc.join("\n"))

  // println(
  //   "  pop rax\n" ++
  //   "  mov rax, [rax]\n" ++
  //   "  push rax"
  // )
}

fun store() {
  val label = {
    var l := Nil
    repeat(4, fn () {
      l := Cons(".L." ++ unique().show(), l)
    })
    l.reverse().vector()
  }

  val smc = [
    "  xor byte [" ++ label[0] ++ "], 0x0d",          // restore 0 : 52 ^ 0d = 5f
    label[0] ++ ":",
    "  db 0x52",
    "  sub byte [" ++ label[0] ++ "], 0x0d",          // hide 0    : 5f - 0d = 52

    "  sub byte [" ++ label[1] ++ "], 0x02",          // restore 1
    label[1] ++ ":",
    "  db 0x5a",

    "  add byte [" ++ label[2] ++ "], 0x01",          // restore 2
    "  sub byte [" ++ label[2] ++ " + 2], 0x02",
    "  xor byte [" ++ label[1] ++ "], 0x02",          // hide 1
    label[2] ++ ":",
    "  db 0x47, 0x89, 0x3a",
    "  xor word [" ++ label[2] ++ " + 1], 0x200",     // hide 2
    "  xor word [" ++ label[2] ++ "], 0x0f",

    "  add byte [" ++ label[3] ++ "], 0x10",          // restore 3
    label[3] ++ ":",
    "  db 0x47",
    "  xor byte [" ++ label[3] ++ "], 0x10",           // hide 3
  ]
  println(smc.join("\n"))


  // println(
  //   "  pop rdi\n" ++
  //   "  pop rax\n" ++
  //   "  mov [rax], rdi\n" ++
  //   "  push rdi"
  // )
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
        Just(Typ(TyArray)) -> {}

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
        Just(Typ(TyArray)) -> {}

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
      val label = {
        var l := Nil
        repeat(2, fn () {
          l := Cons(".L." ++ unique().show(), l)
        })
        l.reverse().vector()
      }
      val smc = [
        "  xor dword [" ++ label[0] ++ "], 0x98cdcd98",
        label[0] ++ ":",
        "  db 0xc0",                                      // original 58
        label[1] ++ ":",
        "  db 0x85, 0x48, 0x58",                          // original 48 85 c0
        "  pushf",
        "  add dword [" ++ label[0] ++ "], -0x683cc298",
        "  popf",

      ]
      println(smc.join("\n"))

      // println(
      //   "  pop rax\n" ++
      //   "  test rax, rax"
      // )

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
      val label = {
        var l := Nil
        repeat(5, fn () {
          l := Cons(".L." ++ unique().show(), l)
        })
        l.reverse().vector()
      }

      val smc = [
        "  xor byte [" ++ label[0] ++ "], 0x60",          // restore 0  : 34 ^ 60 = 54
        label[0] ++ ":",
        "  db 0x34",                                      // original   : 54 (push rsp)
        "  sub byte [" ++ label[0] ++ "], 0x20",          // hide 0     : 54 - 20 = 34

        "  add word [" ++ label[1] ++ " + 1], 0x1020",    // restore 1
        "  jmp " ++ label[1],
        label[1] ++ ":",
        "  db 0xff, 0x14, 0x14",                          // original   : ff 34 24 (push qword [rsp])
        "  xor byte [" ++ label[1] ++ " + 2], 0x30",      // hide 1
        "  xor byte [" ++ label[1] ++ " + 1], 0x20",

        "  xor dword [" ++ label[2] ++"], 0xb86767b8",    // restore 2
        label[2] ++ ":",
        "  db 0xf0, 0xe4, 0x83, 0x48",                    // original   : 48 83 e4 f0
        "  sub dword [" ++ label[2] ++ "], 0xa8609e58",   // hide 2

        "  call " ++ fcname,

        "  add byte [" ++ label[3] ++ "], 0x08",          // restore 3
        "  add byte [" ++ label[3] ++ " + 3], 0x04",
        label[3] ++ ":",
        "  db 0x40, 0x8b, 0x64, 0x20, 0x08",              // original   : 48 8b 64 24 08
        "  xor dword [" ++ label[3] ++ "], 0x4000008",    // hide 3

        "  add byte [" ++ label[4] ++ "], 0x20",          // restore 4
        label[4] ++ ":",
        "  db 0x30",
        "  sub byte [" ++ label[4] ++ "], 0x20",          // hide 4
      ]
      println(smc.join("\n"))

      // println(
      //   "  push rsp\n" ++
      //   "  push qword [rsp]\n" ++
      //   "  and rsp, -0x10\n" ++
      //   "  call " ++ fcname ++ "\n" ++
      //   "  mov rsp, [rsp+0x8]\n" ++
      //   "  push rax"
      // )
    }

    Node(NdReturn, lhs = Just(lhs)) -> {
      gen(lhs)

      // Pop the stored result.
      val label = {
        var l := Nil
        repeat(2, fn () {
          l := Cons(".L." ++ unique().show(), l)
        })
        l.reverse().vector()
      }
      val smc = [
        "  add byte [" ++ label[0] ++ "], 0x14",
        label[0] ++ ":",
        "  db 0x44",                                      // original 0x58
        "  xor byte [" ++ label[0] ++ "], 0x1c",
        "  jmp .L.return." ++ (!func-name).unjust()
      ]
      println(smc.join("\n"))

      // println(
      //   "  pop rax\n" ++
      //   "  jmp .L.return." ++ (!func-name).unjust()
      // )
    }

    Node(kind, ty = Just(typ), lhs = Just(lhs), rhs = Just(rhs)) -> {
      gen(lhs)
      gen(rhs)

      val label = {
        var l := Nil
        repeat(2, fn () {
          l := Cons(".L." ++ unique().show(), l)
        })
        l.reverse().vector()
      }

      val smc = [
        "  sub byte [" ++ label[0] ++ "], 0x20",
        label[0] ++ ":",
        "  db 0x7f",                                      // original 5f
        "  xor byte [" ++ label[0] ++ "], 0x20",

        "  xor byte [" ++ label[1] ++ "], 0x08",
        label[1] ++ ":",
        "  db 0x50",                                      // original 58
        "  sub byte [" ++ label[1] ++ "], 0x08",
      ]
      println(smc.join("\n"))

      // println(
      //   "  pop rdi\n" ++ // rechte Seite
      //   "  pop rax"      // linke Seite
      // );

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

        NdLe -> {
          val label = {
            var l := Nil
            repeat(3, fn () {
              l := Cons(".L." ++ unique().show(), l)
            })
            l.reverse().vector()
          }

          val smc = [
            "  cmp rax, rdi",
            "  setle al",

            "  xor dword [" ++ label[2] ++ "], 0x88b9b988",
            label[2] ++ ":",
            "  db 0xc0, 0xb6, 0x0f, 0x48",
            "  sub dword [" ++ label[2] ++ "], 0x78a65888",
            "  db 0x48, 0x0f, 0xb6, 0xc0",

          ]
          println(smc.join("\n"))

          // println(
          //   "  cmp rax, rdi\n" ++
          //   "  setle al\n" ++
          //   "  movzx rax, al"
          // )
        }

        _ -> {}
      }

      // Store the result
      val label = {
        var l := Nil
        repeat(1, fn () {
          l := Cons(".L." ++ unique().show(), l)
        })
        l.reverse().vector()
      }

      val smc = [
        "  add byte [" ++ label[0] ++ "], -0x7c",
        label[0] ++ ":",
        "  db 0xcc",                                      // original 50
        "  xor byte [" ++ label[0] ++ "], 0x9c",
      ]
      println(smc.join("\n"))
      // println("  push rax")
    }

    _ -> {}
  }
}

public fun codegen( prog : list<funktion> ) {
  val extern-func-names = (!used-func-names).filter(fn (uname) {
    !(!defined-func-names).find(fn (dname) { dname == uname }).bool()
  })

  val constructor-label = "start"
  val destructor-label = "fini"

  println(
    "default rel\n" ++
    "section .smc alloc write exec align=16"
  )

  // Extern names
  if (!extern-func-names.is-empty())
  then println("extern " ++ extern-func-names.join(","))

  // Constructor
  val label = {
    var l := Nil
    repeat(2, fn () {
      l := Cons(".L." ++ unique().show(), l)
    })
    l.reverse().vector()
  }
  val smc = [
    "global " ++ constructor-label,
    constructor-label ++ ":",
    "  lea rax, [rel " ++ destructor-label ++ "]",

    "  xor byte [" ++ label[0] ++ "], 0x9c",
    label[0] ++ ":",
    "  db 0xcc",                                           // original 0x50
    "  sub byte [" ++ label[0] ++ "], -0x7c",

    " jmp main",
  ]
  println(smc.join("\n"))

  // println(
  //   "global " ++ constructor-label ++ "\n" ++
  //   constructor-label ++ ":" ++ "\n" ++
  //   "  lea rax, [rel " ++ destructor-label ++ "]\n" ++
  //   "  push rax\n" ++
  //   "  jmp main"
  // )

  prog.foreach(fn (f) {
    println(
      f.name ++ ":"
    )
    func-name := Just(f.name)

    // Prologue
    val label = {
      var l := Nil
      repeat(3, fn () {
        l := Cons(".L." ++ unique().show(), l)
      })
      l.reverse().vector()
    }
    val smc = [
      "  xor byte [" ++ label[0] ++ "], 0x11",
      label[0] ++ ":",
      "  db 0x44",                                        // original 55
      "  sub byte [" ++ label[0] ++ "], 0x11",

      "  xor word [" ++ label[1] ++ " + 1], 0x6c6c",
      label[1] ++ ":",
      "  db 0x48, 0xe5, 0x89",                            // original 48 89 e5
      "  add word [" ++ label[1] ++ " + 1], -0x5ba4",
    ]
    println(smc.join("\n"))

    // println(
    //   "  push rbp\n" ++
    //   "  mov rbp, rsp"
    // )
    if (f.stacksize != 0) {
      println(
        "  sub rsp, " ++ f.stacksize.show()
      )
    }

    // Push arguments to the stack
    f.params.reverse().foreach-indexed(fn (i, v) {
      println(
        "  mov [rbp - " ++ v.offset.unjust().show() ++ "], " ++ arg-reg[i].unjust()
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

  // Destructor
  // The result has been popped into rax,
  // so move it to rdi to make it the program exit code.
  // Then pass 60 to rax to invoke sys_exit
  println(
    destructor-label ++ ":\n" ++
    "  mov rdi, rax\n" ++
    "  mov rax, 60\n" ++
    "  syscall"
  )
}
