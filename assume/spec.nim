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

type
  NodeFilter* = proc(n: NimNode): NimNode

proc filter*(n: NimNode; f: NodeFilter): NimNode =
  ## rewrites a node and its children by passing each node to the filter;
  ## if the filter yields nil, the node is simply copied.  otherwise, the
  ## node is replaced.
  result = f(n)
  if result.isNil:
    result = copyNimNode n
    for kid in items(n):
      result.add filter(kid, f)
