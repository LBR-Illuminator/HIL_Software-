#!/usr/bin/env python3
"""
Improved Serial Helper Library for Robot Framework with dedicated device connections

This library provides direct control over multiple serial ports simultaneously for Robot Framework tests,
supporting both text-based JSON protocol (Illuminator) and binary protocol (HIL).
"""

import time
import json
import struct
import serial
import serial.tools.list_ports

class ImprovedSerialHelper:
    """Improved Serial library for use with Robot Framework supporting multiple devices"""
    
    ROBOT_LIBRARY_SCOPE = 'SUITE'
    
    def __init__(self):
        """Initialize the library with separate connections for each device"""
        # Device-specific serial connections
        self.illuminator_serial = None
        self.hil_serial = None
        
        # Connection parameters for each device
        self.illuminator_port = None
        self.illuminator_baudrate = None
        self.illuminator_timeout = None
        
        self.hil_port = None
        self.hil_baudrate = None
        self.hil_timeout = None
        
        # Debug mode
        self.debug = True
    
    def open_illuminator_connection(self, port, baudrate=115200, timeout=5.0):
        """
        Open a dedicated serial connection to the Illuminator device
        
        Args:
            port: Serial port name (e.g., COM19, /dev/ttyUSB0)
            baudrate: Baud rate (default: 115200)
            timeout: Read timeout in seconds (default: 5.0)
            
        Returns:
            True if connection successful, False otherwise
        """
        try:
            # Close existing connection if any
            self.close_illuminator_connection()
            
            # Try to open the port
            self._log(f"Attempting to open Illuminator port {port} at {baudrate} baud")
            self.illuminator_serial = serial.Serial(
                port=port,
                baudrate=int(baudrate),
                timeout=float(timeout),
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE
            )
            
            self.illuminator_port = port
            self.illuminator_baudrate = baudrate
            self.illuminator_timeout = timeout
            
            self._log(f"Successfully opened Illuminator port {port}")
            return True
            
        except serial.SerialException as e:
            self._log(f"Error opening Illuminator port {port}: {str(e)}")
            self.list_available_ports()
            return False
    
    def open_hil_connection(self, port, baudrate=115200, timeout=5.0):
        """
        Open a dedicated serial connection to the HIL hardware
        
        Args:
            port: Serial port name (e.g., COM20, /dev/ttyUSB1)
            baudrate: Baud rate (default: 115200)
            timeout: Read timeout in seconds (default: 5.0)
            
        Returns:
            True if connection successful, False otherwise
        """
        try:
            # Close existing connection if any
            self.close_hil_connection()
            
            # Try to open the port
            self._log(f"Attempting to open HIL port {port} at {baudrate} baud")
            self.hil_serial = serial.Serial(
                port=port,
                baudrate=int(baudrate),
                timeout=float(timeout),
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE
            )
            
            self.hil_port = port
            self.hil_baudrate = baudrate
            self.hil_timeout = timeout
            
            self._log(f"Successfully opened HIL port {port}")
            return True
            
        except serial.SerialException as e:
            self._log(f"Error opening HIL port {port}: {str(e)}")
            self.list_available_ports()
            return False
    
    def close_illuminator_connection(self):
        """Close the Illuminator serial connection if open"""
        if self.illuminator_serial and self.illuminator_serial.is_open:
            self._log(f"Closing Illuminator port {self.illuminator_port}")
            self.illuminator_serial.close()
            self.illuminator_serial = None
    
    def close_hil_connection(self):
        """Close the HIL serial connection if open"""
        if self.hil_serial and self.hil_serial.is_open:
            self._log(f"Closing HIL port {self.hil_port}")
            self.hil_serial.close()
            self.hil_serial = None
    
    def close_all_connections(self):
        """Close all serial connections"""
        self.close_illuminator_connection()
        self.close_hil_connection()
    
    def is_illuminator_connected(self):
        """Check if Illuminator port is currently open"""
        return self.illuminator_serial is not None and self.illuminator_serial.is_open
    
    def is_hil_connected(self):
        """Check if HIL port is currently open"""
        return self.hil_serial is not None and self.hil_serial.is_open
    
    def send_illuminator_command(self, command_dict, timeout=5.0):
        """
        Send a JSON command to the Illuminator and get the response
        
        Args:
            command_dict: JSON command string or dictionary
            timeout: Read timeout in seconds
            
        Returns:
            Dictionary parsed from JSON response
        """
        if not self.is_illuminator_connected():
            raise Exception("Illuminator serial port is not open")
        
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
        
        # Ensure we have a newline at the end
        if not command_str.endswith('\n'):
            command_str += '\n'
        
        self._log(f"ILLUMINATOR TX: {command_str.strip()}")
        
        # Send the command
        self.illuminator_serial.write(command_str.encode('utf-8'))
        
        # Get the response with the specified timeout
        original_timeout = self.illuminator_serial.timeout
        try:
            if timeout is not None:
                self.illuminator_serial.timeout = float(timeout)
            
            response_str = self.illuminator_serial.readline().decode('utf-8').strip()
            self._log(f"ILLUMINATOR RX: {response_str}")
            
            # Parse and return JSON
            try:
                return json.loads(response_str)
            except json.JSONDecodeError:
                self._log(f"Invalid JSON response from Illuminator: {response_str}")
                return {"error": "Invalid JSON response", "raw_data": response_str}
        finally:
            # Restore original timeout
            self.illuminator_serial.timeout = original_timeout
    
    def send_hil_command(self, command, timeout=5.0):
        """
        Send a binary command to the HIL board and get the response
        
        Args:
            command: Binary command as bytes or bytearray
            timeout: Read timeout in seconds
            
        Returns:
            Bytes response
        """
        if not self.is_hil_connected():
            raise Exception("HIL serial port is not open")
        
        # Debug log the command bytes
        if self.debug:
            cmd_bytes = ' '.join([f'0x{b:02X}' for b in command])
            self._log(f"HIL TX: {cmd_bytes}")
        
        # Send the command
        self.hil_serial.write(command)
        
        # Wait for processing
        time.sleep(0.1)
        
        # Read the response with the specified timeout
        original_timeout = self.hil_serial.timeout
        try:
            if timeout is not None:
                self.hil_serial.timeout = float(timeout)
            
            # Read response (8 bytes for HIL protocol)
            response = self.hil_serial.read(8)
            
            # Debug log the response bytes
            if self.debug and response:
                resp_bytes = ' '.join([f'0x{b:02X}' for b in response])
                self._log(f"HIL RX: {resp_bytes}")
            
            return response
        finally:
            # Restore original timeout
            self.hil_serial.timeout = original_timeout
    
    def list_available_ports(self):
        """List all available serial ports"""
        ports = list(serial.tools.list_ports.comports())
        
        self._log(f"Found {len(ports)} serial ports:")
        for i, port in enumerate(ports):
            self._log(f"{i+1}. {port.device}: {port.description}")
        
        return [port.device for port in ports]
    
    def _log(self, message):
        """Internal logging function"""
        if self.debug:
            print(message)