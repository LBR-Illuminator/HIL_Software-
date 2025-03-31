#!/usr/bin/env python3
"""
Enhanced Serial Helper Library for Robot Framework

This library provides direct control over serial ports for Robot Framework tests,
with support for both text-based JSON protocol (Illuminator) and binary protocol (HIL).
"""

import sys
import time
import json
import struct
import serial
import serial.tools.list_ports

class EnhancedSerialHelper:
    """Enhanced Serial library for use with Robot Framework"""
    
    ROBOT_LIBRARY_SCOPE = 'SUITE'
    
    def __init__(self):
        """Initialize the library"""
        self.serial = None
        self.port = None
        self.baudrate = None
        self.timeout = None
        self.current_device = None  # 'illuminator' or 'hil'
    
    def open_serial_port(self, port, baudrate=115200, timeout=5.0, device_type='illuminator'):
        """
        Open a serial connection to the specified port
        
        Args:
            port: Serial port name (e.g., COM19, /dev/ttyUSB0)
            baudrate: Baud rate (default: 115200)
            timeout: Read timeout in seconds (default: 5.0)
            device_type: Type of device ('illuminator' or 'hil')
            
        Returns:
            True if connection successful, False otherwise
        """
        try:
            # Close any existing connection
            self.close_serial_port()
            
            # Try to open the port
            print(f"Attempting to open port {port} at {baudrate} baud for {device_type}")
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
            self.current_device = device_type
            
            print(f"Successfully opened port {port} for {device_type}")
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
            data: String data or bytes to write
            
        Returns:
            Number of bytes written
        """
        if not self.is_port_open():
            raise Exception("Serial port is not open")
        
        # Handle different data types based on current device
        if isinstance(data, str):
            # Text data for Illuminator
            # Ensure we have a newline at the end
            if not data.endswith('\n'):
                data += '\n'
            bytes_written = self.serial.write(data.encode('utf-8'))
        elif isinstance(data, (bytes, bytearray)):
            # Binary data for HIL
            bytes_written = self.serial.write(data)
        else:
            raise ValueError("Data must be string or bytes")
            
        return bytes_written
    
    def read_data(self, size=None, timeout=None):
        """
        Read data from the serial port
        
        Args:
            size: Number of bytes to read (default: None, read all available)
            timeout: Read timeout in seconds (default: use port timeout)
            
        Returns:
            Bytes data read
        """
        if not self.is_port_open():
            raise Exception("Serial port is not open")
        
        # Use the specified timeout or the port default
        original_timeout = self.serial.timeout
        try:
            if timeout is not None:
                self.serial.timeout = float(timeout)
            
            if size is None:
                # Read all available data
                data = self.serial.read_all()
            else:
                # Read specific number of bytes
                data = self.serial.read(size)
            
            return data
        finally:
            # Restore original timeout
            self.serial.timeout = original_timeout
    
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
    
    def send_illuminator_command(self, command_dict, timeout=5.0):
        """
        Send a JSON command to the Illuminator and get the response
        
        Args:
            command_dict: JSON command string or dictionary
            timeout: Read timeout in seconds
            
        Returns:
            Dictionary parsed from JSON response
        """
        if not self.is_port_open():
            raise Exception("Serial port is not open")
        
        # If data field is a string that looks like JSON, parse it
        if isinstance(command_dict, dict) and 'data' in command_dict and isinstance(command_dict['data'], str):
            if command_dict['data'].startswith('{') and command_dict['data'].endswith('}'):
                try:
                    command_dict['data'] = json.loads(command_dict['data'])
                except json.JSONDecodeError:
                    # Keep it as a string if it can't be parsed
                    pass

        # Convert dict to string if needed
        if isinstance(command_dict, dict):
            command_str = json.dumps(command_dict)
        else:
            command_str = command_dict
        
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
    
    def send_hil_command(self, command, timeout=5.0):
        """
        Send a binary command to the HIL board and get the response
        
        Args:
            command: Binary command as bytes or bytearray
            timeout: Read timeout in seconds
            
        Returns:
            Bytes response
        """
        if not self.is_port_open():
            raise Exception("Serial port is not open")
        
        # Send the command
        self.write_data(command)
        
        # Wait for processing
        time.sleep(0.1)
        
        # Read the response (8 bytes for HIL protocol)
        response = self.read_data(8, timeout)
        
        return response
    
    def list_available_ports(self):
        """List all available serial ports"""
        ports = list(serial.tools.list_ports.comports())
        
        print(f"Found {len(ports)} serial ports:")
        for i, port in enumerate(ports):
            print(f"{i+1}. {port.device}: {port.description}")
        
        return [port.device for port in ports]