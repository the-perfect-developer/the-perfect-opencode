---
description: Build agent - Default implementation agent for general coding tasks
mode: subagent
hidden: true
tools:
  write: true
  edit: true
  bash: true
  webfetch: true
permission:
  write: allow
  edit: allow
  bash:
    "*": ask
    # --- Filesystem read ---
    "ls*": allow
    "pwd": allow
    "which*": allow
    "whoami": allow
    "cat*": allow
    "head*": allow
    "tail*": allow
    "wc*": allow
    "file*": allow
    "stat*": allow
    "du*": allow
    "df*": allow
    # --- Search and text processing ---
    "grep*": allow
    "rg*": allow
    "find*": allow
    "tree*": allow
    "awk*": allow
    "sed*": allow
    "sort*": allow
    "cut*": allow
    "uniq*": allow
    "tr*": allow
    "comm*": allow
    "diff*": allow
    "jq*": allow
    "yq*": allow
    # --- Output ---
    "echo*": allow
    "printf*": allow
    # --- Environment ---
    "env": allow
    "printenv*": allow
    # --- System info ---
    "uname*": allow
    "arch": allow
    "nproc": allow
    "hostname": allow
    "uptime": allow
    "free*": allow
    "date": allow
    "date +*": allow
    # --- File integrity ---
    "sha256sum*": allow
    "md5sum*": allow
    "sha1sum*": allow
    # --- Runtime versions ---
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
    # --- Package inspection ---
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
    # --- Process inspection ---
    "pgrep*": allow
    "pidof*": allow
    "ps*": ask
    "lsof*": ask
    # --- Git read ---
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
    # --- Network ---
    "curl*": ask
    "ping*": ask
    "dig*": ask
    "nslookup*": ask
    "ss*": ask
    "netstat*": ask
    # --- Build dry-run ---
    "make -n*": ask
    # --- /tmp sandbox ---
    "* /tmp*": allow
    # --- Git write ---
    "git add*": allow
    "git commit*": allow
    "git stash*": allow
    "git switch*": allow
    "git checkout*": ask
    "git push*": ask
    "git reset*": ask
    "git merge*": ask
    "git rebase*": ask
    "git tag*": ask
    # --- Node / JS package managers ---
    "npm install": allow
    "npm ci": allow
    "npm run*": allow
    "npx*": allow
    "yarn install": allow
    "yarn dev": allow
    "yarn build": allow
    "yarn test": allow
    "yarn lint": allow
    "yarn format": allow
    "pnpm install": allow
    "pnpm dev": allow
    "pnpm build": allow
    "pnpm test": allow
    "pnpm lint": allow
    "pnpm format": allow
    "bun install": allow
    "bun run*": allow
    # --- JS/TS tooling ---
    "tsc*": allow
    "eslint*": allow
    "prettier*": allow
    # --- Python tooling ---
    "python -m pytest*": allow
    "pytest*": allow
    "pip install*": allow
    "uv*": allow
    "ruff check*": allow
    "ruff format*": allow
    "mypy*": allow
    "python -m*": allow
    # --- Go tooling ---
    "go test*": allow
    "go build*": allow
    "go run*": allow
    "go mod tidy": allow
    "go mod download": allow
    "go generate*": allow
    "go vet*": allow
    # --- Rust tooling ---
    "cargo test*": allow
    "cargo build*": allow
    "cargo run*": allow
    "cargo fmt*": allow
    "cargo clippy*": allow
    # --- Make ---
    "make*": allow
    # --- Filesystem write ---
    "mkdir*": allow
    "touch*": allow
    "cp*": ask
    "mv*": ask
    "rm*": ask
    "chmod*": ask
    "ln -s*": ask
    # --- Shell validation ---
    "bash -n*": allow
  webfetch: allow
---
