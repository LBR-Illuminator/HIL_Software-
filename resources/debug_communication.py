#!/usr/bin/env python3
"""
Debug Communication Tool for Wiseled_LBR Testing

This script provides a simple way to test and debug communication with both
the Illuminator device and the HIL hardware.
"""

import os
import sys
import time
import json
import serial
import argparse

# Add the resources directory to the path so we can import the helpers
script_dir = os.path.dirname(os.path.abspath(__file__))
resources_dir = os.path.join(script_dir, 'resources')
sys.path.append(resources_dir)

# Import the improved helpers
try:
    from ImprovedSerialHelper import ImprovedSerialHelper
    from ImprovedHILProtocol import ImprovedHILProtocol
    print("Successfully imported ImprovedSerialHelper and ImprovedHILProtocol")
except ImportError as e:
    print(f"Error importing helpers: {e}")
    sys.exit(1)

def print_header(title):
    """Print a formatted header"""
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)

def test_illuminator(serial_helper, port, baudrate=115200, timeout=5.0):
    """Test communication with the Illuminator device"""
    print_header("Testing Illuminator Communication")
    
    # Try to open the connection
    success = serial_helper.open_illuminator_connection(port, baudrate, timeout)
    if not success:
        print(f"Failed to open connection to Illuminator on port {port}")
        return False
    
    print(f"Successfully connected to Illuminator on port {port}")
    
    # Try a ping command
    print("\nSending ping command...")
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ")
    command = {
        "type": "cmd",
        "id": "debug-ping-001",
        "topic": "system",
        "action": "ping",
        "data": {"timestamp": timestamp}
    }
    
    try:
        response = serial_helper.send_illuminator_command(command)
        print(f"Response received: {json.dumps(response, indent=2)}")
        
        # Check if response has data and status
        if response and "data" in response and "status" in response["data"]:
            if response["data"]["status"] == "ok":
                print("Ping successful!")
                return True
        
        print("Ping failed - unexpected response format")
        return False
    except Exception as e:
        print(f"Error during ping: {e}")
        return False
    finally:
        # We'll keep the connection open for now
        pass

def test_hil(serial_helper, hil_protocol, port, baudrate=115200, timeout=5.0):
    """Test communication with the HIL hardware"""
    print_header("Testing HIL Communication")
    
    # Try to open the connection
    success = serial_helper.open_hil_connection(port, baudrate, timeout)
    if not success:
        print(f"Failed to open connection to HIL on port {port}")
        return False
    
    print(f"Successfully connected to HIL on port {port}")
    
    # Set HIL protocol's serial helper
    hil_protocol.set_serial_helper(serial_helper)
    
    # Try a ping command
    print("\nSending ping command...")
    try:
        response = hil_protocol.ping()
        print(f"Response received: {response}")
        
        if response and response.get("status") == "ok":
            if 'firmware_version' in response:
                print(f"Ping successful! HIL Firmware version: {response['firmware_version']}")
            else:
                print("Ping successful!")
            return True
        
        print("Ping failed - unexpected response format")
        return False
    except Exception as e:
        print(f"Error during ping: {e}")
        return False
    finally:
        # We'll keep the connection open for now
        pass

