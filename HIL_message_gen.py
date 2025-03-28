import argparse

def generate_current_simulation_message(cmd, light, func, value):
    encoded_value = round(value)
    
    cmd = ord(cmd)     # Set command
    light = ord(light)   # Light identifier
    func = ord(func)    # Function type
    value_low = encoded_value & 0xFF    # LSB first
    value_high = (encoded_value >> 8) & 0xFF  # MSB second

    checksum = cmd ^ light ^ func ^ value_low ^ value_high

    message = [
        0xAA,   # Start marker
        cmd,    # Set command
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

def main():
    parser = argparse.ArgumentParser(description="Generate a current simulation message.")
    parser.add_argument("cmd", type=str, help="Command character (e.g., 'S').")
    parser.add_argument("light", type=str, help="Light identifier character (e.g., '1').")
    parser.add_argument("func", type=str, help="Function character (e.g., 'C').")
    parser.add_argument("value", type=int, help="Current value to encode.")
    args = parser.parse_args()
    
    result = generate_current_simulation_message(args.cmd, args.light, args.func, args.value)
    print(f"Value: {args.value/10} A")
    print(f"Encoded: {result['encoded_value']}")
    print("Message:", ' '.join(f"0x{x:02X}" for x in result['message']))
    print("---")

if __name__ == "__main__":
    main()
