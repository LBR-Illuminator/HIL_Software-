#!/usr/bin/env python3
"""
Error Analyzer for Wiseled_LBR

This script helps debug error responses from the Wiseled_LBR device by
checking various common issues that could prevent light operation.
"""

import sys
import time
import json
import argparse
from serial import Serial

def parse_args():
    parser = argparse.ArgumentParser(description='Test Wiseled_LBR communication')
    parser.add_argument('port', help='Serial port (e.g., COM19 or /dev/ttyUSB0)')
    parser.add_argument('--baud', type=int, default=115200, help='Baud rate (default: 115200)')
    parser.add_argument('--timeout', type=float, default=2.0, help='Read timeout in seconds (default: 2.0)')
    return parser.parse_args()

def send_command(ser, command_dict):
    """Send a command and get the response"""
    # Convert to JSON string
    command_str = json.dumps(command_dict)
    print(f"Sending: {command_str}")
    
    # Add newline and send
    command_str += "\n"
    ser.write(command_str.encode('utf-8'))
    
    # Read response
    response_str = ser.readline().decode('utf-8').strip()
    print(f"Received: {response_str}")
    
    # Parse JSON response
    try:
        return json.loads(response_str)
    except json.JSONDecodeError:
        print(f"Error parsing JSON: {response_str}")
        return {"error": "Invalid JSON"}

def check_ping(ser):
    """Check if the device is responding to ping commands"""
    print("\n=== Testing Basic Connectivity ===")
    command = {
        "type": "cmd",
        "id": "diag-ping-001",
        "topic": "system",
        "action": "ping",
        "data": {"timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ")}
    }
    
    response = send_command(ser, command)
    if response.get("type") == "resp" and response.get("data", {}).get("status") == "ok":
        print("✓ Ping test successful")
        return True
    else:
        print("✗ Ping test failed")
        return False

def check_system_info(ser):
    """Check basic system information"""
    print("\n=== Getting System Information ===")
    command = {
        "type": "cmd",
        "id": "diag-info-001",
        "topic": "system",
        "action": "info",
        "data": {}
    }
    
    response = send_command(ser, command)
    if response.get("type") == "resp" and response.get("data", {}).get("status") == "ok":
        print("✓ System info available")
        print(f"Device info: {json.dumps(response.get('data', {}), indent=2)}")
        return True
    else:
        print("✗ System info not available")
        return False

def check_alarm_status(ser):
    """Check if there are any active alarms"""
    print("\n=== Checking Alarm Status ===")
    command = {
        "type": "cmd",
        "id": "diag-alarm-001",
        "topic": "alarm",
        "action": "status",
        "data": {}
    }
    
    response = send_command(ser, command)
    if response.get("type") == "resp" and response.get("data", {}).get("status") == "ok":
        active_alarms = response.get("data", {}).get("active_alarms", [])
        if active_alarms:
            print(f"! Found {len(active_alarms)} active alarms:")
            for alarm in active_alarms:
                print(f"   - Light {alarm.get('light')}: {alarm.get('code')}")
            return False
        else:
            print("✓ No active alarms")
            return True
    else:
        print("✗ Failed to check alarm status")
        return False

def check_light_get(ser):
    """Test if we can read the current light states"""
    print("\n=== Checking Light Status ===")
    command = {
        "type": "cmd",
        "id": "diag-light-get-001",
        "topic": "light",
        "action": "get_all",
        "data": {}
    }
    
    response = send_command(ser, command)
    if response.get("type") == "resp" and response.get("data", {}).get("status") == "ok":
        intensities = response.get("data", {}).get("intensities", [])
        print(f"✓ Current light intensities: {intensities}")
        return True
    else:
        print("✗ Failed to get light status")
        return False

def attempt_light_set(ser):
    """Try to set each light individually and report results"""
    print("\n=== Testing Individual Light Control ===")
    success = True
    
    for light_id in range(1, 4):
        for intensity in [25, 50, 75]:
            command = {
                "type": "cmd",
                "id": f"diag-light-set-{light_id}-{intensity}",
                "topic": "light",
                "action": "set",
                "data": {"id": light_id, "intensity": intensity}
            }
            
            response = send_command(ser, command)
            status = response.get("data", {}).get("status")
            
            if status == "ok":
                print(f"✓ Successfully set light {light_id} to {intensity}%")
            else:
                success = False
                message = response.get("data", {}).get("message", "Unknown error")
                print(f"✗ Failed to set light {light_id} to {intensity}%: {message}")
                
            # Small delay between commands
            time.sleep(0.5)
    
    return success

def attempt_clear_alarms(ser):
    """Try to clear all possible alarms"""
    print("\n=== Attempting to Clear All Alarms ===")
    command = {
        "type": "cmd",
        "id": "diag-clear-all-001",
        "topic": "alarm",
        "action": "clear",
        "data": {"lights": [1, 2, 3]}
    }
    
    response = send_command(ser, command)
    status = response.get("data", {}).get("status")
    
    if status == "ok":
        print("✓ Successfully cleared alarms")
        return True
    else:
        message = response.get("data", {}).get("message", "Unknown error")
        print(f"✗ Failed to clear alarms: {message}")
        return False

def main():
    args = parse_args()
    print(f"Connecting to {args.port} at {args.baud} baud...")
    
    try:
        ser = Serial(
            port=args.port,
            baudrate=args.baud,
            timeout=args.timeout,
            bytesize=8,
            parity='N',
            stopbits=1
        )
        
        print(f"Connected successfully to {args.port}")
        
        # Run diagnostic tests
        ping_ok = check_ping(ser)
        if not ping_ok:
            print("\n! Basic connectivity issue detected. Check physical connections and power.")
            return
        
        system_ok = check_system_info(ser)
        alarm_ok = check_alarm_status(ser)
        get_ok = check_light_get(ser)
        
        if not alarm_ok:
            print("\n! Active alarms detected. Attempting to clear...")
            attempt_clear_alarms(ser)
            alarm_ok = check_alarm_status(ser)
        
        set_ok = attempt_light_set(ser)
        
        # Summary
        print("\n=== Diagnostic Summary ===")
        print(f"Basic connectivity: {'✓' if ping_ok else '✗'}")
        print(f"System information: {'✓' if system_ok else '✗'}")
        print(f"Alarm status: {'✓' if alarm_ok else '✗'}")
        print(f"Light status read: {'✓' if get_ok else '✗'}")
        print(f"Light control: {'✓' if set_ok else '✗'}")
        
        # Recommendations
        print("\n=== Troubleshooting Recommendations ===")
        if not set_ok:
            print("- Check if the lights are physically connected")
            print("- Verify that there are no active alarms preventing operation")
            print("- Check if the light drivers are receiving PWM signals")
            print("- Verify that the current and temperature sensors are properly connected")
            print("- Check the error log for any relevant issues")
        
    finally:
        # Clean up
        if ser and ser.is_open:
            ser.close()
            print(f"Closed connection to {args.port}")

if __name__ == "__main__":
    main()