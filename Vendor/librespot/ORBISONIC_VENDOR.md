Vendored librespot source for Orbisonic's embedded Spotify Connect receiver.

- Upstream: https://github.com/librespot-org/librespot
- Upstream commit: 33bf3a77ed4b549df67e8347d7d6e55b007b3ec2
- Upstream license: MIT, see `LICENSE` in this directory.
- Orbisonic use: build a Rust static library that runs librespot in-process and targets `Orbisonic Spotify Input`.

Do not store Spotify credentials, OAuth tokens, caches, or local machine paths in this vendored tree. Runtime files belong in Orbisonic-managed Application Support and Logs directories.
