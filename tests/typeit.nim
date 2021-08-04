import std/macros

import balls

import assume/typeit

type
  N = int
  S = string
  refS = ref S
  O = object
    n: N
    s: S
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
    typeIt 3.N, {}:
      check $it == "3"

  block:
    ## a more complex value
    var found: seq[string]
    typeIt O(n: 2, s: "two"), {}:
      found.add $it
    check found == @["2", "two", "a ref S", "a ref O"]

  block:
    ## type alias of an integer
    typeIt N, {}:
      check $it == "N"

  block:
    ## fields of an object
    var found: seq[string]
    typeIt O, {}:
      found.add $it
    check found == @["N", "S", "refS", "ref O"]

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
    skip"case objects not yet supported":
      var found: seq[string]
      typeIt I, {}:
        found.add $it
      check found == @["true", "3.4", "false", "5.3"]
