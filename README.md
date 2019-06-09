# Bno055

 Low-level Elixir driver used to interact with the Bosch Sensortec BNO055 absolute orientation sensor. 


### Example

```
# Connect to the i2c bus (default is "i2c-1")
{:ok, ref} = Bno055.connect()

# The Bno055 has two addresses available, 0x28 or 0x29.
# We will be using 0x28

# Power on and initialize the device.
Bno055.init(ref, 0x28)

# Check current calibration status
Bno055.calibrated?(ref, 0x28)

# Get Calibration readings on a scale of 0-3.
Bno055.get_calibration(ref, 0x28)

# Get angular velocity from the gyroscope
Bno055.get_angular_velocity(ref, 0x28)

# Get orientation from fusion mode
# - Euler
Bno055.get_euler(ref, 0x28)
# - Quaternion
Bno055.get_quaternion(ref, 0x28)
```

### Roadmap
[x] - Change power modes

[] - GenServer implementation? 

[] - Device Reset

[] - Save and load calibration profiles

[] - Enable external crystal

[] - Get Revision

[] - Remap axis




