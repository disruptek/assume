import std/macros

import balls

import assume/typeit

type
  refS = ref string
  O = object
    n: int
    s: string
    rs: refS
    ro: ref O
  P = object of RootObj
    case m: bool
    of false:
      x: int
    else:
      y: float
  I = object of P
    case k: bool
    of true:
      a: int
    of false:
      b: float

proc `$`(s: refS): string = "a ref S"
proc `$`(o: ref O): string = "a ref O"

suite "type iterator":
  block:
    ## a simple value
    type N = int
    typeIt 3.N, {}:
      check $it == "3"

  block:
    ## a more complex value
    var found: seq[string]
    typeIt O(n: 2, s: "two"), {}:
      found.add $it
    check found == @["2", "two", "a ref S", "a ref O"]

  block:
    ## a more complex value without refs
    var found: seq[string]
    typeIt O(n: 2, s: "two"), {titNoRefs}:
      found.add $it
    check found == @["2", "two", "a ref S"]

  block:
    ## type alias of an integer
    type N = int
    typeIt N, {}:
      check $it == "N"

  block:
    ## bool type; it's gonna be important
    typeIt bool, {}:
      check $it == "bool"

  block:
    ## fields of an object
    var found: seq[string]
    typeIt O, {}:
      found.add $it
    check found == @["int", "string", "refS", "ref O"]

  block:
    ## sequence value
    typeIt @[1, 1, 2, 3, 5], {}:
      check $it == "@[1, 1, 2, 3, 5]"

  block:
    ## value inheritance
    var found: seq[string]
    typeIt I(m: true, y: 3.4, k: false, b: 5.3), {}:
      found.add $it
    check found == @["true", "3.4", "false", "5.3"]

  block:
    ## type inheritance
    var found: seq[string]
    typeIt I(m: true, y: 3.4, k: false, b: 5.3), {}:
      found.add $it
    check found == @["true", "3.4", "false", "5.3"]

  block:
    ## unwrapped distinct values
    type D = distinct bool
    proc `$`(d: D): string {.used.} = "d-ish"
    typeIt true.D, {}:
      check $it == "true"

  block:
    ## unwrapped distinct types
    type D = distinct bool
    proc `$`(d: D): string {.used.} = "d-ish"
    typeIt D, {}:
      check $it == "bool"

  block:
    ## opaque distinct values
    type D = distinct bool
    proc `$`(d: D): string {.used.} = "d-ish"
    typeIt true.D, {titDistincts}:
      check $it == "d-ish"

  block:
    ## opaque distinct types
    type D = distinct bool
    proc `$`(d: D): string {.used.} = "d-ish"
    typeIt D, {titDistincts}:
      check $it == "D"

  block:
    ## opaque type aliases
    type N = int
    typeIt N, {}:
      check $it == "N"

  block:
    ## unwrapped type aliases
    type N = int
    typeIt N, {titNoAliases}:
      check $it == "int"

  block:
    ## ref object values
    type R = ref object
      x: int
      y: float
    var found: seq[string]
    typeIt R(x: 4, y: 1.2), {}:
      found.add $it
    check found == @["4", "1.2"]

  block:
    ## ref object types
    type R = ref object
      x: int
      y: float
    var found: seq[string]
    typeIt R, {}:
      found.add $it
    check found == @["int", "float"]
