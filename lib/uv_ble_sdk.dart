import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uv_ble_sdk/bloc/uv_bloc.dart';
import 'package:uv_ble_sdk/core/constants.dart';
import 'package:uv_ble_sdk/core/utils.dart';
import 'package:uv_ble_sdk/enums/device_connection_state.dart';
import 'package:uv_ble_sdk/enums/treatment_state.dart';

class UvBleSdk {
  UvBleSdk._privateConstructor();

  bool _isMocking = false;

  bool _isInitialised = false;
  bool _isListenerAttached = false;

  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;

  bool get isUVDeviceConnected => _connectionState == BluetoothConnectionState.connected;
  bool get isTreatmentRunning => _isTreatmentRunning;

  bool loggingEnabled = true;
  bool _isTreatmentRunning = false;

  bool _isScanning = false;
  int _scanTimeOut = 15;

  final UVBloc bloc = UVBloc();

  BluetoothDevice? _uvDevice;

  BluetoothCharacteristic? characteristic;

  static final UvBleSdk instance = UvBleSdk._privateConstructor();

  ///This will initialise basic params
  ///This will not ask for permissions
  initialise({bool isMocking = false, bool loggingEnabled = true, int scanTimeOut = 15}) {
    if (!_isInitialised) {
      _isMocking = isMocking;
      loggingEnabled = loggingEnabled;
      _scanTimeOut = scanTimeOut;
      if (loggingEnabled) FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);

      FlutterBluePlus.adapterState.listen((state) {
        bloc.add(BluetoothStateChangedEvent(state));
      });

      FlutterBluePlus.scanResults.listen((results) {
        _uvDevice = Utils.searchForUVDeviceFromScanResult(results);
        _initiateConnection(_uvDevice);
      }, onError: (e) {});

      FlutterBluePlus.isScanning.listen((state) {
        _isScanning = state;
        bloc.add(DeviceDiscoveryEvent(_isScanning
            ? UVDeviceConnectionState.scanning
            : UVDeviceConnectionState.scanningStopped));
      });
    }

    _isInitialised = true;
  }

  startTreatment(int time) {
    if (isUVDeviceConnected) {
      try {
        characteristic!.write(Commands.dose(time).codeUnits, withoutResponse: true);
        bloc.add(const DeviceTreatmentEvent(TreatmentState.running));
        _isTreatmentRunning = true;
      } catch (e) {
        Utils.printLogs(e.toString());
        bloc.add(const DeviceTreatmentEvent(TreatmentState.error));
      }
    } else {
      Utils.printLogs("Device not connected");
    }
  }

  turnOffUVDevice() async {
    if (isUVDeviceConnected) {
      try {
        await characteristic!.write(Commands.keyPower.codeUnits, withoutResponse: true);
        await _uvDevice!.disconnect();
        bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.disconnected));
      } catch (e) {
        Utils.printLogs(e.toString());
      }
    } else {
      Utils.printLogs("Device not connected");
    }
  }

  _initiateConnection(BluetoothDevice? uvDevice) async {
    if (uvDevice != null) {
      await FlutterBluePlus.stopScan();
      Utils.printLogs("Device found trying to connect");
      bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.found));

      uvDevice.connectionState.listen((state) async {
        _connectionState = state;
        if (state == BluetoothConnectionState.connected) {
          bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.connected));
          Utils.printLogs("Device connected");
          _discoverServices(uvDevice);
        } else if (state == BluetoothConnectionState.disconnected) {
          bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.disconnected));
        }
      });

      bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.connecting));
      await uvDevice.connect(mtu: null);
      return;
    }
  }

  _discoverServices(BluetoothDevice uvDevice) async {
    List<BluetoothService> services = await uvDevice.discoverServices();
    try {
      List<BluetoothService> supportedServices = services
          .where((element) => element.serviceUuid.str128 == Constants.deviceServiceId)
          .toList();
      if (supportedServices.isNotEmpty) {
        Utils.printLogs("Service found in device");

        List<BluetoothCharacteristic> characteristics = supportedServices.first.characteristics
            .where(
                (element) => element.characteristicUuid.str128 == Constants.deviceCharacteristicId)
            .toList();

        if (characteristics.isNotEmpty) {
          characteristic = characteristics.first;
          Utils.printLogs("Characteristic found in device");
          if (characteristic != null) {
            if (!_isListenerAttached) {
              characteristic!.setNotifyValue(characteristic!.isNotifying == false);
              characteristic!.onValueReceived.listen((value) {
                String code = String.fromCharCodes(value);
                Utils.printLogs("onValueReceived: $code");
                if (code == "#7Z2@") {
                  bloc.add(const DeviceTreatmentEvent(TreatmentState.completed));
                  _isTreatmentRunning = false;
                } else if (code.contains("#6S")) {
                  String time = code.split("#6S").last.split("@").first;
                  Utils.printLogs(time);
                  bloc.add(
                      DeviceTreatmentEvent(TreatmentState.running, timeLeft: int.tryParse(time)));
                }
              });
            }
            _isListenerAttached = true;
            characteristic!.write(Commands.getInfo.codeUnits, withoutResponse: true);
          }
        } else {
          Utils.printLogs("No supported characteristic found in device");
        }
      } else {
        Utils.printLogs("No supported service found in device");
      }
    } on Exception catch (e) {
      Utils.printLogs(e.toString());
    }
  }

  Future<void> connectWithUVDevice() async {
    if (!_isScanning) {
      bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.scanning));
      try {
        _uvDevice = null;
        _uvDevice = Utils.searchForUVDevice(await FlutterBluePlus.systemDevices);
        _initiateConnection(_uvDevice);
      } catch (e) {
        bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.error));
        Utils.printLogs(e.toString());
      }
      try {
        await FlutterBluePlus.startScan(timeout: Duration(seconds: _scanTimeOut));
      } catch (e) {
        // bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.error));
        Utils.printLogs(e.toString());
      }
    } else {
      Utils.printLogs("Scan in progress");
    }
  }
}