def test_light_control(serial_helper, hil_protocol):
    """Test light control and PWM feedback"""
    print_header("Testing Light Control and PWM Feedback")
    
    # Check if both devices are connected
    if not serial_helper.is_illuminator_connected():
        print("Illuminator not connected - skipping test")
        return False
    
    if not serial_helper.is_hil_connected():
        print("HIL not connected - skipping test")
        return False
    
    print("Both devices connected - proceeding with test")
    
    # First turn off all lights
    print("\nTurning off all lights...")
    command = {
        "type": "cmd",
        "id": "debug-all-off",
        "topic": "light",
        "action": "set_all",
        "data": {"intensities": [0, 0, 0]}
    }
    
    response = serial_helper.send_illuminator_command(command)
    print(f"Response: {json.dumps(response, indent=2)}")
    
    # Wait for system to stabilize
    time.sleep(1)
    
    # Test each light individually
    for light_id in range(1, 4):
        print(f"\nTesting Light {light_id}...")
        test_intensities = [0, 25, 50, 75, 100]
        
        for intensity in test_intensities:
            # Set light intensity
            command = {
                "type": "cmd",
                "id": f"debug-set-{light_id}",
                "topic": "light",
                "action": "set",
                "data": {"id": light_id, "intensity": intensity}
            }
            
            print(f"Setting Light {light_id} to {intensity}%...")
            response = serial_helper.send_illuminator_command(command)
            
            if response and "data" in response and "status" in response["data"]:
                if response["data"]["status"] == "ok":
                    print(f"Set command successful")
                else:
                    print(f"Set command failed: {response}")
                    continue
            else:
                print(f"Invalid response: {response}")
                continue
            
            # Allow system to stabilize
            time.sleep(0.5)
            
            # Read PWM duty cycle
            try:
                duty_cycle = hil_protocol.get_pwm_duty_cycle(light_id)
                print(f"Measured PWM duty cycle: {duty_cycle}%")
                
                # Verify duty cycle is close to what we expect
                if intensity == 0 and duty_cycle < 5:
                    print("✓ Light is OFF as expected")
                elif intensity == 100 and duty_cycle > 95:
                    print("✓ Light is FULL ON as expected")
                elif abs(duty_cycle - intensity) <= 5:
                    print(f"✓ Duty cycle ({duty_cycle}%) is close to expected ({intensity}%)")
                else:
                    print(f"✗ Duty cycle ({duty_cycle}%) differs from expected ({intensity}%)")
            except Exception as e:
                print(f"Error reading PWM: {e}")
        
        # Turn off the light before testing the next one
        command = {
            "type": "cmd",
            "id": f"debug-off-{light_id}",
            "topic": "light",
            "action": "set",
            "data": {"id": light_id, "intensity": 0}
        }
        
        serial_helper.send_illuminator_command(command)
        time.sleep(0.5)
    
    return True

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Debug communication with Wiseled_LBR')
    parser.add_argument('--illuminator', type=str, default='COM19', help='Illuminator serial port')
    parser.add_argument('--hil', type=str, default='COM20', help='HIL serial port')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate')
    parser.add_argument('--timeout', type=float, default=5.0, help='Read timeout in seconds')
    parser.add_argument('--test-light', action='store_true', help='Test light control and PWM feedback')
    args = parser.parse_args()
    
    # Create helper instances
    serial_helper = ImprovedSerialHelper()
    hil_protocol = ImprovedHILProtocol()
    
    try:
        # Test Illuminator communication
        illuminator_ok = test_illuminator(serial_helper, args.illuminator, args.baudrate, args.timeout)
        
        # Test HIL communication
        hil_ok = test_hil(serial_helper, hil_protocol, args.hil, args.baudrate, args.timeout)
        
        # Test light control if requested
        if args.test_light and illuminator_ok and hil_ok:
            test_light_control(serial_helper, hil_protocol)
        
        # Summary
        print_header("Test Summary")
        print(f"Illuminator Communication: {'✓ OK' if illuminator_ok else '✗ FAILED'}")
        print(f"HIL Communication: {'✓ OK' if hil_ok else '✗ FAILED'}")
        
        if not illuminator_ok or not hil_ok:
            print("\nTroubleshooting Tips:")
            if not illuminator_ok:
                print("- Check if Illuminator is powered on")
                print(f"- Verify port {args.illuminator} is correct")
                print("- Check if another application is using the port")
                print("- Try resetting the Illuminator")
            
            if not hil_ok:
                print("- Check if HIL board is powered on")
                print(f"- Verify port {args.hil} is correct")
                print("- Check if another application is using the port")
                print("- Try resetting the HIL board")
    finally:
        # Clean up
        serial_helper.close_all_connections()
        print("\nConnections closed.")

if __name__ == "__main__":
    main()