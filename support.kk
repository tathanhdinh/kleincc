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
