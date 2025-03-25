#!/usr/bin/env python3
"""
Serial Port Check Utility for Wiseled_LBR HIL Testing

This script checks if a specified serial port is available and functional.
It can be used to diagnose issues with serial connections before running tests.

Usage:
    python check_serial_port.py [PORT_NAME]
    
Example:
    python check_serial_port.py COM19
"""

import sys
import time
import platform
import serial
import serial.tools.list_ports

def print_header(text):
    """Print a formatted header"""
    print("\n" + "=" * 60)
    print(f" {text}")
    print("=" * 60)

def list_available_ports():
    """List all available serial ports on the system"""
    print_header("Available Serial Ports")
    
    ports = list(serial.tools.list_ports.comports())
    
    if not ports:
        print(" No serial ports detected.")
        return []
    
    print(f" Found {len(ports)} serial port(s):")
    for i, port in enumerate(ports):
        print(f" {i+1}. {port.device}: {port.description}")
        if port.hwid:
            print(f"    Hardware ID: {port.hwid}")
    
    return [port.device for port in ports]

def check_port(port_name):
    """Test if the specified port can be opened"""
    print_header(f"Checking Port {port_name}")
    
    try:
        # Attempt to open the serial port
        ser = serial.Serial(port_name, 115200, timeout=1)
        
        print(f" SUCCESS: Port {port_name} opened successfully!")
        print(f" Port details:")
        print(f"   Name: {ser.name}")
        print(f"   Baudrate: {ser.baudrate}")
        print(f"   Timeout: {ser.timeout} second(s)")
        
        # Try to read from the port
        print("\n Attempting to read data (5 second timeout)...")
        start_time = time.time()
        received_data = b""
        
        # Read for up to 5 seconds or until we get data
        while (time.time() - start_time) < 5:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                received_data += data
                print(f"   Received: {data}")
            time.sleep(0.1)
        
        if received_data:
            print(f" Received {len(received_data)} bytes in 5 seconds.")
        else:
            print(" No data received in 5 seconds. This is normal if the device isn't sending data.")
        
        # Close the port
        ser.close()
        print(" Port closed successfully.")
        return True
    
    except serial.SerialException as e:
        print(f" ERROR: Could not open port {port_name}")
        print(f" {str(e)}")
        return False

def get_recommendations():
    """Provide system-specific recommendations"""
    print_header("Recommendations")
    
    system = platform.system()
    if system == "Windows":
        print(" - Check Device Manager > Ports (COM & LPT) for available ports")
        print(" - Make sure no other program is using the port")
        print(" - Check that the device is properly connected and powered")
        print(" - Try a different USB port")
        print(" - You may need to install or update device drivers")
    elif system == "Darwin":  # macOS
        print(" - Run 'ls /dev/tty.*' to see available ports")
        print(" - Make sure no other program is using the port")
        print(" - Check that the device is properly connected and powered")
        print(" - You may need to install drivers for USB-Serial adapters")
    else:  # Linux
        print(" - Run 'ls /dev/ttyUSB*' or 'ls /dev/ttyACM*' to see available ports")
        print(" - Make sure you have permissions: 'sudo usermod -a -G dialout $USER'")
        print(" - Check that the device is properly connected and powered")
        print(" - Try a different USB port")

def main():
    """Main function"""
    print("\nSerial Port Check Utility for Wiseled_LBR HIL Testing")
    print(f"Python {platform.python_version()} on {platform.system()}")
    
    available_ports = list_available_ports()
    
    if len(sys.argv) > 1:
        # Port specified on command line
        port_to_check = sys.argv[1]
        print(f"\nYou specified port: {port_to_check}")
        
        if port_to_check not in available_ports:
            print(f"WARNING: Port {port_to_check} was not detected in the available ports list.")
            choice = input("Do you want to try to open it anyway? (y/n): ")
            if choice.lower() != 'y':
                print("Exiting.")
                return
        
        check_port(port_to_check)
    
    else:
        # No port specified, offer to check first available port
        if available_ports:
            choice = input(f"\nWould you like to check the first available port ({available_ports[0]})? (y/n): ")
            if choice.lower() == 'y':
                check_port(available_ports[0])
            else:
                print("Please run again with a specific port: python check_serial_port.py PORT_NAME")
        else:
            print("\nNo ports available to check.")
    
    get_recommendations()
    print("\nDone.")

if __name__ == "__main__":
    main()