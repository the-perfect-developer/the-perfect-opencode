---
description: Explore agent - Fast agent specialized for exploring codebases, finding files by patterns, and searching code
tools:
  write: false
  edit: false
  bash: true
  webfetch: true
permission:
  bash:
    "*": ask
    "ls*": allow
    pwd: allow
    "which*": allow
    whoami: allow
    "cat*": allow
    "head*": allow
    "tail*": allow
    "wc*": allow
    "file*": allow
    "stat*": allow
    "du*": allow
    "df*": allow
    "grep*": allow
    "rg*": allow
    "find*": allow
    "tree*": allow
    "awk*": allow
    "sort*": allow
    "cut*": allow
    "uniq*": allow
    "tr*": allow
    "comm*": allow
    "diff*": allow
    "jq*": allow
    "yq*": allow
    "echo*": allow
    "printf*": allow
    env: allow
    "printenv*": allow
    "uname*": allow
    arch: allow
    nproc: allow
    hostname: allow
    uptime: allow
    "free*": allow
    date: allow
    "date +*": allow
    "sha256sum*": allow
    "md5sum*": allow
    "sha1sum*": allow
    "node --version": allow
    "node -v": allow
    "python --version": allow
    "python3 --version": allow
    "go version": allow
    "go env*": allow
    "rustc --version": allow
    "cargo --version": allow
    "bun --version": allow
    "deno --version": allow
    "java --version": allow
    "ruby --version": allow
    "npm --version": allow
    "yarn --version": allow
    "pnpm --version": allow
    "npm ls*": allow
    "npm list*": allow
    "npm view*": allow
    "pip list": allow
    "pip show*": allow
    "pip freeze": allow
    "go list*": allow
    "cargo metadata": allow
    "cargo tree*": allow
    "gem list": allow
    "pgrep*": allow
    "pidof*": allow
    "ps*": ask
    "lsof*": ask
    "git status": allow
    "git diff*": allow
    "git log*": allow
    "git show*": allow
    "git branch*": allow
    "git remote*": allow
    "git ls-files*": allow
    "git blame*": allow
    "git describe*": allow
    "git rev-parse*": allow
    "git stash list": allow
    "git tag": allow
    "git tag -l*": allow
    "git config --get*": allow
    "curl*": ask
    "ping*": ask
    "dig*": ask
    "nslookup*": ask
    "ss*": ask
    "netstat*": ask
    "make -n*": ask
    "* /tmp*": allow
  webfetch: allow
---
