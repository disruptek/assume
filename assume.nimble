version = "0.6.0"
author = "disruptek"
description = "assume makes an ass out of u and me"
license = "MIT"

taskRequires "test", "https://github.com/disruptek/balls >= 2.0.0 & < 4.0.0"

task test, "run tests for ci":
  when defined(windows):
    exec "balls.cmd"
  else:
    exec "balls"

task demo, "produce a demo":
  exec """demo docs/demo.svg "nim c --define:release --out=\$1 tests/test.nim""""

