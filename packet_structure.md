# Telemetry Data Structure

| Offset (Hex) | Variable Name | Size (Byte) | Format | Data Type | Description |
|--------------|---------------|-------------|--------|-----------|-------------|
| 0x04 | `position_x` | 4 | `f` | Float | World Position (X) |
| 0x08 | `position_y` | 4 | `f` | Float | World Position (Y) |
| 0x0C | `position_z` | 4 | `f` | Float | World Position (Z) |
| 0x10 | `velocity_x` | 4 | `f` | Float | Velocity (X-axis) |
| 0x1C | `rotation_pitch` | 4 | `f` | Float | Rotation: Pitch |
| 0x20 | `rotation_yaw` | 4 | `f` | Float | Rotation: Yaw (Heading) |
| 0x24 | `rotation_roll` | 4 | `f` | Float | Rotation: Roll |
| 0x2C | `angular_velocity_x` | 4 | `f` | Float | Angular Velocity (X-axis) |
| 0x38 | `ride_height` | 4 | `f` | Float | Ride Height (Clearance) |
| 0x3C | `rpm` | 4 | `f` | Float | Engine RPM |
| 0x44 | `current_fuel` | 4 | `f` | Float | Current Fuel Amount |
| 0x48 | `fuel_capacity` | 4 | `f` | Float | Fuel Tank Capacity |
| 0x4C | `car_speed` | 4 | `f` | Float | Vehicle Speed (m/s) |
| 0x50 | `boost` | 4 | `f` | Float | Boost / Turbo Pressure |
| 0x54 | `oil_pressure` | 4 | `f` | Float | Oil Pressure |
| 0x58 | `water_temp` | 4 | `f` | Float | Water Temperature |
| 0x5C | `oil_temp` | 4 | `f` | Float | Oil Temperature |
| 0x60 | `tyre_temp_FL` | 4 | `f` | Float | Tire Temperature (Front Left) |
| 0x64 | `tyre_temp_FR` | 4 | `f` | Float | Tire Temperature (Front Right) |
| 0x68 | `tyre_temp_RL` | 4 | `f` | Float | Tire Temperature (Rear Left) |
| 0x6C | `tyre_temp_RR` | 4 | `f` | Float | Tire Temperature (Rear Right) |
| 0x70 | `package_id` | 4 | `i` | Signed Int | Packet ID (Sequence Number) |
| 0x74 | `current_lap` | 2 | `h` | Signed Short | Current Lap Number |
| 0x76 | `total_laps` | 2 | `h` | Signed Short | Total Laps in Race |
| 0x78 | `best_lap_time` | 4 | `i` | Signed Int | Best Lap Time (ms) |
| 0x7C | `last_lap_time` | 4 | `i` | Signed Int | Last Lap Time (ms) |
| 0x80 | `time_on_track` | 4 | `i` | Signed Int | Total Time on Track (ms) |
| 0x84 | `current_position` | 2 | `h` | Signed Short | Current Race Position |
| 0x86 | `total_positions` | 2 | `h` | Signed Short | Total Number of Participants |
| 0x88 | `rpm_rev_warning` | 2 | `H` | Unsigned Short | RPM Rev Warning Threshold |
| 0x8A | `rpm_rev_limiter` | 2 | `H` | Unsigned Short | RPM Rev Limiter Value |
| 0x8C | `estimated_top_speed` | 2 | `h` | Signed Short | Estimated Top Speed (km/h) |
| 0x8E | `race_flags` | 1 | `B` | Unsigned Char | Status (IsPaused, InRace, etc.) |
| 0x90 | `gear_info` | 1 | `B` | Unsigned Char | Gear Info (Current/Suggested) |
| 0x91 | `throttle` | 1 | `B` | Unsigned Char | Throttle Input (0-255) |
| 0x92 | `brake` | 1 | `B` | Unsigned Char | Brake Input (0-255) |
| 0xA4 | `tyre_speed_FL` | 4 | `f` | Float | Tire Rotation Speed (Front Left) |
| 0xB4 | `tyre_diameter_FL` | 4 | `f` | Float | Tire Diameter (Front Left) |
| 0xC4 | `suspension_fl` | 4 | `f` | Float | Suspension Stroke (Front Left) |
| 0xF4 | `clutch` | 4 | `f` | Float | Clutch Pedal Position |
| 0x104 | `gear_ratio_1` | 4 | `f` | Float | 1st Gear Ratio |
| 0x124 | `car_id` | 4 | `i` | Signed Int | Unique Vehicle ID |