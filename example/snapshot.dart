import 'package:snapshot/snapshot.dart';

void main() {
  var v = Snapshot.fromJson({
    'firstname': 'Jane',
    'lastname': 'Doe',
    'profileUrl': 'https://my.avatar.com/jane-doe.png',
    'createdAt': 1593698272650,
    'dateOfBirth': '2001-01-02',
    'address': {
      'addressLine1': 'Mainstreet 1',
      'city': 'London',
    }
  });

  // getting a property as core data type
  var firstname = v.child('firstname').as<String>();
  print('firstname = $firstname');

  // getting a property and converting it to an Uri
  var profileUrl = v.child('profileUrl').as<Uri>();
  print('profile url = $profileUrl');

  // converting to a DateTime object
  var dateOfBirth = v.child('dateOfBirth').as<DateTime>();
  print('age = ${DateTime.now().difference(dateOfBirth).inDays} days');

  // converting to a DateTime object with alternative format
  var createAt = v.child('createdAt').as<DateTime>(format: 'epoch');
  print('created at = $createAt');

  // accessing a subfield
  var addressLine1 = v.child('address/addressLine1').as<String>();
  print('address = $addressLine1');

  // or
  addressLine1 = v.child('address').child('addressLine1').as();
  print('address = $addressLine1');

  // registering a new converter
  var decoder = SnapshotDecoder()
    ..register<Map<String, dynamic>, Address>((v) => Address.fromJson(v));

  v = Snapshot.fromJson(v.as(), decoder: decoder);

  // getting a property with custom type
  var address = v.child('address').as<Address>();
  print('city = ${address.city}');

  var modifiableAddress = ModifiableAddress.fromJson(address.toJson());

  modifiableAddress.city = 'New York';

  print('city = ${modifiableAddress.city}');
}

// create a mixin on a [SnapshotView]
mixin AddressMixin on SnapshotView {
  // add getters for fields
  String get addressLine1 => get('addressLine1');

  String get city => get('city');
}

// create a class extending a UnmodifiableSnapshotView with the mixin
// this will provide a `fromJson` constructor
class Address = UnmodifiableSnapshotView with AddressMixin;

// create a mixin on a [SnapshotView]
mixin ModifiableAddressMixin on AddressMixin, ModifiableSnapshotView {
  // add setters for fields
  set city(String city) => set('city', city);
}

// create a class extending a ModifiableSnapshotView with the mixin
class ModifiableAddress = ModifiableSnapshotView
    with AddressMixin, ModifiableAddressMixin;
