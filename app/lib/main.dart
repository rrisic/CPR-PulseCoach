import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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

class _InputGraphWidgetState extends State<InputGraphWidget> {
  final TextEditingController _controller = TextEditingController();
  List<double> recentNumbers = [];

  // Function to round up maxY to a sensible value
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
                        recentNumbers.removeAt(0); // Remove oldest number
                      }
                      recentNumbers.add(number); // Add new number
                      _controller.clear(); // Clear the input field
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
          SizedBox(height: 20), // Spacing between input and graph

          // Graph Section
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0, // Y-axis lower bound at 0
                maxY: maxY, // Use the rounded maxY
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      recentNumbers.length,
                      (index) => FlSpot(index.toDouble(), recentNumbers[index]),
                    ),
                    isCurved: false, // Straight lines between points
                    color: Colors.blue, // Line color
                    barWidth: 2, // Line thickness
                    dotData: FlDotData(show: true), // Show dots at data points
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
                    axisNameWidget: Text('Number Value'),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true), // Show chart border
                gridData: FlGridData(show: true), // Show grid lines
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // Clean up the controller
    super.dispose();
  }
}