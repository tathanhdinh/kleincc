public effect control continue<a>() : a

public fun unjust-or-continue( m : maybe<a> ) : continue a {
  match (m) {
    Just(v) -> v
    _ -> continue()
  }
}

public fun just-or-continue( m : maybe<a> ) : continue maybe<a> {
  match (m) {
    Nothing -> continue()
    _ -> m
  }
}

public fun unjust-or( m : maybe<a>, action : () -> e a) : e a {
  match (m) {
    Just(v) -> v
    _ -> action()
  }
}

// Reports an error
public fun error( msg : string ) : exn a {
  throw("error: " ++ msg)
}

// Report an error with location information.
public fun error-at( literal : sslice, msg : string ) : exn a {
  val before-ltr = literal.before()
  val input = before-ltr.before().after()
  val error-msg = input.string() ++ "\n" ++ " ".repeat(before-ltr.count()) ++ "^ error: " ++ msg
  throw(error-msg)
}
