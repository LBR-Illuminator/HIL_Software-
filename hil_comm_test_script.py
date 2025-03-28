#!/usr/bin/env python3
"""
HIL Communication Test Script
Tests connectivity and basic communication with Wiseled_LBR HIL system
"""

import serial
import struct
import time
import argparse

class HILProtocol:
    # Protocol Constants
    START_MARKER = 0xAA
    END_MARKER = 0x55

    # Command Types
    CMD_GET = ord('G')
    CMD_SET = ord('S')
    CMD_PING = ord('P')

    # Signal Types
    SIGNAL_PWM = ord('P')
    SIGNAL_CURRENT = ord('C')
    SIGNAL_TEMP = ord('T')

    @staticmethod
    def calculate_checksum(cmd, light, function, value):
        """Calculate XOR checksum"""
        checksum = cmd ^ light ^ function
        checksum ^= (value & 0xFF)
        checksum ^= ((value >> 8) & 0xFF)
        return checksum

    @staticmethod
    def create_message(cmd, light, function, value=0):
        """Create HIL protocol message"""
        checksum = HILProtocol.calculate_checksum(cmd, light, function, value)
        return struct.pack('<BBBBHBB', 
            HILProtocol.START_MARKER,  # Start marker
            cmd,                       # Command
            light,                     # Light/Channel
            function,                  # Signal type
            value,                     # Value
            checksum,                  # Checksum
            HILProtocol.END_MARKER     # End marker
        )

class HILTester:
    def __init__(self, port, baudrate=115200, timeout=1):
        """
        Initialize serial connection
        
        :param port: Serial port name
        :param baudrate: Communication baudrate
        :param timeout: Serial communication timeout
        """
        try:
            self.ser = serial.Serial(
                port=port, 
                baudrate=baudrate, 
                timeout=timeout
            )
        except serial.SerialException as e:
            print(f"Error opening serial port: {e}")
            raise

    def ping(self):
        """
        Send ping command and check response
        
        :return: Firmware version if successful, None otherwise
        """
        try:
            # Create ping message
            ping_msg = HILProtocol.create_message(
                HILProtocol.CMD_PING, 
                ord('S'),  # System channel 
                HILProtocol.SIGNAL_PWM  # Using PWM as system signal type
            )
            
            # Send ping
            self.ser.write(ping_msg)
            
            # Read response
            response = self.ser.read(8)
            
            # Validate response
            if len(response) != 8:
                print("Incomplete response received")
                return None
            
            # Unpack response
            unpacked = struct.unpack('<BBBBHBB', response)
            
            # Validate markers and response status
            if (unpacked[0] != HILProtocol.START_MARKER or 
                unpacked[1] != ord('O') or  # OK status
                unpacked[6] != HILProtocol.END_MARKER):
                print("Invalid response")
                return None
            
            # Extract firmware version
            firmware_version = unpacked[4]
            major = (firmware_version >> 8) & 0xFF
            minor = firmware_version & 0xFF
            
            print(f"Ping successful. Firmware version: {major}.{minor:02d}")
            return firmware_version
        
        except Exception as e:
            print(f"Ping failed: {e}")
            return None

    def close(self):
        """Close serial connection"""
        if hasattr(self, 'ser'):
            self.ser.close()

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Wiseled_LBR HIL Communication Test')
    parser.add_argument('port', type=str, help='Serial port to connect (e.g., /dev/ttyUSB0, COM3)')
    parser.add_argument('-b', '--baudrate', type=int, default=115200, 
                        help='Baudrate for serial communication (default: 115200)')
    
    # Parse arguments
    args = parser.parse_args()

    try:
        # Attempt to connect to the specified port
        tester = HILTester(port=args.port, baudrate=args.baudrate)
        
        # Try pinging 3 times
        for attempt in range(3):
            result = tester.ping()
            if result is not None:
                break
            time.sleep(0.5)
        
        # Close connection
        tester.close()
    
    except serial.SerialException as e:
        print(f"Serial connection error: {e}")
    except KeyboardInterrupt:
        print("\nTest interrupted by user")

if __name__ == '__main__':
    main()