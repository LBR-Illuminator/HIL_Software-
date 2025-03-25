# Wiseled_LBR HIL Testing Framework

## Overview

This repository contains the Hardware-in-the-Loop (HIL) testing framework for the Wiseled_LBR Illuminator system. It provides automated testing capabilities for validating the communication protocol, control functions, and safety features of the illuminator hardware through its serial interface.

## Features

- **Comprehensive Test Suite**: Tests all aspects of the Wiseled_LBR communication protocol
- **Robot Framework Integration**: Utilizes industry-standard Robot Framework for readable, maintainable test scripts
- **JSON Protocol Support**: Full implementation of the Wiseled_LBR JSON communication protocol
- **Extensible Architecture**: Designed to be extended for additional test cases and hardware simulation
- **Detailed Reporting**: Generates comprehensive test reports and logs

## System Requirements

- Python 3.8 or newer
- USB-to-Serial adapter
- Wiseled_LBR Illuminator hardware (or simulation environment)
- Operating System: Windows, macOS, or Linux

## Project Structure

```
wiseled_hil/
├── requirements.txt        # Python package dependencies
├── README.md              # This file
├── run_tests.bat          # Windows test launcher script
├── run_tests.sh           # Linux/macOS test launcher script
├── wiseled_test_suite.robot # Main test suite file
├── resources/             # Resource files for test suite
│   ├── common.resource    # Common keywords and utilities
│   ├── json_utils.resource # JSON handling utilities
│   ├── serial_commands.resource # Serial communication commands
└── logs/                  # Test execution logs (created at runtime)
```

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/your-organization/wiseled-hil.git
cd wiseled-hil
```

### 2. Set Up a Virtual Environment (Recommended)

```bash
# Create a virtual environment
python -m venv venv

# Activate the virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

## Running Tests

### Using the Launcher Scripts

For Windows:
```bash
run_tests.bat [COM_PORT] [TAGS] [TIMEOUT]
```

For Linux/macOS:
```bash
./run_tests.sh [SERIAL_PORT] [TAGS] [TIMEOUT]
```

Examples:
```bash
# Windows - Run all tests on COM4 with default timeout
run_tests.bat COM4

# Linux - Run only communication tests on /dev/ttyUSB0 with 10 second timeout
./run_tests.sh /dev/ttyUSB0 communication 10
```

### Manual Robot Framework Execution

```bash
# Run all tests
robot wiseled_test_suite.robot

# Run with specific port
robot -v SERIAL_PORT:COM4 wiseled_test_suite.robot

# Run only tests with specific tag
robot -i light wiseled_test_suite.robot
```

## Available Test Tags

- `smoke`: Basic connectivity tests
- `communication`: Protocol communication tests
- `light`: Light control tests
- `status`: Sensor data and status tests
- `alarm`: Alarm handling tests

## Test Report

After test execution, Robot Framework generates several report files:
- `report.html`: Overview of test results
- `log.html`: Detailed test logs with execution steps
- `output.xml`: Machine-readable test results

These files are stored in the `logs/TIMESTAMP` directory and copied to the project root for easy access.

## Protocol Documentation

The Wiseled_LBR uses a JSON-based communication protocol with the following structure:

```json
{
  "type": "cmd|resp|event",
  "id": "unique-message-id",
  "topic": "light|status|system|alarm",
  "action": "specific-action",
  "data": {
    "key1": "value1",
    "key2": "value2"
  }
}
```

The protocol supports the following topics and actions:

### Light Control
- `get`: Get specific light intensity
- `get_all`: Get all light intensities
- `set`: Set specific light intensity
- `set_all`: Set all light intensities

### Status Queries
- `get_sensors`: Get sensor data for specific light
- `get_all_sensors`: Get sensor data for all lights

### System Commands
- `ping`: Check connectivity
- `info`: Get device information
- `reset`: Reset the device
- `get_error_log`: Retrieve error logs

### Alarm System
- `status`: Get alarm status
- `clear`: Clear alarms

## Future Development

This framework is designed to be extended in several ways:

1. **Hardware Simulation**: Adding a second STM32 board to simulate analog inputs
2. **Automated Performance Testing**: Implementing long-duration tests and performance benchmarks
3. **CI/CD Integration**: Adding continuous integration testing capabilities
4. **Fault Injection**: Simulating error conditions to test system robustness

## Troubleshooting

### Common Issues

1. **Serial Port Access**
   - Ensure correct port is specified
   - Check port permissions (Linux/macOS)
   - Make sure no other applications are using the port

2. **Connection Timeouts**
   - Increase timeout value
   - Check physical connections
   - Verify device is powered and running correct firmware

3. **Protocol Errors**
   - Verify firmware version is compatible with test suite
   - Check for JSON syntax errors in communication

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Project Maintainer - [your-email@example.com]

Project Link: [https://github.com/your-organization/wiseled-hil](https://github.com/your-organization/wiseled-hil)