### Idle thoughts

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
  - The return type and effect of `get-argv` is `ndet list<string>` where `ndet` represents the *non-deterministic effect* (still do not understand what it is). The return type of `main` must include also this effect.
  - The return type and effect of `println` may be `console ()` (I guess, since it prints something to the console). The effect of `main` then `<console, ndet>`.
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

- 18/04/2021 (commits: [88fd930](https://github.com/tathanhdinh/kleincc/commit/88fd930dc23f2b6f74d42ce3888e2b35f3d106e1))
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
- 02/05/2021 (commits: [dd943c5](https://github.com/tathanhdinh/kleincc/commit/dd943c565bd047860341710114161dbc169b8e52))
    - In `chibicc`, tokens are stored in a *linked list*:
      ```c
      struct Token {
        TokenKind kind; // Token kind
        Token *next;    // Next token
        long val;       // If kind is TK_NUM, its value
        char *str;      // Token string
      };

      Token *token;    // Pointer to the first token
      ```
      where `next` pointer points to the next element. With `koka`, I simply use `list<token>` where
      ```koka
      struct token {
        kind : token-kind
        value : maybe<int> = Nothing
        literal : maybe<sslice> = Nothing
      }
      ```

    - The function `error` disrupts the control flow (i.e. shows an error message then exits the program), a similar behavior can be obtained by [throwing](https://github.com/koka-lang/koka/blob/df177d5663dcaefb4c087458e6b6e6f5ae9e2a31/lib/std/core.kk#L2483) exceptions
      ```koka
      fun error( msg : string ) : exn a {
        throw("error: " ++ msg)
      }
      ```
      where `exn` is actually an [effect](https://github.com/koka-lang/koka/blob/df177d5663dcaefb4c087458e6b6e6f5ae9e2a31/lib/std/core.kk#L2448).

    - [`while`](https://github.com/koka-lang/koka/blob/50d66e1aa77cc2d5d9371c95ce79d7e155de3a86/lib/std/core.kk#L2715) and [`try`](https://github.com/koka-lang/koka/blob/50d66e1aa77cc2d5d9371c95ce79d7e155de3a86/lib/std/core.kk#L2497) are just functions. The trick used in `tokenize` is that the computation of predicate actually does everything, the action (i.e. loop body) is empty.

    - **Side effect**: I had very vague ideas about why side effect should be seriously considered (as what people usually do with types). Why it shouldn't be "included" in some type?

      Sometimes, how an expression is computed is indeed important: *...a type describes what an expression computes, an effect describes how an expression computes...*[1]. Let's consider:
      ```c
      int f() {
        printf("hello world");
        return 7;
      }
        ```
      without effect `f : () -> char`, but `f` cannot be called in a program which has no access to some console. Worse, the type of `f` says nothing about that, even knowing the type of `f`, we sill cannot sure how to use it correctly: *accessing a console* is a static constraint which has not been described in type.

      Let's consider another version of `f`:
      ```c
      int f() {
        may throws some exception;
        return 7;
      }
      ```
      with a naive idea that we "include" *may throw exception* in the return type, e.g. using a pair `(exn, int)`. Any simple expression as `i + f()` (where `i` is some `int`) is not well typed anymore, for a bad reason. Since this is not the expression which takes care the exception: when the exception occurs, the control is passed to somewhere.

      Some languages eliminate completely exceptions (e.g. Rust), any error handler must be local, then such a simple expression like `i + f()` must be rewritten (may be this is a reason for which error handling in Rust is quite painful, IMHO).

      So the naive idea of composing type with effect does not work well, effect is different (it probably needs another treatment).

- 03/05/2021 (commits: [])
    - I did not find the function which returns the owner (of type `string`) of a string slice `s` (of type `sslice`) then I used a trick `s.before().before().after().string()`: the first `before` returns the slice before `s` (in the owner), so the second `before` returns simply the empty slice at the beginning of the owner string, then the last `after` return the slice of the entire string.

### References
- [1] David K. Gifford, Pierre Jouvelot, Mark A. Sheldon, James W. O'Toole. Report on the FX-91 Programming Language.