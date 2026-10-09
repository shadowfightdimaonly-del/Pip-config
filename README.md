# PipConfig

PIPIS-AFC configuration client for importing and managing user-provided connection configurations.

## Project rules

- No paid infrastructure.
- No owned servers or data centers.
- The app is a client, not a VPN service provider.
- Black + purple PIPIS-AFC visual identity.

## Current implementation

- Flutter Material 3 interface with the PIPIS-AFC black/purple palette.
- Save, select, and delete configuration entries locally on the device.
- Import a configuration by pasting text from the clipboard or entering it manually.
- Basic format recognition for VLESS, VMess, Trojan, Shadowsocks, SOCKS, WireGuard, and OpenVPN.
- Basic sanity checks before saving.
- JSON-based storage, including migration from the previous `name|value` format.

## Important limitations

Format recognition is only a lightweight check. It does not verify whether a server is reachable, decode every subscription format, or mean that a protocol can already connect. The connection button and QR scanner are not implemented yet. No VPN engine or server infrastructure is bundled.

## Next milestones

1. Add proper QR scanning and import.
2. Add subscription-link fetching and parsing with clear user consent.
3. Choose and integrate a suitable open-source Android connection engine.
4. Implement Android VPN permission flow, connection status, and error reporting.
5. Add tests for parsing, persistence, and malformed input.
