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