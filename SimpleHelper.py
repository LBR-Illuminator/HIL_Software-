class SimpleHelper:
    """A very simple Robot Framework library for testing"""
    
    ROBOT_LIBRARY_SCOPE = 'GLOBAL'
    
    def __init__(self):
        print("SimpleHelper initialized!")
        
    def say_hello(self, name):
        """Say hello to someone"""
        message = f"Hello, {name}!"
        print(message)
        return message
        
    def add_numbers(self, a, b):
        """Add two numbers"""
        result = int(a) + int(b)
        print(f"{a} + {b} = {result}")
        return result