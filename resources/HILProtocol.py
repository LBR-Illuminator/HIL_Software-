#!/usr/bin/env python3
"""
HIL Protocol Helper for Wiseled_LBR Testing

This module provides functions to handle the binary communication protocol
with the Hardware-in-the-Loop (HIL) testing hardware.
"""

import struct
import time

class HILProtocol:
    """Helper class for HIL protocol operations"""
    
    # Protocol constants
    START_MARKER = 0xAA
    END_MARKER = 0x55
    
    # Command types
    CMD_GET = 'G'
    CMD_SET = 'S'
    CMD_PING = 'P'
    
    # Signal types
    SIGNAL_PWM = 'P'         # PWM measurement
    SIGNAL_CURRENT = 'C'     # Current simulation
    SIGNAL_TEMPERATURE = 'T' # Temperature simulation
    SIGNAL_SYSTEM = 'S'      # System command
    
    # Response status
    RESPONSE_OK = 'O'
    RESPONSE_ERROR = 'N'

    def __init__(self, serial_helper=None):
        """
        Initialize with a SerialHelper instance
        
        Args:
            serial_helper: Instance of SerialHelper for serial communication
        """
        self.serial = serial_helper

    def set_serial_helper(self, serial_helper):
        """Set the serial helper after initialization"""
        self.serial = serial_helper
    
    def create_command(self, cmd_type, light_id, signal_type, value):
        """
        Create a HIL command frame
        
        Args:
            cmd_type: Command type ('G', 'S', 'P')
            light_id: Light ID (1, 2, 3)
            signal_type: Signal type ('P', 'C', 'T', 'S')
            value: Command value (16-bit integer)
            
        Returns:
            Bytes object containing the complete command frame
        """
        # Convert light_id to string if it's a number
        if isinstance(light_id, int):
            light_id = str(light_id)
            
        # Convert values to appropriate types
        cmd_byte = cmd_type.encode('ascii')[0]
        light_byte = light_id.encode('ascii')[0]
        signal_byte = signal_type.encode('ascii')[0]
        value_bytes = struct.pack("<H", value)  # Little-endian 16-bit value
        
        # Calculate checksum (XOR of all data bytes)
        checksum = cmd_byte ^ light_byte ^ signal_byte ^ value_bytes[0] ^ value_bytes[1]
        
        # Create command frame
        command = bytearray([
            self.START_MARKER,  # Start marker
            cmd_byte,           # Command type
            light_byte,         # Light ID
            signal_byte,        # Signal type
            value_bytes[0],     # Value (low byte)
            value_bytes[1],     # Value (high byte)
            checksum,           # Checksum
            self.END_MARKER     # End marker
        ])
        
        return command
    
    def parse_response(self, response_bytes):
        """
        Parse a HIL response
        
        Args:
            response_bytes: Bytes object containing the response
            
        Returns:
            Dictionary with parsed response data
        """
        # Check if response has valid length
        if len(response_bytes) < 4:
            return {'error': 'Response too short'}
            
        # Check start and end markers
        if response_bytes[0] != self.START_MARKER or response_bytes[-1] != self.END_MARKER:
            return {'error': 'Invalid markers'}
            
        # Extract response data
        if len(response_bytes) == 4:
            # Simple status response
            status_byte = response_bytes[1]
            checksum = response_bytes[2]
            
            # Check checksum
            if checksum != status_byte:
                return {'error': 'Invalid checksum'}
                
            # Parse status
            if status_byte == ord(self.RESPONSE_OK):
                return {'status': 'ok'}
            else:
                return {'status': 'error'}
        elif len(response_bytes) == 8:
            # Data response
            light_byte = response_bytes[1]
            signal_byte = response_bytes[2]
            value_low = response_bytes[3]
            value_high = response_bytes[4]
            checksum = response_bytes[5]
            
            # Check checksum
            if checksum != (light_byte ^ signal_byte ^ value_low ^ value_high):
                return {'error': 'Invalid checksum'}
                
            # Combine value bytes
            value = value_low | (value_high << 8)
            
            # Parse response
            return {
                'light': chr(light_byte),
                'signal': chr(signal_byte),
                'value': value,
                'status': 'ok'
            }
        else:
            return {'error': 'Invalid response length'}
    
    def send_command(self, cmd_type, light_id, signal_type, value):
        """
        Send a command to the HIL board and get the response
        
        Args:
            cmd_type: Command type ('G', 'S', 'P')
            light_id: Light ID (1, 2, 3)
            signal_type: Signal type ('P', 'C', 'T', 'S')
            value: Command value (16-bit integer)
            
        Returns:
            Dictionary with parsed response data
        """
        # Create command
        command = self.create_command(cmd_type, light_id, signal_type, value)
        
        # Send command
        self.serial.write(command)
        
        # Wait for response
        time.sleep(0.1)
        
        # Read response
        response = self.serial.read(8)
        
        # Parse response
        return self.parse_response(response)
    
    def get_pwm_duty_cycle(self, light_id):
        """
        Get PWM duty cycle for a specific light
        
        Args:
            light_id: Light ID (1, 2, 3)
            
        Returns:
            PWM duty cycle (0-100%), or None if error
        """
        response = self.send_command(self.CMD_GET, light_id, self.SIGNAL_PWM, 0)
        
        if response.get('status') == 'ok':
            return response.get('value')
        else:
            return None
    
    def set_current_simulation(self, light_id, current_ma):
        """
        Set current simulation for a specific light
        
        Args:
            light_id: Light ID (1, 2, 3)
            current_ma: Current in milliamps (0-33000)
            
        Returns:
            True if successful, False otherwise
        """
        # Ensure both arguments are integers
        try:
            light_id = int(light_id)
            current_ma = int(current_ma)
        except (ValueError, TypeError):
            print(f"Error converting arguments to integers: light_id={light_id}, current_ma={current_ma}")
            return False
            
        response = self.send_command(self.CMD_SET, light_id, self.SIGNAL_CURRENT, current_ma)
        return response.get('status') == 'ok'

    def set_temperature_simulation(self, light_id, temperature_c):
        """
        Set temperature simulation for a specific light
        
        Args:
            light_id: Light ID (1, 2, 3)
            temperature_c: Temperature in degrees Celsius (0-330)
            
        Returns:
            True if successful, False otherwise
        """
        # Ensure light_id is an integer
        try:
            light_id = int(light_id)
            temperature_c = float(temperature_c)
        except (ValueError, TypeError):
            print(f"Error converting arguments to numbers: light_id={light_id}, temperature_c={temperature_c}")
            return False
        
        # Convert to tenths of a degree if needed
        if temperature_c < 330:
            temp_value = int(temperature_c * 10)
        else:
            temp_value = int(temperature_c)
                
        response = self.send_command(self.CMD_SET, light_id, self.SIGNAL_TEMPERATURE, temp_value)
        return response.get('status') == 'ok'
    
    def ping(self):
        """
        Send ping command to HIL
        
        Returns:
            True if successful, False otherwise
        """
        response = self.send_command(self.CMD_PING, '1', self.SIGNAL_SYSTEM, 0)
        return response.get('status') == 'ok'
