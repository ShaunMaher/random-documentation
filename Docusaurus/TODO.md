---
title: TODOs
---

* showLastUpdateAuthor and showLastUpdateTime are not working.  This is probably
  because:
  * docs is a git submodule
  * The .git directory is not being copied into the build dir in the CI/CD
    pipeline.