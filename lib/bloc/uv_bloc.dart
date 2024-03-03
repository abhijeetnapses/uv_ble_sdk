import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uv_ble_sdk/enums/bluetooth_state.dart';
import 'package:uv_ble_sdk/enums/device_connection_state.dart';
import 'package:uv_ble_sdk/enums/treatment_state.dart';

part 'uv_event.dart';
part 'uv_state.dart';

class UVBloc extends Bloc<UVEvent, UVState> {
  UVBloc() : super(UVInitial()) {
    on<BluetoothStateChangedEvent>((event, emit) {
      emit(BluetoothModuleStatusChangedState(BluetoothModuleState.values.firstWhere(
          (element) => element.name == event.bluetoothAdapterState.name,
          orElse: () => BluetoothModuleState.unknown)));
    });
    on<DeviceDiscoveryEvent>((event, emit) {
      emit(DeviceConnectionState(event.uvDeviceDiscoveryState));
    });

    on<DeviceTreatmentEvent>((event, emit) {
      emit(DeviceTreatmentState(event.state, event.timeLeft));
    });
  }
}
