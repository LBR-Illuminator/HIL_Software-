#!/usr/bin/env python3
"""
Test script for EnhancedSerialHelper with HIL hardware

This script tests if the EnhancedSerialHelper class can successfully
connect to and communicate with the HIL hardware.
"""

import sys
import time
import os

# Add the resources directory to the path so we can import the helper
script_dir = os.path.dirname(os.path.abspath(__file__))
resources_dir = os.path.join(script_dir, 'resources')
sys.path.append(resources_dir)

# Import the EnhancedSerialHelper
try:
    from EnhancedSerialHelper import EnhancedSerialHelper
    print("Successfully imported EnhancedSerialHelper")
except ImportError as e:
    print(f"Error importing EnhancedSerialHelper: {e}")
    sys.exit(1)

def test_hil_connection(port="COM20", baudrate=115200, timeout=5.0):
    """Test connection to HIL hardware using EnhancedSerialHelper"""
    
    # Create an instance of the helper
    helper = EnhancedSerialHelper()
    print(f"Created EnhancedSerialHelper instance")
    
    # Try to open the port
    success = helper.open_serial_port(port, baudrate, timeout, "hil")
    if not success:
        print(f"Failed to open port {port}")
        return False
    
    print(f"Successfully opened port {port} for HIL communication")
    
    # Create a simple ping command (0xAA P 1 S 0000 <checksum> 0x55)
    # Command: P (ping)
    # Light: 1
    # Function: S (system)
    # Value: 0
    
    cmd_type = ord('P')
    light_id = ord('1')
    function = ord('S')
    value_low = 0
    value_high = 0
    
    # Calculate checksum (XOR of all data bytes)
    checksum = cmd_type ^ light_id ^ function ^ value_low ^ value_high
    
    # Create command frame
    command = bytearray([
        0xAA,       # Start marker
        cmd_type,   # Command type
        light_id,   # Light ID
        function,   # Function
        value_low,  # Value (low byte)
        value_high, # Value (high byte)
        checksum,   # Checksum
        0x55        # End marker
    ])
    
    print(f"Sending HIL ping command: {' '.join(f'0x{b:02X}' for b in command)}")
    
    # Send the command
    helper.write_data(command)
    
    # Wait for response
    time.sleep(0.1)
    
    # Read the response
    response = helper.read_data()
    
    if response and len(response) > 0:
        print(f"Received response: {' '.join(f'0x{b:02X}' for b in response)}")
        
        # Check if it's a valid response (at least has start and end markers)
        if len(response) >= 4 and response[0] == 0xAA and response[-1] == 0x55:
            if response[1] == ord('O'):
                print("HIL communication successful - received OK response")
                success = True
            else:
                print(f"Received response with unexpected format")
                success = False
        else:
            print("Response doesn't have valid markers")
            success = False
    else:
        print("No response received from HIL")
        success = False
    
    # Close the port
    helper.close_serial_port()
    print(f"Closed port {port}")
    
    return success

def test_illuminator_connection(port="COM19", baudrate=115200, timeout=5.0):
    """Test connection to Illuminator using EnhancedSerialHelper"""
    
    # Create an instance of the helper
    helper = EnhancedSerialHelper()
    print(f"Created EnhancedSerialHelper instance")
    
    # Try to open the port
    success = helper.open_serial_port(port, baudrate, timeout, "illuminator")
    if not success:
        print(f"Failed to open port {port}")
        return False
    
    print(f"Successfully opened port {port} for Illuminator communication")
    
    # Create a simple ping command
    command = {
        "type": "cmd",
        "id": "ping-test",
        "topic": "system",
        "action": "ping",
        "data": {"timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ")}
    }
    
    try:
        print(f"Sending Illuminator ping command: {command}")
        response = helper.send_illuminator_command(command)
        
        if response and "data" in response and "status" in response["data"]:
            if response["data"]["status"] == "ok":
                print("Illuminator communication successful - received OK response")
                print(f"Full response: {response}")
                success = True
            else:
                print(f"Received error response: {response}")
                success = False
        else:
            print(f"Received unexpected response format: {response}")
            success = False
    except Exception as e:
        print(f"Error communicating with Illuminator: {e}")
        success = False
    
    # Close the port
    helper.close_serial_port()
    print(f"Closed port {port}")
    
    return success

def main():
    """Main function - run tests"""
    
    print("Testing EnhancedSerialHelper with HIL and Illuminator")
    print("-" * 60)
    
    # Get port names from command line arguments or use defaults
    hil_port = sys.argv[1] if len(sys.argv) > 1 else "COM20"
    illuminator_port = sys.argv[2] if len(sys.argv) > 2 else "COM19"
    
    print(f"Testing HIL connection on port {hil_port}")
    hil_success = test_hil_connection(hil_port)
    
    print("\n" + "-" * 60)
    
    print(f"Testing Illuminator connection on port {illuminator_port}")
    illuminator_success = test_illuminator_connection(illuminator_port)
    
    print("\n" + "-" * 60)
    print("Test Results:")
    print(f"HIL Communication: {'SUCCESS' if hil_success else 'FAILED'}")
    print(f"Illuminator Communication: {'SUCCESS' if illuminator_success else 'FAILED'}")

if __name__ == "__main__":
    main()