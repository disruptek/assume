import std/genasts
import std/macros

import balls

import assume

suite "assumptions are, like, great":
  block:
    ## do a thing with var sections, let sections, identdefs
    macro goats(n: typed) =
      result = newStmtList()
      for statement in n.items:
        case statement.kind
        of nnkVarSection:
          var i = 0
          for ident in statement.asIdentDefs:
            inc i
            result.add:
              genAst(size = ident.len, tipe = ident[1]):
                check size == 3, "identdefs should be len==3"
                check tipe isnot void, "identdefs should have a type"
                check tipe is int, "in this test, the type is int"
          result.add:
            genAst(i = newLit i):
              check i == 1, "expected one identdefs"
        of nnkLetSection:
          var i = 0
          for ident in statement.asIdentDefs:
            inc i
            result.add:
              genAst(size = ident.len, tipe = ident[1]):
                check size == 3, "identdefs should be len==3"
                check tipe isnot void, "identdefs should have a type"
                check tipe is int, "in this test, the type is int"
          result.add:
            genAst(i = newLit i):
              check i == 3, "expected three identdefs"
          i = 0
          let mut = toAnVarSection statement
          for ident in mut.asIdentDefs:
            inc i
          result.add:
            genAst(kind = newLit $mut.kind, i = newLit i):
              check i == 3, "expected three identdefs"
              check kind == "nnkVarSection", "lame conversion"
        else:
          discard

    goats:
      var n = 4
      let a, b, c = 3
      #var (x, y, z) = (5, 6, 7)
