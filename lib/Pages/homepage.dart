import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late BluetoothConnection bluetoothConnection;
  late BluetoothDevice bluetoothDevice;
  bool isConnected = false;
  bool isBulbOn = false;
  int flag = 0;

  @override
  void initState() {
    super.initState();
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

      // await _sendPWMvalue(0);
      await turnBulbOff();

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
        await turnBulbOff();

        await Future.delayed(Duration(milliseconds: 300)); // allow flush

        setState(() {
          isBulbOn = false;
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
    isBulbOn = false;
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
      setState(() {
        if (flag == 0) {
          flag = 1;
        }
      });
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

  Future<void> turnBulbOn() async {
    // fromat: {VALUE}\r\n
    String sendMsg = "value{1}\r\n";
    setState(() {
      flag = 0;
    });
    _sendDataToMCU(sendMsg);
    setState(() {
      if (flag == 1) {
        isBulbOn = true;
      }
      flag = 0;
    });
  }

  Future<void> turnBulbOff() async {
    // fromat: {VALUE}\r\n
    String sendMsg = "value{0}\r\n";
    setState(() {
      flag = 0;
    });
    _sendDataToMCU(sendMsg);
    setState(() {
      if (flag == 1) {
        isBulbOn = false;
      }
      flag = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Theme.of(context).colorScheme.surface;

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
                        setState(() {
                          _requestPermissionsAndConnect();
                        });
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
                  SizedBox(height: 100),

                  GestureDetector(
                    onTap: () {
                      if (isBulbOn) {
                        turnBulbOff();
                      } else {
                        turnBulbOn();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: backgroundColor,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: isBulbOn ? 5.0 : 30.0,
                            offset: isBulbOn
                                ? Offset(-10, -10)
                                : Offset(-28, -28),
                            color: Colors.white,
                          ),
                          BoxShadow(
                            blurRadius: isBulbOn ? 5.0 : 30.0,
                            offset: isBulbOn ? Offset(10, 10) : Offset(28, 28),
                            color: Color(0xFFA7A9AF),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 200,
                        width: 200,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isBulbOn
                                  ? Icons.lightbulb
                                  : Icons.lightbulb_outline,
                              size: 64,
                              color: isBulbOn ? Colors.amber : Colors.blueGrey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isBulbOn ? 'LIGHT ON' : 'LIGHT OFF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isBulbOn
                                    ? Colors.amber.shade800
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Tap to toggle'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 200),

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
