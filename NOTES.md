## Programming notes

- 15/04/2021 (commits: [f8954de](https://github.com/tathanhdinh/kleincc/commit/fd4ffdd447f1aae4288cb434549cee6bf492727a))
  - To get the "unprocessed" command line (i.e. the corresponding of C's `argv`), we can use the function [`get-argv`](https://koka-lang.github.io/koka/doc/std_os_env-source.html#get_argv) which is in the module `std/os/env`.
    ```koka
    import std/os/env

    fn main() {
	    ...
	    val argv = get-argv()
	    ...
    }
    ```
  - The return type of `get-argv` is `ndet list<string>` where `ndet` represents the *non-deterministic effect* (still do not understand what it is). The return type of `main` must include also this effect.
  - The return type of `println` may be `console ()` (I guess, since it prints something to the console). The effect of `main` then `<console, ndet>`.
  - The "early" returns in the evaluation of `input` are really for returning early from `main` (do not figure out yet how the effects are combined and propagated).
    ```koka
    val input = match (get-argv()) {
      Cons(prog, args) -> {
        match (args) {
          Cons(input, Nil) -> input
          _ -> {
            ...
            return 1
          }
        }
      }

      _ -> return 1
    }
    ```

- 18/04/2021 (commits: [82f8d42](https://github.com/tathanhdinh/kleincc/commit/82f8d42c1c550e55cd15d85c7de6dae105e96239))
    - Dot notation: a function `f(a, b, c,...)` has a syntactic sugar as `a.f(b, c...)`. The iteration over a list can be done by `foreach` which is actually a [function](https://github.com/koka-lang/koka/blob/df177d5663dcaefb4c087458e6b6e6f5ae9e2a31/lib/std/core.kk#L677), like that:
      ```koka
      input.split("+").foreach fn(term) {
        // do something with term
        ...
      }
      ```

    - `with` statement seems just a syntactic sugar: the statements following `with` are put into a lambda. For example
      ```koka
      with term = terms.foreach
      println("  sub rax" ++ term)
      ```
      is equivalent to
      ```
      terms.foreach fn(term) {
        println("  sub rax" ++ term)
      }
      ```
