import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uv_ble_sdk/bloc/uv_bloc.dart';
import 'package:uv_ble_sdk/enums/device_connection_state.dart';
import 'package:uv_ble_sdk/enums/treatment_state.dart';
import 'package:uv_ble_sdk/uv_ble_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UvBleSdk.instance.initialise(loggingEnabled: false);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _uvBleSdkPlugin = UvBleSdk.instance;
  bool isConnected = false;
  bool isTreatmentRunning = false;

  int? timeLeft;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: BlocConsumer<UVBloc, UVState>(
            bloc: _uvBleSdkPlugin.bloc,
            listener: (context, state) {
              if (state is DeviceConnectionState) {
                isConnected = state.state == UVDeviceConnectionState.connected;
              } else if (state is DeviceTreatmentState) {
                isTreatmentRunning = state.state == TreatmentState.running;
                if (isTreatmentRunning) {
                  timeLeft = state.timeLeft ?? 0;
                } else {
                  timeLeft == null;
                }
              }
            },
            builder: (context, state) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                      onPressed: !isConnected
                          ? () {
                              _uvBleSdkPlugin.connectWithUVDevice();
                            }
                          : null,
                      child: Text(isConnected ? "Connected" : "Start Connection")),
                  if (state is DeviceConnectionState &&
                      (state.state == UVDeviceConnectionState.connecting ||
                          state.state == UVDeviceConnectionState.scanning))
                    const CircularProgressIndicator(),
                  ElevatedButton(
                      onPressed: isConnected && !isTreatmentRunning
                          ? () {
                              _uvBleSdkPlugin.startTreatment(10);
                            }
                          : null,
                      child: Text(
                          isTreatmentRunning ? "Running- ${timeLeft}s" : "Start Treatment 10 sec")),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
