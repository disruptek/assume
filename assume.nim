import std/strutils
import std/genasts
import std/macros

type
  AssError* = ValueError
  AssNode = distinct NimNode
  NodeLike = Assnode or NimNode

proc isNil*(a: AssNode): bool {.borrow.}
proc kind*(a: AssNode): NimNodeKind {.borrow.}

template badass(n: NodeLike; s: string): untyped =
  raise AssError.newException:
    "bad assumption for $# node: $#" %
      [ if n.isNil: "nil" else: $n.kind, s ]

macro twoway(n: typed): untyped =
  n.expectKind nnkConverterDef
  var n = n
  while n.len > 7: n.del 7
  result = newStmtList()
  result.add:
    copyNimTree n
  let
    takes = n.params[1][1] # type
    returns = n.params[0]
  result.add:
    genAst(takes, returns):
      converter `from returns to takes`*(n: returns): takes =
        takes n

template bitch(item: untyped; body: untyped): untyped =
  if item.isNil:
    item.badass "nice try, jackass"
  else:
    body

type
  AnIdentDefs* = distinct AssNode

proc `[]=`(a: var AssNode; index: int; value: NimNode) =
  ## unexported assignment borrow, basically
  bitch a:
    bitch value:
      NimNode(a)[index] = value

proc `[]`(a: AssNode; index: int): NimNode =
  ## unexported borrow, basically
  bitch a:
    result = NimNode(a)[index]

proc add(a: var AssNode; value: NimNode) =
  ## unexported borrow, basically
  bitch a:
    bitch value:
      discard NimNode(a).add value

proc len*(a: AssNode): int =
  bitch a:
    result = NimNode(a).len

template borrows(t: typedesc) =
  proc `[]`(a: t; index: int): NimNode {.borrow.}
  proc `[]=`(a: var t; index: int; value: NimNode) {.borrow.}
  proc add(a: var t; value: NimNode) {.borrow.}
  proc len*(a: t): int {.borrow.}

borrows AnIdentDefs

converter toAnIdentDefs*(n: NimNode): AnIdentDefs {.twoway.} =
  if n.isNil:
    n.badass "cowardly refusing to convert nil to IdentDefs"
  else:
    case n.kind
    of nnkVarSection, nnkLetSection:
      case n.len
      of 0: n.badass "unable to invent IdentDefs from empty var/let section"
      of 1: result = AnIdentDefs n.last
      else: n.badass "i won't guess at which identdefs you are interested in"
    of nnkIdentDefs:
      result = AnIdentDefs n
    else:
      n.badass "unimplemented"

  while result.len < 3:
    result.add newEmptyNode()
  result[1] =
    if result[1].kind == nnkEmpty:
      if result[2].kind == nnkEmpty:
        n.badass "missing initialization needed for type inference"
      else:
        getTypeImpl result[2]
    else:
      result[1]

iterator asIdentDefs*(n: AnIdentDefs): AnIdentDefs = yield n

iterator asIdentDefs*(n: NimNode): AnIdentDefs =
  case n.kind
  of nnkVarSection, nnkLetSection:
    for defs in n.items:
      for each in (toAnIdentDefs defs).asIdentDefs:
        yield each
  of nnkIdentDefs:
    for each in (toAnIdentDefs n).asIdentDefs:
      yield each
  else:
    n.badass "unsupported for identdefs iteration"
