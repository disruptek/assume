import std/strutils
import std/genasts
import std/macros

type
  AssError* = ValueError
  AssNode = distinct NimNode
  NodeLike = Assnode or NimNode

proc isNil*(a: AssNode): bool {.borrow.}
proc kind*(a: AssNode): NimNodeKind {.borrow.}
proc treeRepr*(a: AssNode): string {.borrow.}
proc repr*(a: AssNode): string {.borrow.}

template badass(n: NodeLike; s: string): untyped =
  if not n.isNil:
    debugEcho treeRepr(n)
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
  ## find the length of a node
  bitch a:
    result = NimNode(a).len

template borrows(t: typedesc) =
  proc `[]`(a: t; index: int): NimNode {.borrow, used.}
  proc `[]=`(a: var t; index: int; value: NimNode) {.borrow, used.}
  proc add(a: var t; value: NimNode) {.borrow, used.}
  proc len*(a: t): int {.borrow.}
  proc treeRepr(a: t): string {.borrow, used.}
  proc repr(a: t): string {.borrow, used.}

type
  AnIdentDefs* = distinct AssNode
  AnVarSection* = distinct AssNode
  AnLetSection* = distinct AssNode

borrows AnIdentDefs
borrows AnVarSection
borrows AnLetSection

template convertThingFrom(source: NimNode; body: untyped) {.dirty.} =
  ## attempt an automatic conversion
  if source.isNil:
    n.badass "cowardly refusing to convert from nil"
  else:
    body
  copyLineInfo(NimNode result, source)

proc add*(a: var AnLetSection | var AnVarSection; n: AnIdentDefs) =
  NimNode(a).add n.NimNode

converter toAnIdentDefs*(n: NimNode): AnIdentDefs {.twoway.} =
  convertThingFrom n:
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

converter toAnLetSection*(n: NimNode): AnLetSection {.twoway.} =
  convertThingFrom n:
    case n.kind
    of nnkVarSection:
      result = AnLetSection: nnkLetSection.newNimNode n
      for item in n.items:
        result.add: item.toAnIdentDefs
    of nnkLetSection:
      result = AnLetSection n
    of nnkIdentDefs:
      result = AnLetSection: nnkLetSection.newTree n
    else:
      n.badass "unimplemented"

converter toAnVarSection*(n: NimNode): AnVarSection {.twoway.} =
  convertThingFrom n:
    case n.kind
    of nnkLetSection:
      result = AnVarSection: nnkVarSection.newNimNode n
      for item in n.items:
        result.add: item.toAnIdentDefs
    of nnkVarSection:
      result = AnVarSection n
    of nnkIdentDefs:
      result = AnVarSection: nnkVarSection.newTree n
    else:
      n.badass "unimplemented"

iterator asIdentDefs*(n: AnIdentDefs): AnIdentDefs =
  ## iterate over the identdefs in an identdefs
  yield n

iterator asIdentDefs*(n: AnVarSection or AnLetSection): AnIdentDefs =
  ## iterate over the identdefs in a var|let section
  for defs in n.items:
    for each in (toAnIdentDefs defs).asIdentDefs:
      yield each

iterator asIdentDefs*(n: NimNode): AnIdentDefs =
  ## iterate over the identdefs in a rando node
  case n.kind
  of nnkVarSection:
    for each in (toAnVarSection n).asIdentDefs:
      yield each
  of nnkLetSection:
    for each in (toAnLetSection n).asIdentDefs:
      yield each
  of nnkIdentDefs:
    for each in (toAnIdentDefs n).asIdentDefs:
      yield each
  else:
    n.badass "unsupported for identdefs iteration"
