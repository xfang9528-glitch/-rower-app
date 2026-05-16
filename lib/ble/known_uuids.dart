// Friendly names for standard BLE GATT services / characteristics so the
// protocol explorer can instantly tell us whether the Xiaomo rower speaks a
// documented standard (especially FTMS) or a proprietary protocol.

const String ftmsServiceUuid = '00001826-0000-1000-8000-00805f9b34fb';
const String rowerDataCharUuid = '00002ad1-0000-1000-8000-00805f9b34fb';
const String ftmsControlPointCharUuid =
    '00002ad9-0000-1000-8000-00805f9b34fb';

const Map<String, String> _knownNames = {
  // Services
  '00001800': 'Generic Access',
  '00001801': 'Generic Attribute',
  '0000180a': 'Device Information',
  '0000180d': 'Heart Rate',
  '0000180f': 'Battery',
  '00001816': 'Cycling Speed and Cadence',
  '00001818': 'Cycling Power',
  '00001826': 'Fitness Machine (FTMS)',
  '0000fff0': 'Vendor FFF0 (common proprietary)',
  '0000ffe0': 'Vendor FFE0 (common UART-style)',
  '0000fe59': 'Nordic DFU',
  '6e400001-b5a3-f393-e0a9-e50e24dcca9e': 'Nordic UART Service',
  // Characteristics
  '00002a00': 'Device Name',
  '00002a19': 'Battery Level',
  '00002a24': 'Model Number',
  '00002a25': 'Serial Number',
  '00002a26': 'Firmware Revision',
  '00002a29': 'Manufacturer Name',
  '00002a37': 'Heart Rate Measurement',
  '00002acc': 'Fitness Machine Feature',
  '00002ad1': 'Rower Data (FTMS)',
  '00002ad2': 'Indoor Bike Data (FTMS)',
  '00002ad3': 'Training Status (FTMS)',
  '00002ad9': 'Fitness Machine Control Point (FTMS)',
  '00002ada': 'Fitness Machine Status (FTMS)',
  '00002ad6': 'Supported Resistance Level Range (FTMS)',
  '00002ad8': 'Supported Power Range (FTMS)',
  '6e400002-b5a3-f393-e0a9-e50e24dcca9e': 'Nordic UART RX (write)',
  '6e400003-b5a3-f393-e0a9-e50e24dcca9e': 'Nordic UART TX (notify)',
};

/// Returns the 16-bit short form (e.g. `0x2AD1`) when the UUID is a Bluetooth
/// SIG base UUID, otherwise the full 128-bit string.
String shortUuid(String uuid) {
  final u = uuid.toLowerCase();
  if (u.length == 36 &&
      u.endsWith('-0000-1000-8000-00805f9b34fb') &&
      u.startsWith('0000')) {
    return '0x${u.substring(4, 8).toUpperCase()}';
  }
  return uuid;
}

/// Friendly label for a UUID, or null when unknown.
String? describeUuid(String uuid) {
  final u = uuid.toLowerCase();
  if (_knownNames.containsKey(u)) return _knownNames[u];
  if (u.length == 36 && u.endsWith('-0000-1000-8000-00805f9b34fb')) {
    final key = u.substring(0, 8);
    if (_knownNames.containsKey(key)) return _knownNames[key];
  }
  return null;
}

bool isRowerDataChar(String uuid) =>
    uuid.toLowerCase() == rowerDataCharUuid;
