#!/usr/bin/env python3
"""
Serial Helper Library for Robot Framework

This library provides direct control over serial ports for Robot Framework tests.
"""

import sys
import time
import json
import serial
import serial.tools.list_ports

class SerialHelper:
    """Custom Serial library for use with Robot Framework"""
    
    ROBOT_LIBRARY_SCOPE = 'SUITE'
    
    def __init__(self):
        """Initialize the library"""
        self.serial = None
        self.port = None
        self.baudrate = None
        self.timeout = None
    
    def open_serial_port(self, port, baudrate=115200, timeout=5.0):
        """
        Open a serial connection to the specified port
        
        Args:
            port: Serial port name (e.g., COM19, /dev/ttyUSB0)
            baudrate: Baud rate (default: 115200)
            timeout: Read timeout in seconds (default: 5.0)
            
        Returns:
            True if connection successful, False otherwise
        """
        print("----opening serial port")
        try:
            # Close any existing connection
            self.close_serial_port()
            
            # Try to open the port
            print(f"Attempting to open port {port} at {baudrate} baud")
            self.serial = serial.Serial(
                port=port,
                baudrate=int(baudrate),
                timeout=float(timeout),
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE
            )
            
            self.port = port
            self.baudrate = baudrate
            self.timeout = timeout
            
            print(f"Successfully opened port {port}")
            return True
            
        except serial.SerialException as e:
            print(f"Error opening port {port}: {str(e)}")
            self.list_available_ports()
            return False
    
    def close_serial_port(self):
        """Close the current serial connection if open"""
        if self.serial and self.serial.is_open:
            print(f"Closing port {self.port}")
            self.serial.close()
            self.serial = None
    
    def is_port_open(self):
        """Check if the port is currently open"""
        return self.serial is not None and self.serial.is_open
    
    def write_data(self, data):
        """
        Write data to the serial port
        
        Args:
            data: String data to write
            
        Returns:
            Number of bytes written
        """
        if not self.is_port_open():
            raise Exception("Serial port is not open")
        
        # Ensure we have a newline at the end
        if not data.endswith('\n'):
            data += '\n'
            
        bytes_written = self.serial.write(data.encode('utf-8'))
        return bytes_written
    
    def read_until_newline(self, timeout=None):
        """
        Read data until a newline character is found
        
        Args:
            timeout: Read timeout in seconds (default: use port timeout)
            
        Returns:
            String data read
        """
        if not self.is_port_open():
            raise Exception("Serial port is not open")
        
        # Use the specified timeout or the port default
        original_timeout = self.serial.timeout
        try:
            if timeout is not None:
                self.serial.timeout = float(timeout)
            
            data = self.serial.readline().decode('utf-8')
            return data
        finally:
            # Restore original timeout
            self.serial.timeout = original_timeout
    
    def send_command_and_get_response(self, command_json, timeout=5.0):
        """
        Send a JSON command and get the response
        
        Args:
            command_json: JSON command string or dictionary
            timeout: Read timeout in seconds
            
        Returns:
            Dictionary parsed from JSON response
        """
        if not self.is_port_open():
            raise Exception("Serial port is not open")
        
        # Convert dict to string if needed
        if isinstance(command_json, dict):
            command_str = json.dumps(command_json)
        else:
            command_str = command_json
        
        # Send the command
        self.write_data(command_str)
        
        # Get the response
        response_str = self.read_until_newline(timeout)
        
        # Parse and return JSON
        try:
            return json.loads(response_str)
        except json.JSONDecodeError:
            print(f"Invalid JSON response: {response_str}")
            return {"error": "Invalid JSON response", "raw_data": response_str}
    
    def list_available_ports(self):
        """List all available serial ports"""
        ports = list(serial.tools.list_ports.comports())
        
        print(f"Found {len(ports)} serial ports:")
        for i, port in enumerate(ports):
            print(f"{i+1}. {port.device}: {port.description}")
        
        return [port.device for port in ports]