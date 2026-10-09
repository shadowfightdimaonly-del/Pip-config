import 'package:flutter_test/flutter_test.dart';
import 'package:pip_config/main.dart';

void main() {
  group('ConfigInspector.labelFor', () {
    test('recognizes common URI schemes', () {
      expect(ConfigInspector.labelFor('vless://id@example.com:443'), 'VLESS');
      expect(ConfigInspector.labelFor('vmess://encoded-payload'), 'VMess');
      expect(ConfigInspector.labelFor('trojan://secret@example.com:443'), 'Trojan');
      expect(ConfigInspector.labelFor('ss://encoded-payload'), 'Shadowsocks');
      expect(ConfigInspector.labelFor('socks5://localhost:1080'), 'SOCKS proxy');
      expect(ConfigInspector.labelFor('https://example.com/sub'), 'HTTP(S) link');
    });

    test('recognizes WireGuard and OpenVPN text', () {
      const wireGuard = '''
[Interface]
PrivateKey = example-private-key
Address = 10.0.0.2/32

[Peer]
PublicKey = example-public-key
Endpoint = example.com:51820
''';
      const openVpn = '''
client
dev tun
remote vpn.example.com 1194
''';
      expect(ConfigInspector.labelFor(wireGuard), 'WireGuard');
      expect(ConfigInspector.labelFor(openVpn), 'OpenVPN');
    });
  });

  group('ConfigInspector.validate', () {
    test('accepts a non-empty recognized URI with a payload', () {
      expect(ConfigInspector.validate('vless://id@example.com:443'), isNull);
      expect(ConfigInspector.validate('https://example.com/sub'), isNull);
    });

    test('rejects empty and unknown input', () {
      expect(ConfigInspector.validate('  '), isNotNull);
      expect(ConfigInspector.validate('this is not a config'), isNotNull);
    });

    test('checks required fields in text configs', () {
      expect(
        ConfigInspector.validate('[Interface]\nPrivateKey = abc\n[Peer]\n'),
        isNotNull,
      );
      expect(ConfigInspector.validate('client\ndev tun\n'), isNotNull);
    });
  });
}
