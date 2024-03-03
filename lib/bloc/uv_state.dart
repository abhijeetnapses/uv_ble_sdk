part of 'uv_bloc.dart';

sealed class UVState extends Equatable {
  const UVState();

  @override
  List<Object> get props => [];
}

final class UVInitial extends UVState {}

class BluetoothModuleStatusChangedState extends UVState {
  final BluetoothModuleState state;
  const BluetoothModuleStatusChangedState(this.state);

  @override
  List<Object> get props => [state];
}

class DeviceConnectionState extends UVState {
  final UVDeviceConnectionState state;
  const DeviceConnectionState(this.state);

  @override
  List<Object> get props => [state];
}

class DeviceTreatmentState extends UVState {
  final TreatmentState state;
  final int? timeLeft;

  const DeviceTreatmentState(this.state, this.timeLeft);

  @override
  List<Object> get props => [state, timeLeft ?? 0];
}
