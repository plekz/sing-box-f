# sing-box Forking Notes

Remotes
- upstream: https://github.com/SagerNet/sing-box (read-only)
- origin: to be set by you (your remote repo). Example:
  git remote add origin <your-remote-url>
  git push -u origin stable/<version>

Branching
- stable/<version>: exact upstream tag checkout
- refactor/reality-compat: place Reality/Vision compatibility changes

Build
- make build            # local build
- make build-linux      # linux/amd64
- make build-darwin     # macOS arm64

TODOs
- Enhance Reality/Vision logging (SNI/ALPN/short-id trace)
- Tolerant handshake mode options (ALPN ordering, empty short-id acceptance)
- Config schema toggles (backward-compatible)
