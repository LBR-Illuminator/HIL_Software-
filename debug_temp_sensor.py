# debug_temp_sensor.py
import time
from resources.ImprovedSerialHelper import ImprovedSerialHelper
from resources.ImprovedHILProtocol import ImprovedHILProtocol

helper = ImprovedSerialHelper()
hil = ImprovedHILProtocol()

helper.open_illuminator_connection("COM19", 115200)
helper.open_hil_connection("COM20", 115200)
hil.set_serial_helper(helper)

# Set light on
command = {
    "type": "cmd",
    "id": "test-light",
    "topic": "light",
    "action": "set",
    "data": {"id": 1, "intensity": 50}
}
helper.send_illuminator_command(command)

# Try different temperatures
for temp in [10, 30, 50, 100, 150]:
    print(f"\nTesting temperature: {temp}°C")
    # Set temperature
    hil.set_temperature_simulation(1, temp)
    time.sleep(1)
    
    # Get sensor reading
    command = {
        "type": "cmd",
        "id": f"get-sensor-{temp}",
        "topic": "status",
        "action": "get_sensors",
        "data": {"id": 1}
    }
    response = helper.send_illuminator_command(command)
    print(f"Response: {response}")