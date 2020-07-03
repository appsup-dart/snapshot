import 'package:snapshot/src/patch.dart';
import 'package:test/test.dart';

void main() {
  group('Patch', () {
    test('Patches from individual operations', () {
      var patch = Patch([
        Operation.add('/hello', 'world'),
      ]);
      var v = patch.apply({});
      expect(v, {'hello': 'world'});

      patch = Patch([Operation.replace('/hello', 'everyone')]);
      v = patch.apply(v);
      expect(v, {'hello': 'everyone'});

      patch = Patch([Operation.move('/hello', '/hi')]);
      v = patch.apply(v);
      expect(v, {'hi': 'everyone'});

      patch = Patch([Operation.copy('/hi', '/hey')]);
      v = patch.apply(v);
      expect(v, {'hi': 'everyone', 'hey': 'everyone'});

      patch = Patch([Operation.remove('/hi')]);
      v = patch.apply(v);
      expect(v, {'hey': 'everyone'});

      patch = Patch([Operation.test('/hey', 'everyone')]);
      v = patch.apply(v);
      expect(v, {'hey': 'everyone'});
    });
  });
}
