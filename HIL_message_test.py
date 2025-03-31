import argparse
import serial
import time
import sys

def generate_message(cmd, light, func, value):
    encoded_value = round(value)
    
    cmd = ord(cmd)     # Command character
    light = ord(light)   # Light identifier
    func = ord(func)    # Function type
    value_low = encoded_value & 0xFF    # LSB first
    value_high = (encoded_value >> 8) & 0xFF  # MSB second

    checksum = cmd ^ light ^ func ^ value_low ^ value_high

    message = [
        0xAA,   # Start marker
        cmd,    # Command
        light,  # Light identifier
        func,   # Function type
        value_low,   # LSB
        value_high,  # MSB
        checksum,    # Checksum
        0x55    # End marker
    ]
    
    return {
        "value": value,
        "encoded_value": encoded_value,
        "message": message
    }

def parse_response(response_bytes):
    # Check if we have a valid response (minimum 4 bytes for minimal response)
    if len(response_bytes) < 4:
        return {"status": "error", "message": "Response too short"}
    
    # Check start and end markers
    if response_bytes[0] != 0xAA or response_bytes[-1] != 0x55:
        return {"status": "error", "message": "Invalid response markers"}
    
    # Print the full response for debugging
    print(f"Debug - Full response: {' '.join(f'0x{x:02X}' for x in response_bytes)}")
    
    # Based on the example response format from the output
    # It appears the format is: 0xAA 0x4F 0x00 0x50 0x0F 0x00 0x10 0x55
    # This doesn't match our expected format, so let's try to interpret it differently
    
    # Check if this is an OK response (second byte is 'O' = 0x4F)
    if response_bytes[1] == ord('O'):
        # Success response
        return {"status": "ok", "message": "Command successful"}
    
    # Check if this is a NOT OK response (second byte is 'N' = 0x4E)
    elif response_bytes[1] == ord('N'):
        return {"status": "error", "message": "Command failed"}
    
    # Get command response with data - assuming 8-byte format
    elif len(response_bytes) == 8:
        # Based on the response example, it seems the format might be:
        # START + RESPONSE_TYPE + LIGHT_ID + FUNCTION + VALUE_LOW + VALUE_HIGH + CHECKSUM + END
        resp_type = chr(response_bytes[1])
        light_id = chr(response_bytes[2])
        func = chr(response_bytes[3])
        value_low = response_bytes[4]
        value_high = response_bytes[5]
        value = (value_high << 8) | value_low
        received_checksum = response_bytes[6]
        
        # Calculate checksum (XOR of all data bytes)
        calculated_checksum = response_bytes[1] ^ response_bytes[2] ^ response_bytes[3] ^ response_bytes[4] ^ response_bytes[5]
        
        print(f"Debug - Calculated checksum: 0x{calculated_checksum:02X}, Received: 0x{received_checksum:02X}")
        
        if calculated_checksum != received_checksum:
            return {"status": "error", "message": f"Checksum mismatch. Calculated: 0x{calculated_checksum:02X}, Received: 0x{received_checksum:02X}"}
        
        # Translate value based on function type
        if func == 'P':
            # PWM is 0-100%
            actual_value = value 
            unit = "%"
        elif func == 'C':
            # Current is 0-33A (10A per volt)
            actual_value = value / 10
            unit = "A"
        elif func == 'T':
            # Temperature is 0-330°C (100°C per volt)
            actual_value = value 
            unit = "°C"
        else:
            actual_value = value
            unit = "raw"
        
        return {
            "status": "ok", 
            "light": str(light_id) if isinstance(light_id, int) else light_id,
            "function": func,
            "raw_value": value,
            "actual_value": actual_value,
            "unit": unit
        }
    
    return {"status": "error", "message": f"Unknown response format: {' '.join(f'0x{x:02X}' for x in response_bytes)}"}

def send_command(port, cmd, light, func, value):
    message_data = generate_message(cmd, light, func, value)
    message_bytes = bytearray(message_data["message"])
    
    try:
        ser = serial.Serial(port, 115200, timeout=1)
        print(f"Connected to {port}")
        
        # Send the message
        print(f"Sending: {' '.join(f'0x{x:02X}' for x in message_bytes)}")
        ser.write(message_bytes)
        
        # Wait for response
        time.sleep(0.1)
        
        # Read response
        if ser.in_waiting:
            response = ser.read(ser.in_waiting)
            print(f"Received: {' '.join(f'0x{x:02X}' for x in response)}")
            
            # Parse the response
            parsed = parse_response(response)
            if parsed["status"] == "ok":
                if "actual_value" in parsed:
                    print(f"Response: Light {parsed['light']}, {parsed['function']} = {parsed['actual_value']:.2f} {parsed['unit']}")
                else:
                    print(f"Response: {parsed['message']}")
            else:
                print(f"Error: {parsed['message']}")
        else:
            print("No response received")
            
        ser.close()
        return True
        
    except serial.SerialException as e:
        print(f"Error: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Wiseled_LBR HIL Communication Tool")
    parser.add_argument("cmd", type=str, help="Command character ('G' for Get, 'S' for Set).")
    parser.add_argument("light", type=str, help="Light identifier ('1', '2', or '3').")
    parser.add_argument("func", type=str, help="Function ('P' for PWM, 'C' for Current, 'T' for Temperature).")
    parser.add_argument("value", type=int, help="Value to set (for Set commands) or 0 (for Get commands).")
    parser.add_argument("--port", "-p", type=str, help="COM port to connect to (e.g., COM3 or /dev/ttyUSB0).")
    args = parser.parse_args()
    
    # Validate arguments
    if args.cmd not in ['G', 'S']:
        print("Error: Command must be 'G' (Get) or 'S' (Set)")
        return
    
    if args.light not in ['1', '2', '3']:
        print("Error: Light must be '1', '2', or '3'")
        return
    
    if args.func not in ['P', 'C', 'T']:
        print("Error: Function must be 'P' (PWM), 'C' (Current), or 'T' (Temperature)")
        return
    
    # Display the message details
    result = generate_message(args.cmd, args.light, args.func, args.value)
    
    # Format the value based on function type
    if args.func == 'P':
        formatted_value = f"{args.value/0x7FFF*100:.2f}%"
    elif args.func == 'C':
        formatted_value = f"{args.value/0x7FFF*33:.2f}A"
    elif args.func == 'T':
        formatted_value = f"{args.value/0x7FFF*330:.2f}°C"
    else:
        formatted_value = str(args.value)
    
    print(f"Command: {args.cmd} (Light {args.light}, {args.func}, Value: {formatted_value})")
    print(f"Encoded value: {result['encoded_value']}")
    print("Message bytes:", ' '.join(f"0x{x:02X}" for x in result['message']))
    print("---")
    
    # If a port is specified, try to connect and send the command
    if args.port:
        max_retries = 3
        success = False
        
        for attempt in range(1, max_retries + 1):
            print(f"Attempt {attempt} of {max_retries}...")
            if send_command(args.port, args.cmd, args.light, args.func, args.value):
                success = True
                break
            
            if attempt < max_retries:
                print(f"Retrying in 2 seconds...")
                time.sleep(2)
        
        if not success:
            print(f"Failed to communicate after {max_retries} attempts")
    else:
        print("No COM port specified. Use --port or -p to specify a port.")

if __name__ == "__main__":
    main()