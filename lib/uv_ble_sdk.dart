import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uv_ble_sdk/bloc/uv_bloc.dart';
import 'package:uv_ble_sdk/core/constants.dart';
import 'package:uv_ble_sdk/core/utils.dart';
import 'package:uv_ble_sdk/enums/device_connection_state.dart';
import 'package:uv_ble_sdk/enums/treatment_state.dart';
import 'package:uv_ble_sdk/ui/mock_dialog.dart';

class UvBleSdk {
  UvBleSdk._privateConstructor();

  bool _isMocking = false;
  bool? _askedForMocking;

  bool _isInitialised = false;
  GlobalKey<NavigatorState>? _navigatorKey;

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

  StreamSubscription<BluetoothConnectionState>? _connectionStateListener;

  StreamSubscription<List<int>>? _commandsListener;

  BluetoothAdapterState? _adapterState;

  bool get isBluetoothOn => _adapterState == BluetoothAdapterState.on;

  static final UvBleSdk instance = UvBleSdk._privateConstructor();

  ///True: mocking
  ///False: using real device
  Future<bool> _checkForMocking() async {
    if (_isMocking && _askedForMocking == null) {
      if (_navigatorKey != null && _navigatorKey!.currentContext != null) {
        bool result = await _showMockDialog(_navigatorKey!.currentContext!);
        _askedForMocking = result;
        return result;
      }
    } else if (_isMocking && _askedForMocking != null && _askedForMocking!) {
      return true;
    }
    return false;
  }

  Future<bool> _showMockDialog(BuildContext context) async {
    var result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return MockDialog(
          title: 'Device simulator',
          button1Title: 'Simulate UV device',
          button2Title: 'Use real device',
          button1Callback: () {
            Navigator.of(context).pop(true);
          },
          button2Callback: () {
            Navigator.of(context).pop(false);
          },
        );
      },
    );
    if (result != null && result) return true;

    return false;
  }

  ///Turn on bluetooth Android only
  Future<void> turnOnBluetooth({int timeout = 60}) async {
    try {
      if (Platform.isAndroid) {
        if (!await _checkForMocking()) {
          await FlutterBluePlus.turnOn(timeout: timeout);
        } else {
          await _mockTurnOn();
        }
      } else {
        Utils.printLogs("turnOn() iOS is not supported");
        Utils.printLogs("If you're reading this, someone forgot to put condition for iOS in UI");
        Utils.printLogs("#noob");
      }
    } catch (e) {
      Utils.printLogs("Error while turning on Bluetooth");
    }
  }

  ///This will initialise basic params
  ///This will not ask for permissions
  initialise({
    bool isMocking = false,
    bool loggingEnabled = true,
    int scanTimeOut = 15,
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    if (!_isInitialised) {
      _isMocking = isMocking;
      loggingEnabled = loggingEnabled;
      _scanTimeOut = scanTimeOut;
      _navigatorKey = navigatorKey;
      if (loggingEnabled) FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
      FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
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

  startTreatment(int time) async {
    if (!await _checkForMocking()) {
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
    } else {
      _mockStartTreatment(time);
    }
  }

  turnOffUVDevice() async {
    if (!await _checkForMocking()) {
      if (isUVDeviceConnected) {
        try {
          await characteristic!.write(Commands.keyPower.codeUnits, withoutResponse: true);
          await _uvDevice!.disconnect();
          // bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.disconnected));
        } catch (e) {
          Utils.printLogs(e.toString());
        }
      } else {
        Utils.printLogs("Device not connected");
      }
    } else {
      _mockTurnOff();
    }
  }

  _initiateConnection(BluetoothDevice? uvDevice) async {
    if (uvDevice != null) {
      await FlutterBluePlus.stopScan();
      Utils.printLogs("Device found trying to connect");
      bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.found));

      if (_connectionStateListener != null) await _connectionStateListener!.cancel();

      _connectionStateListener = uvDevice.connectionState.listen((state) async {
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
            characteristic!.setNotifyValue(true);
            if (_commandsListener != null) await _commandsListener!.cancel();
            Utils.printLogs("Attaching commands listener");
            _commandsListener = characteristic!.onValueReceived.listen((value) async {
              String code = String.fromCharCodes(value);
              Utils.printLogs("onValueReceived: $code");
              if (code == "#7Z2@") {
                await Future.delayed(const Duration(seconds: 1));
                bloc.add(const DeviceTreatmentEvent(TreatmentState.completed));
                _isTreatmentRunning = false;
              } else if (code.contains("#6S")) {
                String time = code.split("#6S").last.split("@").first;
                bloc.add(
                    DeviceTreatmentEvent(TreatmentState.running, timeLeft: int.tryParse(time)));
              }
            });

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
    if (!await _checkForMocking()) {
      if (!_isScanning) {
        bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.scanning));
        try {
          if (_uvDevice != null) {
            if (_uvDevice!.isConnected) {
              await _uvDevice!.disconnect();
            }
            _uvDevice = null;
          }
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
    } else {
      _mockConnectionWithUVDevice();
    }
  }

  Future<void> _mockConnectionWithUVDevice() async {
    bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.scanning));
    await Future.delayed(const Duration(seconds: 1));
    bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.found));
    await Future.delayed(const Duration(seconds: 1));
    bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.connecting));
    await Future.delayed(const Duration(seconds: 1));
    _connectionState = BluetoothConnectionState.connected;
    bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.connected));
  }

  Future<void> _mockTurnOff() async {
    _connectionState = BluetoothConnectionState.disconnected;
    await Future.delayed(const Duration(seconds: 2));
    bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.disconnected));
  }

  int _remainingTime = 0;

  Future<void> _mockStartTreatment(int time) async {
    _remainingTime = time;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingTime--;
      if (_remainingTime < 0) {
        timer.cancel();
        bloc.add(const DeviceTreatmentEvent(TreatmentState.completed));
        return;
      }
      bloc.add(DeviceTreatmentEvent(TreatmentState.running, timeLeft: _remainingTime));
    });
  }

  Future<void> _mockTurnOn() async {
    await Future.delayed(const Duration(seconds: 1));
    _adapterState = BluetoothAdapterState.on;
    bloc.add(BluetoothStateChangedEvent(_adapterState!));
  }
}
