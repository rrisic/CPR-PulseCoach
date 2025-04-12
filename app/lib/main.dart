import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io' show Platform;

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize FlutterBluePlus
  try {
    if (Platform.isIOS) {
      // For iOS, initialize FlutterBluePlus with specific configurations
      print('Initializing FlutterBluePlus for iOS');
      await FlutterBluePlus.setLogLevel(LogLevel.verbose);
    }
  } catch (e) {
    print('Error initializing FlutterBluePlus: $e');
  }
  
  runApp(MyApp());
}

Future<Map<String, bool>> requestPermissions() async {
  Map<String, bool> permissionResults = {
    'bluetooth': false,
    'bluetoothScan': false, 
    'bluetoothConnect': false,
  };

  // Print initial status for debugging
  print('Initial bluetooth status: ${await Permission.bluetooth.status}');
  print('Initial bluetoothScan status: ${await Permission.bluetoothScan.status}');
  print('Initial bluetoothConnect status: ${await Permission.bluetoothConnect.status}');

  try {
    // For iOS, we need to request Location permission first
    // as it's often a prerequisite for Bluetooth scanning
    if (Platform.isIOS) {
      // Request Location first (this should trigger the iOS system prompt)
      

      
      // Then request bluetooth permissions
      if (await Permission.bluetooth.status != PermissionStatus.granted) {
        final bluetoothStatus = await Permission.bluetooth.request();
        print('Bluetooth permission after request: $bluetoothStatus');
        permissionResults['bluetooth'] = bluetoothStatus.isGranted;
      } else {
        permissionResults['bluetooth'] = true;
      }
      
      // Apply the same pattern to other permissions with delays between
      await Future.delayed(Duration(milliseconds: 5000));
      
      if (await Permission.bluetoothScan.status != PermissionStatus.granted) {
        final scanStatus = await Permission.bluetoothScan.request();
        print('Bluetooth Scan permission after request: $scanStatus');
        permissionResults['bluetoothScan'] = scanStatus.isGranted;
      } else {
        permissionResults['bluetoothScan'] = true;
      }
      
      await Future.delayed(Duration(milliseconds: 5000));
      
      if (await Permission.bluetoothConnect.status != PermissionStatus.granted) {
        final connectStatus = await Permission.bluetoothConnect.request();
        print('Bluetooth Connect permission after request: $connectStatus');
        permissionResults['bluetoothConnect'] = connectStatus.isGranted;
      } else {
        permissionResults['bluetoothConnect'] = true;
      }
    } else {
      // Android handling
      // Request permissions in sequence
      final bluetoothStatus = await Permission.bluetooth.request();
      permissionResults['bluetooth'] = bluetoothStatus.isGranted;
      
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      permissionResults['bluetoothScan'] = bluetoothScanStatus.isGranted;
      
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      permissionResults['bluetoothConnect'] = bluetoothConnectStatus.isGranted;
    }

    // Check if any permission was denied
    if (permissionResults.containsValue(false)) {
      print('Some permissions were not granted: $permissionResults');
      
      // Check if all permissions are permanently denied
      if (await Permission.bluetooth.isPermanentlyDenied &&
          await Permission.bluetoothScan.isPermanentlyDenied &&
          await Permission.bluetoothConnect.isPermanentlyDenied) {
        print('All permissions are permanently denied. Open app settings...');
      }
    } else {
      print('All permissions granted successfully');
    }

    return permissionResults;
  } catch (e) {
    print('Error requesting permissions: $e');
    return permissionResults;
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Recent Inputs Graph'),
        ),
        body: InputGraphWidget(),
      ),
    );
  }
}

class InputGraphWidget extends StatefulWidget {
  @override
  _InputGraphWidgetState createState() => _InputGraphWidgetState();
}

