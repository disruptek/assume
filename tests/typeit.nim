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

proc main =
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

    block:
      ## typeit all fields
      var
        i = I()
        count = 0
      typeit(i, {titAllFields}):
        inc count
      assert count == 6

    block:
      ## typeit all fields / isaccessible
      var
        p = P()
        accessible = 0
        fieldCount = 0
        res: seq[string]
      typeit(p, {titAllFields}):
        if isAccessible(it):
          inc accessible
          res.add $it
        inc fieldCount
      check res == @["false", "0"]
      check accessible == 2
      check fieldCount == 3

    block:
      ## isAccessible object test
      var o = O()
      check isAccessible(o.n)
      check isAccessible(o.s)
      check isAccessible(o.rs)
      check isAccessible(o.ro)

    block:
      ## isAccessible variant test
      var p = P()
      check isAccessible(p.m)
      check isAccessible(p.x)
      check not isAccessible(p.y)
      p = P(m: true)
      check isAccessible(p.m)
      check not isAccessible(p.x)
      check isAccessible(p.y)

    block:
      ## isAccessible inheritance variant test
      var i = I()
      check isAccessible(i.m)
      check isAccessible(i.k)
      check not isAccessible(i.y)
      check not isAccessible(i.a)
      check isAccessible(i.b)

    block:
      ## Ensure same line fields inside variants work
      type A = object
        case b: bool
        of true: f: float
        else: discard
      var a = A()
      typeIt(a, {titAllFields}):
        when it is bool:
          check astToStr(it) == "a.b"
        elif it is float:
          check astToStr(it) == "a.f"

main()
