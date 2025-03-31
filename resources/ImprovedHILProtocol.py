#!/usr/bin/env python3
"""
Improved HIL Protocol Helper for Wiseled_LBR Testing

This module provides functions to handle the binary communication protocol
with the Hardware-in-the-Loop (HIL) testing hardware, using a dedicated
serial connection.
"""

import struct
import time

class ImprovedHILProtocol:
    """Helper class for HIL protocol operations with dedicated serial connection"""
    
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
        self.debug = True

    def set_serial_helper(self, serial_helper_name):
        """Set the serial helper by name"""
        # Try to get the library instance from Robot Framework
        try:
            from robot.libraries.BuiltIn import BuiltIn
            self.serial = BuiltIn().get_library_instance(serial_helper_name)
            
            # Verify the helper was set correctly
            if self.serial and hasattr(self.serial, 'is_hil_connected'):
                print(f"Successfully set serial helper: {self.serial}")
            else:
                print(f"Warning: Serial helper doesn't have expected methods: {self.serial}")
        except Exception as e:
            # Fall back to direct reference if BuiltIn approach fails
            print(f"Error using Robot BuiltIn: {e}")
            print(f"Trying direct approach with name: {serial_helper_name}")
            
            # In this case, assume the actual helper object was passed
            if isinstance(serial_helper_name, object) and hasattr(serial_helper_name, 'is_hil_connected'):
                self.serial = serial_helper_name
                print(f"Successfully set serial helper directly: {self.serial}")
    
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
        cmd_byte = ord(cmd_type) if isinstance(cmd_type, str) else cmd_type
        light_byte = ord(light_id) if isinstance(light_id, str) else light_id
        signal_byte = ord(signal_type) if isinstance(signal_type, str) else signal_type
        
        # Ensure value is an integer
        value = int(value)
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
        
        if self.debug:
            cmd_str = ' '.join([f'0x{b:02X}' for b in command])
            print(f"HIL Command: {cmd_str}")
        
        return command
    
    def parse_response(self, response_bytes):
        """
        Parse a HIL response
        
        Args:
            response_bytes: Bytes object containing the response
            
        Returns:
            Dictionary with parsed response data
        """
        if self.debug and response_bytes:
            resp_str = ' '.join([f'0x{b:02X}' for b in response_bytes])
            print(f"HIL Response: {resp_str}")
            
        # Check if response has valid length
        if len(response_bytes) < 4:
            return {'error': 'Response too short'}
            
        # Check start and end markers
        if response_bytes[0] != self.START_MARKER or response_bytes[-1] != self.END_MARKER:
            return {'error': 'Invalid markers'}
        
        # Check for OK response (cmd byte is 'O')
        if response_bytes[1] == ord('O') or response_bytes[1] == ord(self.RESPONSE_OK):
            # This is a success response
            if len(response_bytes) == 8:
                # Full response with data
                light_byte = response_bytes[2]
                signal_byte = response_bytes[3]
                value_low = response_bytes[4]
                value_high = response_bytes[5]
                checksum = response_bytes[6]
                
                # Combine value bytes (little endian)
                value = value_low | (value_high << 8)
                
                # For ping responses, the value is the firmware version
                if light_byte == ord('S') and signal_byte == ord('S'):
                    # This is a system response
                    major_version = value_high  # High byte is major version
                    minor_version = value_low   # Low byte is minor version
                    firmware_version = f"{major_version}.{minor_version}"
                    
                    return {
                        'status': 'ok',
                        'type': 'system',
                        'firmware_version': firmware_version,
                        'raw_value': value
                    }
                else:
                    # This is a regular data response
                    return {
                        'status': 'ok',
                        'light': chr(light_byte),
                        'signal': chr(signal_byte),
                        'value': value
                    }
            else:
                # Simple OK response without data
                return {'status': 'ok'}
        elif response_bytes[1] == ord('N') or response_bytes[1] == ord(self.RESPONSE_ERROR):
            # This is an error response
            return {'status': 'error'}
        else:
            # Unknown response type
            return {'error': f'Unknown response type: {chr(response_bytes[1])}'}
    
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
        if not self.serial:
            raise ValueError("Serial helper is not set")
            
        if not self.serial.is_hil_connected():
            raise ConnectionError("HIL serial port is not connected")
        
        # Create command
        command = self.create_command(cmd_type, light_id, signal_type, value)
        
        # Send command and get response
        response = self.serial.send_hil_command(command)
        
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
        
        if response.get('status') == 'ok' and 'value' in response:
            # Scale value to percentage if needed (assuming raw value is 0-32767)
            raw_value = response.get('value')
            
            # If value is already 0-100, return as is
            if raw_value <= 100:
                return raw_value
            else:
                # Scale from 0-32767 to 0-100
                percentage = (raw_value / 32767) * 100
                return round(percentage, 1)
        else:
            print(f"Error getting PWM duty cycle: {response}")
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
            
        # Scale current from 0-33000mA to 0-32767 value if needed
        if current_ma > 32767:
            scaled_value = min(32767, int((current_ma / 33000) * 32767))
        else:
            scaled_value = current_ma
            
        response = self.send_command(self.CMD_SET, light_id, self.SIGNAL_CURRENT, scaled_value)
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
        
        # Scale temperature from 0-330°C to 0-32767 value if needed
        if temperature_c > 32767:
            scaled_value = min(32767, int((temperature_c / 330) * 32767))
        else:
            scaled_value = int(temperature_c)
                
        response = self.send_command(self.CMD_SET, light_id, self.SIGNAL_TEMPERATURE, scaled_value)
        return response.get('status') == 'ok'
    
    def ping(self):
        """
        Send ping command to HIL
        
        Returns:
            Response dictionary including firmware version if successful
        """
        response = self.send_command(self.CMD_PING, 'S', self.SIGNAL_SYSTEM, 0)
        
        if self.debug:
            if response.get('status') == 'ok':
                if 'firmware_version' in response:
                    print(f"HIL Ping successful - Firmware version: {response['firmware_version']}")
                else:
                    print(f"HIL Ping successful")
            else:
                print(f"HIL Ping failed: {response}")
                
        return response