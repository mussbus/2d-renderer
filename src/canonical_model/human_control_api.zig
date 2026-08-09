const implementation = @import("human_controls.zig");

pub const Area = implementation.Area;
pub const TargetKind = implementation.TargetKind;
pub const TraceEntry = implementation.TraceEntry;
pub const TraceError = implementation.TraceError;
pub const traceCount = implementation.traceCount;
pub const generateTraces = implementation.generateTraces;
pub const findControl = implementation.findControl;
pub const controlIsActive = implementation.controlIsActive;
pub const activeControlCount = implementation.activeControlCount;
pub const areaForControl = implementation.areaForControl;
