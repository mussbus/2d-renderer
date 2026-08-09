const coordinate = @import("coordinate.zig");
const definition = @import("definition.zig");
const diagnostics = @import("diagnostics.zig");
const validation = @import("validation.zig");

pub const NormalizedDefinition = struct {
    source: *const definition.CanonicalCreatureDefinition,
    coordinate_contract: coordinate.CoordinateContract,
};

pub const Result = struct {
    normalized: ?NormalizedDefinition,
    report: diagnostics.ValidationReport,

    pub fn isValid(self: Result) bool {
        return self.normalized != null and self.report.isValid();
    }
};

pub fn normalize(
    source: *const definition.CanonicalCreatureDefinition,
    context: validation.ValidationContext,
    diagnostic_storage: []diagnostics.Diagnostic,
) validation.ValidationError!Result {
    const report = try validation.validate(source, context, diagnostic_storage);
    return .{
        .normalized = if (report.isValid()) .{
            .source = source,
            .coordinate_contract = source.coordinate_contract orelse coordinate.canonical,
        } else null,
        .report = report,
    };
}
