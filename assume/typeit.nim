import std/macros

import assume/spec

type
  titOption* = enum          ## type iteration options
    titNoParents = "ignore parent types via inheritance"
    titNoRefs    = "ignore reference types"

  Mode = enum Types, Values  ## felt cute might delete later idk

  Context = object           ## just carries options around
    mode: Mode
    options: set[titOption]

proc iterate(c: Context; o, tipe, body: NimNode): NimNode

proc invoke(c: Context; body, input: NimNode): NimNode =
  ## called to output the user's supplied body with the `it` ident swapped

  # define a filter that swaps an `it` identifier with the input node
  proc swapIt(n: NimNode): NimNode =
    if n.kind == nnkIdent and n.strVal == "it":
      return input

  # the result is the provided block with the `it` swapped
  nnkBlockStmt.newTree newEmptyNode():
    filter(body, swapIt)

proc eachField(c: Context; o, tipe, body: NimNode): NimNode =
  ## invoke for each field in `tipe`
  result = newStmtList()
  for index, node in tipe.pairs:
    case node.kind

    # normal object field list
    of nnkRecList:
      result.add:
        c.eachField(o, node, body)

    # single definition
    of nnkIdentDefs:
      result.add:
        c.invoke body: o.dot node[0]

    # variant object
    of nnkRecCase:
      if c.mode == Types:
        result.add:
          o.errorAst "variant objects may not be iterated"
      else:
        # invoke the discriminator first, and then
        let kind = node[0][0]
        result.insert 0:
          c.invoke body: o.dot kind

        # add a case statement to invoke the proper branches.
        let kase = nnkCaseStmt.newTree(o.dot kind)
        for branch in node[1 .. ^1]:                # skip discriminator
          let clone = copyNimNode branch
          case branch.kind
          of nnkOfBranch:
            for expr in branch[0 .. ^2]:
              clone.add expr
            clone.add:
              c.eachField(o, branch.last, body)
          of nnkElse:
            clone.add:
              c.eachField(o, branch.last, body)
          else:
            result.add:
              node.errorAst "unrecognized ast"
          kase.add clone
        result.add kase

    else:
      # it's a tuple; invoke on each field by index
      result.add:
        c.invoke body: o.sq index

proc forTuple(c: Context; o, tipe, body: NimNode): NimNode =
  ## invoke for each field in `tipe`
  c.eachField(o, tipe, body)

proc forObject(c: Context; o, tipe, body: NimNode): NimNode =
  ## invoke for each field in `tipe`
  result = newStmtList()
  case tipe.kind
  of nnkEmpty:
    discard
  of nnkOfInherit:
    if titNoParents notin c.options:
      # we need to traverse the parent object type's fields
      result.add:
        c.forObject(o, getTypeImpl tipe.last, body)
  of nnkRefTy:
    if titNoRefs notin c.options:
      # unwrap a ref type modifier
      result.add:
        c.forObject(o, getTypeImpl tipe.last, body)
  of nnkObjectTy:
    # first see about traversing the parent object's fields
    result.add:
      c.forObject(o, tipe[1], body)

    # now we can traverse the records in this object
    let records = tipe[2]
    case records.kind
    of nnkEmpty:
      discard
    of nnkRecList:
      result.add:
        c.eachField(o, records, body)
    else:
      result.add:
        tipe.errorAst "unrecognized object type ast"
  else:
    # creepy ast
    result.add:
      tipe.errorAst "unrecognized object type ast"

macro typeIt*(o: typed; options: static[set[titOption]];
              body: untyped): untyped =

  ## Iterate over the symbol, `o`.

  ## If it's a value, `it` in the body will represent that value if it's a
  ## simple type, or the component parts of the value if it has a complex
  ## type.

  ## If it's a type, `it` in the body will represent the type if it's a
  ## simple type, or the component parts of the type if it's a complex
  ## type.

  let tipe = getTypeImpl o
  result =
    case tipe.kind
    of nnkSym, nnkTupleTy, nnkObjectTy, nnkTupleConstr, nnkObjConstr:
      # the input is a value
      var c = Context(mode: Values, options: options)
      c.iterate(o, tipe, body)
    of nnkBracketExpr:
      # the input is a type
      var c = Context(mode: Types, options: options)
      c.iterate(o, tipe.last, body)
    else:
      # i dunno wtf the input is
      o.errorAst "unexpected " & $tipe.kind

proc iterate(c: Context; o, tipe, body: NimNode): NimNode =
  ## entry point for iteration
  let tipe = getTypeImpl tipe
  case tipe.kind
  of nnkDistinctTy:
    # unwrap a distinct
    newCall(bindSym"typeIt", newCall(tipe[0], o))
  of nnkObjectTy, nnkObjConstr:
    # looks like an object
    c.forObject(o, tipe, body)
  of nnkTupleTy, nnkTupleConstr:
    # looks like a tuple
    c.forTuple(o, o, body)
  else:
    # looks like a primitive
    c.invoke body: o
