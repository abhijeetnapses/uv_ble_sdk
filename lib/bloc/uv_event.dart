part of 'uv_bloc.dart';

sealed class UVEvent extends Equatable {
  const UVEvent();

  @override
  List<Object> get props => [];
}

class BluetoothStateChangedEvent extends UVEvent {
  final BluetoothAdapterState bluetoothAdapterState;
  const BluetoothStateChangedEvent(this.bluetoothAdapterState);
}

class DeviceDiscoveryEvent extends UVEvent {
  final UVDeviceConnectionState uvDeviceDiscoveryState;
  const DeviceDiscoveryEvent(this.uvDeviceDiscoveryState);
}

class DeviceTreatmentEvent extends UVEvent {
  final TreatmentState state;
  final int? timeLeft;

  const DeviceTreatmentEvent(this.state, {this.timeLeft});
}

class DeviceQueueEvent extends UVEvent {
  final QueueState state;
  const DeviceQueueEvent(this.state);
}
