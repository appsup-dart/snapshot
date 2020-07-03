import 'package:snapshot/snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('SnapshotView', () {
    group('SnapshotView.toJson()', () {
      test('Should return content unmodified', () {
        SnapshotView v = UnmodifiableSnapshotView.fromJson(
            {'firstname': 'Jane', 'lastname': 'Doe'});

        expect(v.toJson(), {'firstname': 'Jane', 'lastname': 'Doe'});

        v = ModifiableSnapshotView.fromJson(
            {'firstname': 'Jane', 'lastname': 'Doe'});

        expect(v.toJson(), {'firstname': 'Jane', 'lastname': 'Doe'});
      });
    });

    group('SnapshotView.get()', () {
      test('Should return and convert property', () {
        var decoder = SnapshotDecoder()
          ..register<Map<String, dynamic>, Address>((v) => Address.fromJson(v))
          ..seal();
        SnapshotView v = UnmodifiableSnapshotView.fromJson({
          'firstname': 'Jane',
          'lastname': 'Doe',
          'pictureUrl': 'https://my.avatar.com/jane-doe',
          'address': {'addressLine1': 'Mainstreet 1', 'city': 'London'}
        }, decoder: decoder);

        expect(v.get('firstname'), 'Jane');
        expect(v.get<Uri>('pictureUrl'),
            Uri.parse('https://my.avatar.com/jane-doe'));
        var address = v.get<Address>('address');
        expect(address, isA<Address>());
        expect(address.city, 'London');
        expect(address.addressLine1, 'Mainstreet 1');

        v = ModifiableSnapshotView.fromJson({
          'firstname': 'Jane',
          'lastname': 'Doe',
          'pictureUrl': 'https://my.avatar.com/jane-doe',
          'address': {'addressLine1': 'Mainstreet 1', 'city': 'London'}
        }, decoder: decoder);

        expect(v.get('firstname'), 'Jane');
        expect(v.get<Uri>('pictureUrl'),
            Uri.parse('https://my.avatar.com/jane-doe'));
        address = v.get<Address>('address');
        expect(address, isA<Address>());
        expect(address.city, 'London');
        expect(address.addressLine1, 'Mainstreet 1');
      });
    });

    group('SnapshotView.set()', () {
      test('Should update content', () {
        var decoder = SnapshotDecoder()
          ..register<Map<String, dynamic>, ModifiableAddress>(
              (v) => ModifiableAddress.fromJson(v))
          ..seal();
        var v = ModifiableSnapshotView.fromJson({
          'firstname': 'Jane',
          'lastname': 'Doe',
          'pictureUrl': 'https://my.avatar.com/jane-doe',
          'address': {'addressLine1': 'Mainstreet 1', 'city': 'London'}
        }, decoder: decoder);

        v.set('firstname', 'John');
        expect(v.get('firstname'), 'John');
        expect(v.get('lastname'), 'Doe');

        var address = v.get<ModifiableAddress>('address');

        address.city = 'New York';
        expect(address.city, 'New York');
        expect(address.addressLine1, 'Mainstreet 1');
        expect(v.get('address/city'), 'London');

        v.set('address', address.toJson());
        expect(v.get('address/city'), 'New York');
      });
    });
  });
}

mixin AddressMixin on SnapshotView {
  String get addressLine1 => get('addressLine1');

  String get city => get('city');
}

class Address = UnmodifiableSnapshotView with AddressMixin;

mixin ModifiableAddressMixin on ModifiableSnapshotView {
  set addressLine1(String v) => set('addressLine1', v);

  set city(String v) => set('city', v);
}

class ModifiableAddress = ModifiableSnapshotView
    with AddressMixin, ModifiableAddressMixin;
