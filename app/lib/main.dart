import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
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
    {'name': "Stayin' Alive", 'path': 'assets/stayinalive.mp3'},
    {'name': 'Life is a Highway', 'path': 'assets/highway.mp3'},
    {'name': 'Levitating', 'path': 'assets/levitating.mp3'},
    {'name': 'All Star', 'path': 'assets/allstar.mp3'}
  ];
  String? selectedAudioPath = 'metronome.mp3';

  // Animation for pulsating effect
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  final String targetDeviceName = "Arduino R4 WiFi";
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
    print('Starting Bluetooth scan...');
    print('Note: Please ensure Bluetooth and location permissions are granted in device settings.');

    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    StreamSubscription<ScanResult>? subscription;
    subscription = FlutterBluePlus.scan().listen((result) {
      print('Found device: ${result.device.name} (${result.device.id})');
      if (result.device.name == targetDeviceName) {
        setState(() {
          if (!scanResults.any((existing) => existing.device.id == result.device.id)) {
            scanResults.add(result);
          }
        });
      }
    }, onDone: () {
      subscription?.cancel();
      setState(() {
        isScanning = false;
      });
    }, onError: (e) {
      print('Error during Bluetooth scan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during scan: $e')),
      );
      subscription?.cancel();
      setState(() {
        isScanning = false;
      });
    });

    await Future.delayed(Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    print('Attempting to connect to device: ${device.name} (${device.id})');

    try {
      if (connectedDevice != null) {
        print('Disconnecting from previous device: ${connectedDevice!.name}');
        await connectedDevice!.disconnect();
        print('Disconnected from previous device');
      }

      print('Connecting to device...');
      await device.connect(timeout: Duration(seconds: 10));
      print('Successfully connected to device: ${device.name}');

      setState(() {
        connectedDevice = device;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
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
          print('Device disconnected: ${device.name}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Disconnected from ${device.name}')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LED turned ${ledState ? 'ON' : 'OFF'}')),
      );
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
                final isConnected = connectedDevice?.id == device.id;
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text(device.id.toString()),
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