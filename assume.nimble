version = "0.7.0"
author = "disruptek"
description = "assume makes an ass out of u and me"
license = "MIT"

task demo, "produce a demo":
  exec """demo docs/demo.svg "nim c --define:release --out=\$1 tests/test.nim""""

