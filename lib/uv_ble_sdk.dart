import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uv_ble_sdk/bloc/uv_bloc.dart';
import 'package:uv_ble_sdk/core/constants.dart';
import 'package:uv_ble_sdk/core/utils.dart';
import 'package:uv_ble_sdk/enums/device_connection_state.dart';
import 'package:uv_ble_sdk/enums/queue_state.dart';
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
  bool get isTreatmentPaused => _isTreatmentPaused;

  bool loggingEnabled = true;
  bool _isTreatmentRunning = false;
  bool _isTreatmentPaused = false;

  bool _isScanning = false;
  int _scanTimeOut = 15;

  bool waitingForInitialRequest = false;

  final UVBloc bloc = UVBloc();

  BluetoothDevice? _uvDevice;

  String? get getDeviceInfo => _uvDevice?.remoteId.str;

  BluetoothCharacteristic? _characteristic;

  StreamSubscription<BluetoothConnectionState>? _connectionStateListener;

  StreamSubscription<List<int>>? _commandsListener;

  BluetoothAdapterState? _adapterState;

  bool get isBluetoothOn => _adapterState == BluetoothAdapterState.on;

  static final UvBleSdk instance = UvBleSdk._privateConstructor();

  Timer? _heartBeatTimer;

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
    List<String>? supportedDeviceNames,
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    if (!_isInitialised) {
      _isMocking = isMocking;
      loggingEnabled = loggingEnabled;
      _scanTimeOut = scanTimeOut;
      _navigatorKey = navigatorKey;
      if (loggingEnabled) FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);

      if (supportedDeviceNames != null && supportedDeviceNames.isNotEmpty) {
        Constants.supportedDeviceNames = supportedDeviceNames;
      }

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

  stopTreatment() {
    if (isUVDeviceConnected) {
      try {
        _characteristic!.write(Commands.endTreatment.codeUnits, withoutResponse: true);
        bloc.add(const DeviceTreatmentEvent(TreatmentState.completed));
        _isTreatmentRunning = false;
        _isTreatmentPaused = false;
      } catch (e) {
        Utils.printLogs(e.toString());
        bloc.add(const DeviceTreatmentEvent(TreatmentState.error));
      }
    } else {
      Utils.printLogs("Device not connected");
    }
  }

  startTreatment(int time) async {
    if (!await _checkForMocking()) {
      if (isUVDeviceConnected) {
        try {
          _characteristic!.write(Commands.dose(time).codeUnits, withoutResponse: true);
          bloc.add(const DeviceTreatmentEvent(TreatmentState.running));
          _isTreatmentRunning = true;
          _isTreatmentPaused = false;
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
          await _characteristic!.write(Commands.keyPower.codeUnits, withoutResponse: true);
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
      _isTreatmentRunning = false;
      _isTreatmentPaused = false;
      if (_connectionStateListener != null) await _connectionStateListener!.cancel();

      _connectionStateListener = uvDevice.connectionState.listen((state) async {
        _connectionState = state;
        if (state == BluetoothConnectionState.connected) {
          waitingForInitialRequest = true;
          Utils.printLogs("Device connected");
          Utils.printLogs("Waiting for initial response");
          _discoverServices(uvDevice);
        } else if (state == BluetoothConnectionState.disconnected) {
          _stopTimer();
          bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.disconnected));
          waitingForInitialRequest = false;
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
          _characteristic = characteristics.first;
          Utils.printLogs("Characteristic found in device");
          if (_characteristic != null) {
            _characteristic!.setNotifyValue(true);
            if (_commandsListener != null) await _commandsListener!.cancel();
            Utils.printLogs("Attaching commands listener");
            _commandsListener = _characteristic!.onValueReceived.listen(_receivingValueListener);
            await _characteristic!.write(Commands.verifyComm.codeUnits, withoutResponse: true);
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

  _receivingValueListener(value) async {
    String code = String.fromCharCodes(value);
    if (code == ReceivedCommands.treatmentCompleted) {
      Utils.printLogs("onValueReceived: treatmentCompleted - $code");
      bloc.add(const DeviceTreatmentEvent(TreatmentState.completed));
      _isTreatmentRunning = false;
      _isTreatmentPaused = false;
    } else if (code == ReceivedCommands.treatmentPaused) {
      Utils.printLogs("onValueReceived: treatmentPaused - $code");
      _isTreatmentPaused = true;
      bloc.add(const DeviceTreatmentEvent(TreatmentState.paused));
    } else if (code == ReceivedCommands.treatmentResumed) {
      Utils.printLogs("onValueReceived: treatmentResumed - $code");
      _isTreatmentRunning = true;
      _isTreatmentPaused = false;
      bloc.add(const DeviceTreatmentEvent(TreatmentState.resumed));
    } else if (code.contains(ReceivedCommands.timerPrefix)) {
      Utils.printLogs("onValueReceived: running - $code");
      _isTreatmentRunning = true;
      _isTreatmentPaused = false;
      String time =
          code.split(ReceivedCommands.timerPrefix).last.split(ReceivedCommands.frameSuffix).first;
      bloc.add(DeviceTreatmentEvent(TreatmentState.running, timeLeft: int.tryParse(time)));
    } else if (code == ReceivedCommands.queueWorking) {
      Utils.printLogs("onValueReceived: queueWorking - $code");
      bloc.add(const DeviceQueueEvent(QueueState.working));
    } else if (code == ReceivedCommands.queueSuspended) {
      Utils.printLogs("onValueReceived: queueSuspended - $code");
      bloc.add(const DeviceQueueEvent(QueueState.suspended));
    } else if (code == ReceivedCommands.queueFinished) {
      Utils.printLogs("onValueReceived: queueFinished - $code");
      bloc.add(const DeviceQueueEvent(QueueState.finished));
    } else if (code == ReceivedCommands.verifyComm) {
      Utils.printLogs("onValueReceived: verifyComm - $code");
      if (waitingForInitialRequest) {
        Utils.printLogs("Got initial request: - Connected");
        bloc.add(const DeviceDiscoveryEvent(UVDeviceConnectionState.connected));
        waitingForInitialRequest = false;
        await _characteristic!.write(Commands.queryStatus.codeUnits, withoutResponse: true);
        _startHeartBeat();
      }
    } else {
      Utils.printLogs("onValueReceived: $code");
    }
  }

  _startHeartBeat() async {
    _stopTimer();
    _heartBeatTimer = Timer.periodic(const Duration(seconds: 10), (t) {
      if (isUVDeviceConnected && !isTreatmentRunning && !_isScanning) {
        _characteristic!.write(Commands.verifyComm.codeUnits, withoutResponse: true);
        Utils.printLogs("Heart beat verify comm");
      } else {
        Utils.printLogs("Heart beat is running but didn't sent any Command");
      }
      if (!isUVDeviceConnected) {
        _stopTimer();
        Utils.printLogs("Heart beat is running but device is not connected.");
      }
    });
  }

  Future<void> connectWithUVDevice() async {
    if (!await _checkForMocking()) {
      if (!_isScanning) {
        _stopTimer();
        waitingForInitialRequest = false;
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

  _stopTimer() {
    if (_heartBeatTimer != null) {
      Utils.printLogs("Cancelling timer");
      try {
        _heartBeatTimer!.cancel();
      } catch (e) {
        Utils.printLogs("Error while cancelling timer");
      }
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
