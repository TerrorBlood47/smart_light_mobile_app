import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

import 'package:syncfusion_flutter_gauges/gauges.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late BluetoothConnection bluetoothConnection;
  late BluetoothDevice bluetoothDevice;
  bool isConnected = false;
  double radialPWMvalue = 0.0;

  @override
  void initState() {
    super.initState();
    // _requestPermissionsAndConnect();
  }

  /// Request necessary Bluetooth permissions
  Future<void> _requestPermissionsAndConnect() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    final statuses = await permissions.request();

    if (statuses[Permission.bluetoothConnect]?.isGranted ?? false) {
      _connectToDevice();
    } else {
      debugPrint('Bluetooth permissions not granted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth permissions required')),
        );
      }
    }
  }

  Future<void> _connectToDevice() async {
    // if (bluetoothConnection.isConnected) return;

    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance
          .getBondedDevices();

      debugPrint("Available bonded devices: $devices");

      String deviceAddress = '00:24:09:01:1A:CD';
      BluetoothDevice? device;

      try {
        device = devices.firstWhere((d) => d.address == deviceAddress);
      } catch (e) {
        debugPrint('Device not found in bonded devices: $deviceAddress');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device not paired. Please pair the device first.'),
            ),
          );
        }
        return;
      }

      // Connect with baud rate ??? (common for STM32 UART) -- seem to detect automatically
      BluetoothConnection connection = await BluetoothConnection.toAddress(
        device.address,
      );

      setState(() {
        bluetoothDevice = device!;
        bluetoothConnection = connection;
        isConnected = true;
      });

      debugPrint('Connected to ${bluetoothDevice.name}');

      await _sendPWMvalue(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${bluetoothDevice.name}')),
        );
      }
    } catch (error) {
      debugPrint('Error connecting to device: $error');
      setState(() {
        isConnected = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection error: $error')));
      }
    }
  }

  Future<void> _disconnectFromDevice() async {
    try {
      if (isConnected && bluetoothConnection.isConnected) {
        
        await _sendPWMvalue(0); // ensure send completes

        await Future.delayed(Duration(milliseconds: 300)); // allow flush

        setState(() {
          radialPWMvalue = 0;
          isConnected = false;
        });

        await bluetoothConnection.close();
      }
    } catch (e) {
      debugPrint("error while disconnecting from device: $e");
    }
  }

  @override
  void dispose() {
    isConnected = false;
    bluetoothConnection.dispose();
    super.dispose();
  }

  /// Send data to STM32 MCU (115200 baud rate)
  void _sendDataToMCU(String data) {
    if (!bluetoothConnection.isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Device not connected')));
      return;
    }

    try {
      bluetoothConnection.output.add(Uint8List.fromList(data.codeUnits));
      debugPrint('Sent to MCU: $data');
    } catch (e) {
      debugPrint('Error sending data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send error: $e')));
    }
  }

  /// Listen for data from STM32 MCU
  // ignore: unused_element
  void _listenToMCU() {
    bluetoothConnection.input
        ?.listen((Uint8List data) {
          String receivedData = String.fromCharCodes(data);
          debugPrint('Received from MCU: $receivedData');
        })
        .onError((error) {
          debugPrint('Listen error: $error');
        });
  }

  Future<void> _sendPWMvalue(int value) async {
    // fromat: {VALUE}\r\n
    String sendMsg = "{$value}\r\n";
    _sendDataToMCU(sendMsg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("SMART LIGHT"), centerTitle: true),
      body: isConnected == false
          ? Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("Not connected"),
                SizedBox(height: 100),
                Center(
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(200),
                      onTap: () {
                        _requestPermissionsAndConnect();
                      },
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: FractionalOffset.topRight,
                            end: FractionalOffset.bottomLeft,
                            colors: [
                              Colors.lightBlue.shade100.withValues(alpha: 0.09),
                              Colors.lightBlue.shade700.withValues(alpha: 0.09),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.lightBlue.shade700.withValues(
                                alpha: 0.09,
                              ),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),

                        child: Container(
                          padding: EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: FractionalOffset.topRight,
                              end: FractionalOffset.bottomLeft,
                              colors: [
                                Colors.lightBlue.shade100.withValues(
                                  alpha: 0.09,
                                ),
                                Colors.lightBlue.shade700.withValues(
                                  alpha: 0.09,
                                ),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.lightBlue.shade700.withValues(
                                  alpha: 0.09,
                                ),
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),

                          child: Container(
                            padding: EdgeInsets.all(16),

                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: FractionalOffset.topRight,
                                end: FractionalOffset.bottomLeft,
                                colors: [
                                  Colors.blue.shade700,
                                  Colors.blue.shade200,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  spreadRadius: 5,
                                  blurRadius: 7,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              height: 120,
                              width: 120,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.power_settings_new,
                                    size: 28,
                                    color: Colors.blue,
                                  ),

                                  SizedBox(height: 4),

                                  Text(
                                    "Tap to Connect",
                                    style: TextStyle(
                                      fontFamily: 'Ubold',
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          :
            // WHEN NOT CONNECTED TO BLUETOOTH DEVICE
            Center(
              child: Column(
                children: [
                  Text("Connected"),
                  SizedBox(height: 50),
                  SfRadialGauge(
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: 0,
                        maximum: 100,
                        startAngle: 120,
                        endAngle: 360 + 60,
                        isInversed: true,
                        showLabels: false,
                        labelsPosition: ElementsPosition.inside,
                        showTicks: false,
                        radiusFactor: 0.7,
                        interval: 20,
                        showFirstLabel: true,
                        labelFormat: "{value}%",
                        axisLineStyle: const AxisLineStyle(
                          cornerStyle: CornerStyle.bothCurve,
                        ),
                        pointers: <GaugePointer>[
                          RangePointer(
                            value: radialPWMvalue,
                            cornerStyle: CornerStyle.bothCurve,
                            width: 20,
                            sizeUnit: GaugeSizeUnit.logicalPixel,
                            gradient: SweepGradient(
                              colors: [
                                Color(0xFF00C6FF),
                                Color(0xFF0072FF),
                                Color(0xFF8E2DE2),
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                          ),
                          MarkerPointer(
                            value: radialPWMvalue,
                            enableDragging: true,
                            onValueChanged: (value) {
                              setState(() {
                                radialPWMvalue = value;
                              });
                            },

                            onValueChangeEnd: (value) async {
                              await _sendPWMvalue(radialPWMvalue.ceil());
                            },

                            markerHeight: 30,
                            markerWidth: 30,
                            markerType: MarkerType.circle,
                            borderWidth: 2,
                            borderColor: Colors.blueAccent,
                          ),
                        ],

                        annotations: [
                          GaugeAnnotation(
                            angle: 90,
                            // axisValue: 5,
                            positionFactor: 0.00,
                            widget: Text(
                              "${radialPWMvalue.ceil().toString()}%",
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Container(
                    width: 220,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF8E2DE2),
                          Color(0xFF0072FF),
                          Color(0xFF00C6FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          // print("Button Pressed");
                          _disconnectFromDevice();
                        },
                        child: Center(
                          child: Text(
                            "Disconnect",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
