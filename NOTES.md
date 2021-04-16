## Programming diary

- 15/04/2021 ([commit 0](https://github.com/tathanhdinh/kleincc/commit/fd4ffdd447f1aae4288cb434549cee6bf492727a))
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
  - The "early" returns in the evaluation of `input` are really for returning early from `main` (still do not understand how the effects are combined and propagated).
  ```koka
  val input = match (get-argv()) {
    Cons(prog, args) -> {
      match (args) {
        Cons(input, Nil) -> input
        _ -> { println(prog ++ ": invalid number of arguments"); return 1 }
      }
    }

    _ -> return 1
  }
  ```