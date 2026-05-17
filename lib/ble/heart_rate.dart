import 'dart:typed_data';

/// 标准 BLE 心率服务 / 测量特征。Xiaomi Watch S4 Sport 蓝牙心率广播
/// 官方兼容码表 = 走标准 0x180D;通用心率带(Polar/Magene 等)同此。
const String hrServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
const String hrMeasurementCharUuid = '00002a37-0000-1000-8000-00805f9b34fb';

/// 解析 0x2A37「Heart Rate Measurement」。
///   byte0 = flags;bit0: 0 → 心率为 8 位(byte1);1 → 16 位小端(byte1..2)
/// 返回 bpm,无效帧返回 null。
int? parseHeartRate(Uint8List d) {
  if (d.isEmpty) return null;
  final flags = d[0];
  final is16 = (flags & 0x01) != 0;
  if (is16) {
    if (d.length < 3) return null;
    return d[1] | (d[2] << 8);
  }
  if (d.length < 2) return null;
  return d[1];
}
