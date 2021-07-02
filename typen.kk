module typen

import kleincc
import tokenize

public fun is-integer( ty : typ ) {
  match (ty) {
    Typ(TyInt) -> True

    _ -> False
  }
}

public fun add-type( node : node ) {
  if (node.ty.bool()) then return node

  // typisieren
  val typed-lhs = node.lhs.map(add-type)
  val typed-rhs = node.rhs.map(add-type)

  val typed-wenn = node.wenn.map(add-type)
  val typed-dann = node.dann.map(add-type)
  val typed-sonst = node.sonst.map(add-type)
  val typed-init = node.init.map(add-type)
  val typed-inc = node.inc.map(add-type)

  val typed-body = node.body.map(fn (ns) {
    ns.map(add-type)
  })

  val typed-fcargs = node.fcargs.map(fn (args) {
    args.map(add-type)
  })

  val lhs-ty = fn () { typed-lhs.unjust().ty.unjust() }
  val node-ty = match (node.kind) {
    NdPtrAdd -> lhs-ty()

    NdPtrSub -> lhs-ty()

    NdAssign -> lhs-ty()

    NdVar -> {

      // val node-var = node.variable.unjust()
      // val node-var-deref : variable = !node-var
      // node-var.ty.unjust()

      // node-var-deref.ty.unjust()
      (!node.variable.unjust()).ty.unjust()
    }

    NdAddr -> {
      val ty = lhs-ty()
      match (ty) {
        Typ(TyArray, _, base) -> Typ(TyPtr, base = base)

        _ -> Typ(TyPtr, base = Just(ty))
      }
    }

    NdDeref -> {
      match (lhs-ty().base) {
        Just(ty) -> ty

        _ -> error-token(node.token, "invalid pointer dereference")
      }
    }

    _ -> Typ(TyInt)
  }

  node(
    ty = Just(node-ty), lhs = typed-lhs, rhs = typed-rhs,
    wenn = typed-wenn, dann = typed-dann, sonst = typed-sonst,
    init = typed-init, inc = typed-inc,
    body = typed-body, fcargs = typed-fcargs
  )
}
