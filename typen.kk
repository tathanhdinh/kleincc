module typen

import kleincc

public fun is-integer( ty : typ ) {
  match (ty.kind) {
    TyInt -> True
    _ -> False
  }
}

public fun add-type( node : node ) : <div, exn> node {
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

  val node-ty = match (node.kind) {
    NdPtrAdd -> typed-lhs.unjust().ty.unjust()
    NdPtrSub -> typed-lhs.unjust().ty.unjust()
    NdAssign -> typed-lhs.unjust().ty.unjust()
    NdAddr -> Typ(TyPtr, typed-lhs.unjust().ty)
    NdDeref -> match (typed-lhs.unjust().ty.unjust()) {
      Typ(TyPtr, base) -> base.unjust()
      _ -> Typ(TyInt)
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
