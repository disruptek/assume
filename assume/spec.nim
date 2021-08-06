import std/macros

type
  AssError* = ValueError
  AssNode* = distinct NimNode
  NodeLike* = Assnode or NimNode

template dot*(a, b: NimNode): NimNode =
  ## for constructing foo.bar
  newDotExpr(a, b)

template dot*(a: NimNode; b: string): NimNode =
  ## for constructing `.`(foo, "bar")
  dot(a, ident(b))

template eq*(a, b: NimNode): NimNode =
  ## for constructing foo=bar in a call
  nnkExprEqExpr.newNimNode(a).add(a).add(b)

template eq*(a: string; b: NimNode): NimNode =
  ## for constructing foo=bar in a call
  eq(ident(a), b)

template colon*(a, b: NimNode): NimNode =
  ## for constructing foo: bar in a ctor
  nnkExprColonExpr.newNimNode(a).add(a).add(b)

template colon*(a: string; b: NimNode): NimNode =
  ## for constructing foo: bar in a ctor
  colon(ident(a), b)

template colon*(a: string | NimNode; b: string | int): NimNode =
  ## for constructing foo: bar in a ctor
  colon(a, newLit(b))

template sq*(a: NimNode): NimNode =
  ## for [foo]
  nnkBracket.newNimNode(a)

template sq*(a, b: NimNode): NimNode =
  ## for foo[bar]
  nnkBracketExpr.newNimNode(a).add(a).add(b)

template sq*(a: NimNode; b: SomeInteger) =
  ## for foo[5]
  sq(a, newLit b)

proc isType*(n: NimNode): bool =
  ## `true` if the node is a type symbol
  n.kind == nnkSym and n.symKind == nskType

proc isType*(n: NimNode; s: string): bool =
  ## `true` if the node is the named type
  n.isType and n.strVal == s

proc isGenericOf*(n: NimNode; s: string): bool =
  ## `true` if the type is a generic of the named type
  if n.kind == nnkBracketExpr:
    if n.len > 0:
      return n[0].isType s

proc errorAst*(s: string, info: NimNode = nil): NimNode =
  ## produce {.error: s.} in order to embed errors in the ast
  ##
  ## optionally take a node to set the error line information
  result =
    nnkPragma.newTree:
      ident"error".newColonExpr: newLit s
  if not info.isNil:
    result[0].copyLineInfo info

proc errorAst*(n: NimNode; s = "creepy ast"): NimNode =
  ## embed an error with a message,
  ## the line info is copied from the node
  errorAst(s & ":\n" & treeRepr(n) & "\n", n)

proc inject*(n: NimNode): NimNode =
  ## sym -> sym {.inject.}   also handles identdefs, sections, idents, etc.
  case n.kind
  of nnkSym, nnkIdent:
    nnkPragmaExpr.newTree n:
      nnkPragma.newTree ident"inject"
  of nnkIdentDefs:
    nnkIdentDefs.newTree(inject n[0]).add n[1..^1]
  of nnkVarSection, nnkLetSection:
    if n.len != 1:
      n.errorAst "gimme a section with a single variable"
    else:
      n.kind.newTree(inject n[0])
  else:
    n.errorAst "unsupported form for injection"

type
  NodeFilter* = proc(n: NimNode): NimNode

proc filter*(f: NodeFilter; n: NimNode): NimNode =
  ## rewrites a node and its children by passing each node to the filter;
  ## if the filter yields nil, the node is simply copied.  otherwise, the
  ## node is replaced.
  result = f(n)
  if result.isNil:
    result = copyNimNode n
    for kid in items(n):
      result.add filter(f, kid)

macro enumValuesAsArray*(e: typed): untyped =
  ## given an enum type, render an array of its symbol fields
  nnkBracket.newNimNode(e).add:
    e.getType[1][1..^1]

macro enumValuesAsSet*(e: typed): untyped =
  ## given an enum type, render a set of its symbol fields
  nnkCurly.newNimNode(e).add:
    e.getType[1][1..^1]

macro enumValuesAsSetOfOrds*(e: typed): untyped =
  ## given an enum type, render a set of its integer values
  result = nnkCurly.newNimNode(e)
  for n in 1 ..< e.getType[1].len:
    result.add:
      newLit e.getType[1][n].intVal

macro enumValueAsString*(e: enum): string =
  ## produce the literal enum value as opposed to its stringification
  runnableExamples:
    type E = enum One = "A", Two = "B"
    assert One.enumValueAsString == "One"
  for sym in (getTypeImpl e)[1..^1]:
    if sym.intVal == e.intVal:
      return newLit sym.strVal
  error "unexpected"

macro newTreeFrom*(kind: NimNodeKind; n: NimNode; body: untyped): NimNode =
  ## use the kind and `n` node to create a new tree;
  ## add the statements in the body and return this node
  var tree = genSym(nskVar, "tree")
  result = newStmtList:
    newVarStmt tree:                           # var tree =
      bindSym"newNimNode".newCall(kind, n)     # newNimNode(kind, n)
  for child in body.items:                     # for child in body:
    add result:
      bindSym"add".newCall tree:               #   add tree:
        child                                  #     child statement
  add result:                                  # tree
    tree

proc desym*(n: NimNode): NimNode =
  ## replace a symbol with an identifier of the same name
  if not n.isNil and n.kind == nnkSym:
    result = ident(repr n)  # use repr to properly desym genSym'd symbols
    result.copyLineInfo n   # don't throw away line info!
  else:
    result = n