class _InputGraphWidgetState extends State<InputGraphWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  List<double> recentNumbers = [];
  late AudioPlayer _audioPlayer;
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;
  bool ledState = false;

  // Audio file selection
  final List<Map<String, String>> audioFiles = [
    {'name': "Stayin' Alive", 'path': 'stayinalive.mp3'},
    {'name': 'Life is a Highway', 'path': 'highway.mp3'},
    {'name': 'Levitating', 'path': 'levitating.mp3'},
    {'name': 'All Star', 'path': 'allstar.mp3'},
    {'name': 'Metronome', 'path': 'metronome.mp3'}
  ];
  String? selectedAudioPath = 'metronome.mp3';

  // Animation for pulsating effect
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  final String targetDeviceName = "Arduino";
  final String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
  final String characteristicUuid = "19B10001-E8F2-537E-4F6C-D104768A1214";

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop); // Set audio to loop
    _playBackgroundMusic();

    // Initialize animation controller for pulsating effect
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800), // Duration of one heartbeat cycle
    )..repeat(reverse: true); // Repeat the animation, reversing direction

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _playBackgroundMusic() async {
    try {
      await _audioPlayer.setVolume(0.5);
      await _audioPlayer.play(AssetSource(selectedAudioPath!));
      print('Playing audio: $selectedAudioPath at ${DateTime.now()}');
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void _changeAudio(String newAudioPath) async {
    try {
      setState(() {
        selectedAudioPath = newAudioPath;
      });
      await _audioPlayer.stop();
      await _playBackgroundMusic();
    } catch (e) {
      print('Error changing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error changing audio: $e')),
      );
    }
  }

  Future<void> _startBluetoothScan() async {
  
  // If we get here, we should have permissions
  setState(() {
    isScanning = true;
    scanResults.clear();
  });
  
  try {
    // Use a different approach to start scanning
    print('Starting scan with permissions');
    
    // Use the listeners approach
    var subscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult result in results) {
          print('Device found: ${result.device.platformName} (${result.device.remoteId})');
          if (result.device.platformName == targetDeviceName) {
            setState(() {
              if (!scanResults.any((existing) => existing.device.remoteId == result.device.remoteId)) {
                scanResults.add(result);
              }
            });
          }
        }
      },
      onError: (e) {
        print('Scan results error: $e');
        setState(() {
          isScanning = false;
        });
      },
      onDone: () {
        setState(() {
          isScanning = false;
        });
      },
    );
    
    // Start scan with specific settings for iOS
    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: 4),
      androidUsesFineLocation: true,
    );
    
    // Cancel the subscription after scan timeout
    Future.delayed(Duration(seconds: 5)).then((_) {
      subscription.cancel();
      if (isScanning) {
        try {
          FlutterBluePlus.stopScan();
        } catch (e) {
          print('Error stopping scan: $e');
        }
        setState(() {
          isScanning = false;
        });
      }
    });
  } catch (e) {
    print('Error in Bluetooth scan: $e');
    setState(() {
      isScanning = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scan error: $e')),
    );
  }
}

  Future<void> _connectToDevice(BluetoothDevice device) async {
    print('Attempting to connect to device: ${device.platformName} (${device.remoteId})');

    try {
      if (connectedDevice != null) {
        print('Disconnecting from previous device: ${connectedDevice!.platformName}');
        await connectedDevice!.disconnect();
        print('Disconnected from previous device');
      }

      print('Connecting to device...');
      await device.connect(timeout: Duration(seconds: 10));
      print('Successfully connected to device: ${device.platformName}');

      setState(() {
        connectedDevice = device;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.platformName}')),
      );

      print('Discovering services...');
      List<BluetoothService> services = await device.discoverServices();
      print('Found ${services.length} services');

      for (BluetoothService service in services) {
        print('Service UUID: ${service.uuid.toString()}');
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          print('Found target service: $serviceUuid');
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            print('Characteristic UUID: ${characteristic.uuid.toString()}');
            if (characteristic.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              setState(() {
                targetCharacteristic = characteristic;
              });
              print('Found target characteristic: $characteristicUuid');
              break;
            }
          }
        }
      }

      if (targetCharacteristic == null) {
        print('Target characteristic not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Target characteristic not found')),
        );
      }

      device.state.listen((state) {
        print('Device state changed: $state');
        if (state == BluetoothDeviceState.disconnected) {
          setState(() {
            connectedDevice = null;
            targetCharacteristic = null;
            ledState = false;
          });
          print('Device disconnected: ${device.platformName}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Disconnected from ${device.platformName}')),
          );
        }
      });
    } catch (e) {
      print('Error connecting to device: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  Future<void> _toggleLed() async {
    if (targetCharacteristic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not connected to a device with the target characteristic')),
      );
      return;
    }

    try {
      setState(() {
        ledState = !ledState;
      });
      await targetCharacteristic!.write([ledState ? 1 : 0]);
      print('LED state set to: $ledState');
    } catch (e) {
      print('Error writing to characteristic: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error controlling LED: $e')),
      );
    }
  }

  double roundUpMaxY(double maxValue) {
    if (maxValue <= 0) return 10.0;

    double step;
    if (maxValue <= 10) {
      step = 2;
    } else if (maxValue <= 50) {
      step = 10;
    } else if (maxValue <= 200) {
      step = 20;
    } else {
      step = 50;
    }
    return (maxValue / step).ceil() * step;
  }

  double _calculateAverage() {
    if (recentNumbers.isEmpty) return 0.0;
    return recentNumbers.reduce((a, b) => a + b) / recentNumbers.length;
  }

  @override
  Widget build(BuildContext context) {
    double maxY = recentNumbers.isNotEmpty
        ? recentNumbers.reduce((a, b) => a > b ? a : b)
        : 10.0;
    maxY = roundUpMaxY(maxY);

    double yInterval;
    if (maxY <= 10) {
      yInterval = 2;
    } else if (maxY <= 50) {
      yInterval = 10;
    } else if (maxY <= 200) {
      yInterval = 20;
    } else {
      yInterval = 50;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pulsating Average Value Display
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Text(
                    'Average: ${_calculateAverage().toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                );
              },
            ),
          ),

          // Audio File Dropdown
          DropdownButton<String>(
            value: selectedAudioPath,
            hint: Text('Select an audio file'),
            isExpanded: true,
            items: audioFiles.map((audio) {
              return DropdownMenuItem<String>(
                value: audio['path'],
                child: Text(audio['name']!),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                _changeAudio(newValue);
              }
            },
          ),
          SizedBox(height: 20),

          
          // Input Section
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Enter a number',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  String input = _controller.text;
                  try {
                    double number = double.parse(input);
                    setState(() {
                      if (recentNumbers.length >= 5) {
                        recentNumbers.removeAt(0);
                      }
                      recentNumbers.add(number);
                      _controller.clear();
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid number')),
                    );
                  }
                },
                child: Text('Add'),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Graph Section
          Expanded(
            flex: 2,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      recentNumbers.length,
                      (index) => FlSpot(index.toDouble(), recentNumbers[index]),
                    ),
                    isCurved: false,
                    color: Colors.blue,
                    barWidth: 2,
                    dotData: FlDotData(show: true),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < recentNumbers.length) {
                          return Text(
                            (index + 1).toString(),
                            style: TextStyle(fontSize: 12),
                          );
                        }
                        return Text('');
                      },
                    ),
                    axisNameWidget: Text('Input Order'),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value <= maxY) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 12),
                          );
                        }
                        return Text('');
                      },
                    ),
                    axisNameWidget: Text('Number Value'),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                gridData: FlGridData(show: true),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Bluetooth Scan Button
          ElevatedButton(
            onPressed: isScanning ? null : _startBluetoothScan,
            child: Text(isScanning ? 'Scanning...' : 'Scan for Arduino R4 WiFi'),
          ),
          SizedBox(height: 10),

          // Bluetooth Scan Results with Connect Button
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final result = scanResults[index];
                final device = result.device;
                final isConnected = connectedDevice?.remoteId == device.remoteId;
                return ListTile(
                  title: Text(device.platformName),
                  subtitle: Text(device.remoteId.toString()),
                  trailing: ElevatedButton(
                    onPressed: isConnected ? null : () => _connectToDevice(device),
                    child: Text(isConnected ? 'Connected' : 'Connect'),
                  ),
                );
              },
            ),
          ),

          // LED Control Button
          ElevatedButton(
            onPressed: connectedDevice != null ? _toggleLed : null,
            child: Text(ledState ? 'Turn LED OFF' : 'Turn LED ON'),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _controller.dispose();
    FlutterBluePlus.stopScan();
    connectedDevice?.disconnect();
    _animationController.dispose();
    super.dispose();
  }
}