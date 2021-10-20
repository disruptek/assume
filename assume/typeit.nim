import std/macros except sameType

import assume/spec

type
  titOption* = enum          ## type iteration options
    titNoParents = "ignore parent types via inheritance"
    titNoRefs    = "ignore reference types"
    titNoAliases = "fully resolve type aliases"
    titDistincts = "treat distinct types as opaque"

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
    filter desym:
      filter(swapIt, body)

template guardRefs(c: Context; tipe: NimNode; body: untyped): untyped =
  ## a guard against ref type output according to user's options
  if titNoRefs notin c.options or tipe.kind != nnkRefTy:
    body
  else:
    newEmptyNode()

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
        c.guardRefs node[1]:
          c.invoke body: o.dot node[0]

    # variant object
    of nnkRecCase:
      case c.mode
      of Types:
        result.add:
          o.errorAst "variant objects may not be iterated"
      of Values:
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
    # unwrap a ref type modifier
    result.add:
      c.guardRefs getTypeImpl tipe.last:
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

  template iteration(m: Mode; obj, tipe: untyped): untyped =
    ## convenience
    var c = Context(mode: m, options: options)
    c.iterate(obj, tipe, body)

  let tipe = getTypeImpl o
  case tipe.kind
  of nnkSym, nnkTupleTy, nnkObjectTy, nnkTupleConstr, nnkObjConstr:
    # the input is a value
    Values.iteration(o, getTypeImpl tipe)
  of nnkRefTy:
    # let iterate unwrap a reference value
    Values.iteration(o, tipe)
  of nnkBracketExpr:
    # the input is a type
    Types.iteration(o, getTypeImpl tipe.last)
  of nnkDistinctTy:
    if titDistincts in options:
      # leave distincts opaque
      Types.iteration(o, getTypeImpl tipe[0])  # Types is good enough
    else:
      # unwrap distincts
      case o.kind
      of nnkConv:                                  # obviously, a value
        if o.len != 2:
          o.errorAst "unrecognized conversion ast"
        else:
          Values.iteration(o[1], getTypeImpl o[0])
      else:
        Types.iteration(o.last, o.last)            # must be a type
  else:
    # i dunno wtf the input is
    o.errorAst "unexpected " & $tipe.kind

proc iterate(c: Context; o, tipe, body: NimNode): NimNode =
  ## entry point for iteration
  case tipe.kind
  of nnkDistinctTy:
    if titDistincts in c.options:
      # treat distincts as opaque
      c.invoke body: o
    else:
      # unwrap a distinct
      let target =
        case c.mode
        of Types:
          # target the original type
          desym tipe.last   # nim bug: must desym
        of Values:
          # convert the value to the original type
          newCall(tipe.last, o)
      # issue a typeIt on the refined target
      newCall(bindSym"typeIt", target, newLit c.options, body)
  of nnkObjectTy, nnkObjConstr:
    # looks like an object
    c.forObject(o, tipe, body)
  of nnkTupleTy, nnkTupleConstr:
    # looks like a tuple
    c.forTuple(o, o, body)
  of nnkRefTy:
    c.guardRefs tipe:
      case c.mode
      of Types:       # "deref" the type
        c.iterate(getTypeImpl o, getTypeImpl tipe.last, body)
      of Values:      # deref the value
        c.iterate(newCall(ident"[]", o), getTypeImpl tipe.last, body)
  else:
    # looks like a primitive
    case c.mode
    of Types:
      var (o, tipe) = (o, tipe)
      if titNoAliases in c.options:
        while not sameType(o, tipe):
          o = tipe
          tipe = getType tipe
      c.guardRefs tipe:
        c.invoke body: desym o    # nim bug: must desym
    of Values:
      c.guardRefs tipe:
        c.invoke body: o
