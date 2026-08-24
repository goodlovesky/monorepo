import 'package:app/services/home_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeLayout', () {
    test('default order resolves to defaultOrder', () {
      const layout = HomeLayout();
      expect(layout.resolvedOrder(), HomeLayout.defaultOrder);
      expect(layout.isHidden('subscription'), isFalse);
    });

    test('user order takes precedence and unknown ids are dropped', () {
      const layout = HomeLayout(order: ['traffic', 'unknown', 'subscription']);
      final resolved = layout.resolvedOrder();
      expect(resolved.first, 'traffic');
      expect(resolved.contains('unknown'), isFalse);
      expect(
        resolved.indexOf('traffic'),
        lessThan(resolved.indexOf('subscription')),
      );
    });

    test('hidden set toggles visibility', () {
      const layout = HomeLayout(hidden: {'traffic', 'metrics'});
      expect(layout.isHidden('traffic'), isTrue);
      expect(layout.isHidden('subscription'), isFalse);
    });

    test('JSON round-trip preserves order and hidden', () {
      final original = HomeLayout(
        order: const ['traffic', 'subscription', 'currentNode'],
        hidden: const {'metrics', 'siteTest'},
      );
      final encoded = original.encode();
      final decoded = HomeLayout.fromMetaString(encoded);
      expect(decoded.order, original.order);
      expect(decoded.hidden, original.hidden);
    });

    test('invalid JSON falls back to default', () {
      final layout = HomeLayout.fromMetaString('not json');
      expect(layout.order, isEmpty);
      expect(layout.hidden, isEmpty);
    });
  });
}
