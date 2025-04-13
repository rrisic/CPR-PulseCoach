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
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('CPR PulseCoach'),
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
  BluetoothCharacteristic? testCharacteristic;
  BluetoothCharacteristic? numberCharacteristic;
  BluetoothCharacteristic? testResultCharacteristic;
  bool ledState = false;
  int receivedNumber = 0;

  // Audio file selection
  final List<Map<String, String>> audioFiles = [
    {'name': "Stayin' Alive - Bee Gees", 'path': 'stayinalive.mp3'},
    {'name': 'Life is a Highway - Rascal Flatts', 'path': 'highway.mp3'},
    {'name': 'Levitating - Dua Lipa', 'path': 'levitating.mp3'},
    {'name': 'All Star - Smash Mouth', 'path': 'allstar.mp3'},
    {'name': 'Metronome', 'path': 'metronome.mp3'},
    {'name': 'Stressful Environment', 'path': 'panic.mp3'}
  ];
  String selectedAudioPath = 'metronome.mp3';

  // Animation for pulsating effect
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  final String targetDeviceName = "Arduino";
  final String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
  final String characteristicUuid = "19B10001-E8F2-537E-4F6C-D104768A1214";
  final String numberCharacteristicUuid = "19B10002-E8F2-537E-4F6C-D104768A1214";
  final String resultCharacteristicUuid = "19B10003-E8F2-537E-4F6C-D104768A1214";

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop); // Set audio to loop
    _playBackgroundMusic();

    // Initialize animation controller for pulsating effect
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 582), // Duration of one heartbeat cycle
    )..repeat(reverse: true); // Repeat the animation, reversing direction

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void showTimerPopup(BuildContext context) {
    int countdown = 3; // Start from 3 for "Starting test in"
    String title = "Starting test in";
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            timer ??= Timer.periodic(Duration(seconds: 1), (Timer t) {
              setPopupState(() {
                countdown--;
                if (countdown == 0 && title == "Starting test in") {
                  // Switch to Timer stage
                  title = "Timer";
                  countdown = 15;
                } else if (countdown == 0 && title == "Timer") {
                  t.cancel();
                  Navigator.of(context).pop();
                }
              });
            });

            return AlertDialog(
              title: Center(child: Text(title)),
              content: Text(
                "$countdown",
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showScorePopup(BuildContext context, int score) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("BPM"),
        content: Text(
          "$score",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close"),
          )
        ],
      ),
    );
  }
  void monitorConnectionState(BluetoothDevice device) {
    device.connectionState.listen((BluetoothConnectionState state) {
      setState((){
        connectedDevice = null;
      });
      if (state == BluetoothConnectionState.disconnected) {
        _startBluetoothScan();
      }
    });
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
              if (!scanResults.any((existing) => existing.device.remoteId == result.device.remoteId)) {
                setState(() {
                  scanResults.add(result);
                });
                break; // Move the break outside setState
              }
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
                testCharacteristic = characteristic;
              });
              print('Found target characteristic: $characteristicUuid');
              if (characteristic.properties.notify){
                await characteristic.setNotifyValue(true);
                characteristic.lastValueStream.listen((value) {
                  if (value.isNotEmpty && value[0] != 0) {
                    showTimerPopup(context);
                  }
                });
              }
            } if (characteristic.uuid.toString().toLowerCase() == numberCharacteristicUuid.toLowerCase()) {
              setState(() {
                numberCharacteristic = characteristic;
              });
              print('Found number characteristic: $numberCharacteristicUuid');
              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);
                characteristic.lastValueStream.listen((value) {
                  if (value.isNotEmpty) {
                    int received = value[0] |
                        (value[1] << 8) |
                        (value[2] << 16) |
                        (value[3] << 24);
                    print('Received number: $received');
                    setState(() {
                      receivedNumber = received;
                      if (recentNumbers.length >= 5) {
                        recentNumbers.removeAt(0);
                      }
                      recentNumbers.add(received.toDouble());
                    });
                  }
                });
              }
            } if (characteristic.uuid.toString().toLowerCase() == resultCharacteristicUuid.toLowerCase()){
              setState(() {
                testResultCharacteristic = characteristic;
              });
              print('Found target characteristic: $characteristicUuid');
              if (characteristic.properties.notify){
                await characteristic.setNotifyValue(true);
                characteristic.lastValueStream.listen((value) {
                  if (value.isNotEmpty) {
                    showScorePopup(context, value[0]);
                  }
                });
              }
            }
          }
        }
      }

      if (testCharacteristic == null) {
        print('Target characteristic not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Target characteristic not found')),
        );
      }

      device.connectionState.listen((state) {
        print('Device state changed: $state');
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            connectedDevice = null;
            testCharacteristic = null;
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

  

  double roundUpMaxY(double maxValue) {
    if (maxValue <= 0) return 10.0; // Default for no data or negative values

    // Determine the step size based on the magnitude of maxValue
    double step;
    if (maxValue <= 10) {
      step = 2; // Small numbers: step by 2 (e.g., 2, 4, 6, 8, 10)
    } else if (maxValue <= 50) {
      step = 10; // Medium numbers: step by 10 (e.g., 10, 20, 30, 40, 50)
    } else if (maxValue <= 200) {
      step = 20; // Larger numbers: step by 20 (e.g., 20, 40, 60, 80, 100)
    } else {
      step = 50; // Very large numbers: step by 50 (e.g., 50, 100, 150, 200)
    }

    // Round up to the nearest step
    return (maxValue / step).ceil() * step;
  }

  // function to color each point in the graph depending on if they are in range of good BPMs
  Color bpmToGradientColor(double bpm) {
    const Color goodColor = Colors.green;
    const Color warningColor = Color(0xFFFFC107); // Amber/yellow
    const Color dangerColor = Colors.red;
    const int minBPM = 96;
    const int maxBPM = 110;

    if (bpm >= minBPM && bpm <= maxBPM) {
      return goodColor;
    } 
    else if (bpm >= (minBPM * 3/4) && bpm < minBPM) {
      // Below range but not bad
      final ratio = (minBPM - bpm) / minBPM;
      return Color.lerp(goodColor, warningColor, ratio.clamp(0.0, 1.0))!;
    }
    else if (bpm <= (maxBPM * 4/3) && bpm > maxBPM) {
      // above range but not bad
      final ratio = (bpm - maxBPM) / maxBPM;
      return Color.lerp(goodColor, warningColor, ratio.clamp(0.0, 1.0))!;
    }
    else if (bpm >= (minBPM * 1/2) && bpm < (minBPM * 3/4)) {
      // pretty bad below range
      final ratio = (minBPM - bpm) / minBPM;
      return Color.lerp(warningColor, dangerColor, ratio.clamp(0.0, 1.0))!;
    }
    else if (bpm <= (maxBPM * 2) && bpm > (maxBPM * 4/3)) {
      // pretty bad above range
      final ratio = (bpm - maxBPM) / maxBPM;
      return Color.lerp(warningColor, dangerColor, ratio.clamp(0.0, 1.0))!;
    }
     else {
      // very bad
      return dangerColor;
    }
  }
  double _calculateAverage() {
    if (recentNumbers.isEmpty) return 0.0;
    return recentNumbers.reduce((a, b) => a + b) / recentNumbers.length;
  }
  @override
  Widget build(BuildContext context) {
    // Calculate maxY dynamically, default to 10 if no data
    double maxY = recentNumbers.isNotEmpty
        ? recentNumbers.reduce((a, b) => a > b ? a : b)
        : 10.0;
    maxY = roundUpMaxY(maxY); // Round up to a sensible value

    // Calculate the interval for y-axis ticks to align with maxY
    double yInterval;
    if (maxY <= 10) {
      yInterval = 2; // Small steps for small maxY
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
          // Pulsating Image and Average Value Display (Side by Side)
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the row contents
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Text(
                        '\u2665 BPM: ${_calculateAverage().toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Audio File Dropdown
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                icon: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('\u25BC', style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  )),
                ),
                value: selectedAudioPath,
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
            ),
          ),
          SizedBox(height: 20),
          // Input Section
          

          // Graph Section
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0, // Y-axis lower bound at 0
                maxY: maxY, // Use the rounded maxY
                lineBarsData: recentNumbers.isEmpty ? []
                : 
                recentNumbers.length == 1 ? [
                  // Single data point – show dot
                  LineChartBarData(
                    spots: [FlSpot(0, recentNumbers[0])],
                    isCurved: false,
                    color: bpmToGradientColor(recentNumbers[0]),
                    barWidth: 2,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ]
                :
                [
                  // Gradient background underlay that mimics the line color pattern
                  ...List.generate(
                    recentNumbers.length - 1,
                    (i) {
                      final p1 = FlSpot(i.toDouble(), recentNumbers[i]);
                      final p2 = FlSpot((i + 1).toDouble(), recentNumbers[i + 1]);

                      return LineChartBarData(
                        spots: [p1, p2],
                        isCurved: false,
                        barWidth: 0, // invisible line
                        color: Colors.transparent,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              // ignore: deprecated_member_use
                              bpmToGradientColor(p1.y).withOpacity(0.15),
                              // ignore: deprecated_member_use
                              bpmToGradientColor(p2.y).withOpacity(0.15),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      );
                    },
                  ),
              
                  // 1. Colored line segments with gradient
                  ...List.generate(
                    recentNumbers.length - 1,
                    (i) {
                      final p1 = FlSpot(i.toDouble(), recentNumbers[i]);
                      final p2 = FlSpot((i + 1).toDouble(), recentNumbers[i + 1]);

                      return LineChartBarData(
                        spots: [p1, p2],
                        isCurved: false,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),

                        // Gradient from p1 to p2 based on BPM range
                        gradient: LinearGradient(
                          colors: [
                            bpmToGradientColor(p1.y),
                            bpmToGradientColor(p2.y),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      );
                    },
                  ),

                  // 2. Dots with color-coded BPM
                  LineChartBarData(
                    spots: List.generate(
                      recentNumbers.length,
                      (index) => FlSpot(index.toDouble(), recentNumbers[index]),
                    ),
                    isCurved: false,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3.5,
                          color: bpmToGradientColor(spot.y),
                          strokeWidth: 0,
                        );
                      },
                    ),
                  ),
                ],

                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: EdgeInsets.only(top: 4), // Extra breathing room
                      child: Text(
                        'Time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    axisNameSize: 30, // Increased from default to avoid cutoff
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
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40, // Space for y-axis labels
                      interval: yInterval, // Set the y-axis tick interval
                      getTitlesWidget: (value, meta) {
                        // Only show labels up to maxY
                        if (value <= maxY) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 12),
                          );
                        }
                        return Text('');
                      },
                    ),
                    axisNameWidget: Text('BPM', style: TextStyle(fontWeight: FontWeight.bold)),
                    axisNameSize: 28, // space for the label
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true), // Show chart border
                gridData: FlGridData(show: true), // Show grid lines
              ),
            ),
          ),
          SizedBox(height: 80),

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