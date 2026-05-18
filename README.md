# ethmultisig.org

A zero-dependency, single-file, open-source Ethereum multisig wallet.

## Overview

`ethmultisig.org` is a static site that lets users:
- Configure multisig owner sets and thresholds.
- Review a compact Solidity multisig contract source.
- Deploy directly from the browser with a connected wallet.

The project emphasizes **security through transparency**:
- No proxies.
- No upgrade paths.
- No external contract dependencies.
- Single-file website (`index.html`) for easy auditing and forking.

## Project Structure

- `index.html` — complete website UI, logic, and embedded contract source.
- `LICENSE` — MIT license.

## Local Development

Because this is a static site, you can run it with any basic HTTP server.

Examples:

```bash
python3 -m http.server 8080
```

Then open <http://localhost:8080>.

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE).
