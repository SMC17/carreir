const std = @import("std");

/// Represents a Carrier .ml3 configuration file.
pub const CarrierConfig = struct {
    max_pressure_psi: f32,
    min_temp_c: f32,
    max_rpm: u32,
    low_refrigerant_threshold: f32,

    pub const default = CarrierConfig{
        .max_pressure_psi = 450.0,
        .min_temp_c = -40.0,
        .max_rpm = 4500,
        .low_refrigerant_threshold = 20.0,
    };
};

/// Represents a Carrier HVAC/Reefer system state
pub const PhysicalState = struct {
    ambient_temp_c: f32,
    target_temp_c: f32,
    compressor_rpm: u32,
    refrigerant_pressure_psi: f32,
    energy_input_watts: f32,
    
    // Cycle enthalpies (kJ/kg)
    h1_evap_exit: f32, 
    h2_comp_exit: f32,
    h3_cond_exit: f32,
    h4_evap_inlet: f32,
    
    entropy_s: f32,   // kJ/kg*K
    config: CarrierConfig,

    pub fn calculateCOP(self: *const PhysicalState) f32 {
        // Real thermodynamic Coefficient of Performance
        // COP = Cooling Effect / Work Input
        // Cooling Effect = h1 - h4 (Enthalpy absorbed in evaporator)
        // Work Input = h2 - h1 (Enthalpy added by compressor)
        const cooling_effect = self.h1_evap_exit - self.h4_evap_inlet;
        const work_input = self.h2_comp_exit - self.h1_evap_exit;
        
        if (work_input <= 0.0) return 0.0;
        return cooling_effect / work_input;
    }
};

pub const ControlAction = struct {
    compressor_speed: f32, // 0.0 to 1.0
    fan_speed: f32,        // 0.0 to 1.0
};

/// Real physical PID Controller instead of randomized hexagrams
pub const PidController = struct {
    kp: f32,
    ki: f32,
    kd: f32,
    
    integral: f32 = 0.0,
    prev_error: f32 = 0.0,

    pub fn init(kp: f32, ki: f32, kd: f32) PidController {
        return .{ .kp = kp, .ki = ki, .kd = kd };
    }

    pub fn step(self: *PidController, setpoint: f32, measured_value: f32, dt: f32) f32 {
        const err = setpoint - measured_value;
        self.integral += err * dt;
        const derivative = (err - self.prev_error) / dt;
        self.prev_error = err;
        
        var output = (self.kp * err) + (self.ki * self.integral) + (self.kd * derivative);
        
        // Clamp output to [0.0, 1.0]
        if (output > 1.0) output = 1.0;
        if (output < 0.0) output = 0.0;
        
        return output;
    }
};

/// Dimensional Analysis for Scientific Truth Verification.
pub const Dimension = enum {
    Energy,    // M^1 L^2 T^-2
    Frequency, // T^-1
    Dimensionless,
};

