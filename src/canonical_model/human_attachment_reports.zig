const implementation = @import("human_attachments.zig");

pub const report_tolerance_m = implementation.report_tolerance_m;
pub const AnchorReportEntry = implementation.AnchorReportEntry;
pub const SocketReportEntry = implementation.SocketReportEntry;
pub const MountReportEntry = implementation.MountReportEntry;
pub const ReportError = implementation.ReportError;
pub const generateAnchorReport = implementation.generateAnchorReport;
pub const generateSocketReport = implementation.generateSocketReport;
pub const generateMountReport = implementation.generateMountReport;
pub const anchorWorldPosition = implementation.anchorWorldPosition;
pub const boneWorldTransform = implementation.boneWorldTransform;
