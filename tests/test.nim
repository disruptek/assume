import std/genasts
import std/macros

import balls

import assume

suite "assumptions are, like, great":
  block:
    ## do a thing
    macro goats(n: typed) =
      result = newStmtList()
      for statement in n.items:
        case statement.kind
        of nnkVarSection:
          for ident in statement.asIdentDefs:
            result.add:
              genAst(size = ident.len, tipe = ident[1]):
                check size == 3, "identdefs should be len==3"
                check tipe isnot void, "identdefs should have a type"
                check tipe is int, "in this test, the type is int"
        else:
          discard

    goats:
      var n = 4
      var a, b, c = 3
      #var (x, y, z) = (5, 6, 7)
