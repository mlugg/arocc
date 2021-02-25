const NodeIndex = @import("Tree.zig").NodeIndex;
const Parser = @import("Parser.zig");

const Type = @This();

pub const Qualifiers = packed struct {
    @"const": bool = false,
    atomic: bool = false,
    @"volatile": bool = false,
    restrict: bool = false,
};

pub const Func = struct {
    return_type: Type,
    param_types: []Type,
};

pub const Array = struct {
    len: u64,
    elem: Type,
};

pub const Specifier = enum {
    void,
    bool,

    // integers
    char,
    schar,
    uchar,
    short,
    ushort,
    int,
    uint,
    long,
    ulong,
    long_long,
    ulong_long,

    // floating point numbers
    float,
    double,
    long_double,
    complex_float,
    complex_double,
    complex_long_double,

    // data.sub_type
    pointer,
    atomic,
    // data.func
    func,

    // data.array
    array,
    static_array,
    // data.node
    @"struct",
    @"union",
    @"enum",
};

data: union {
    sub_type: *Type,
    func: *Func,
    array: *Array,
    node: NodeIndex,
    none: void,
} = .{ .none = {} },
alignment: u32 = 0,
specifier: Specifier,
qual: Qualifiers = .{},

/// An unfinished Type
pub const Builder = union(enum) {
    none,
    void,
    bool,
    char,
    schar,
    uchar,

    unsigned,
    signed,
    short,
    sshort,
    ushort,
    short_int,
    sshort_int,
    ushort_int,
    int,
    sint,
    uint,
    long,
    slong,
    ulong,
    long_int,
    slong_int,
    ulong_int,
    long_long,
    slong_long,
    ulong_long,
    long_long_int,
    slong_long_int,
    ulong_long_int,

    float,
    double,
    long_double,
    complex,
    complex_long,
    complex_float,
    complex_double,
    complex_long_double,

    pointer: *Type,
    atomic: *Type,
    func: *Func,
    array: *Array,
    static_array: *Array,
    @"struct": NodeIndex,
    @"union": NodeIndex,
    @"enum": NodeIndex,

    pub fn str(spec: Builder) []const u8 {
        return switch (spec) {
            .none => unreachable,
            .void => "void",
            .bool => "_Bool",
            .char => "char",
            .schar => "signed char",
            .uchar => "unsigned char",
            .unsigned => "unsigned",
            .signed => "signed",
            .short => "short",
            .ushort => "unsigned short",
            .sshort => "signed short",
            .short_int => "short int",
            .sshort_int => "signed short int",
            .ushort_int => "unsigned short int",
            .int => "int",
            .sint => "signed int",
            .uint => "unsigned int",
            .long => "long",
            .slong => "signed long",
            .ulong => "unsigned long",
            .long_int => "long int",
            .slong_int => "signed long int",
            .ulong_int => "unsigned long int",
            .long_long => "long long",
            .slong_long => "signed long long",
            .ulong_long => "unsigned long long",
            .long_long_int => "long long int",
            .slong_long_int => "signed long long int",
            .ulong_long_int => "unsigned long long int",

            .float => "float",
            .double => "double",
            .long_double => "long double",
            .complex => "_Complex",
            .complex_long => "_Complex long",
            .complex_float => "_Complex float",
            .complex_double => "_Complex double",
            .complex_long_double => "_Complex long double",

            // TODO make these more specific?
            .pointer => "pointer",
            .atomic => "atomic",
            .func => "function",
            .array, .static_array => "array",
            .@"struct" => "struct",
            .@"union" => "union",
            .@"enum" => "enum",
        };
    }

    pub fn finish(spec: Builder, p: *Parser, ty: *Type) Parser.Error!void {
        ty.specifier = switch (spec) {
            .none => {
                ty.specifier = .int;
                return p.err(.missing_type_specifier);
            },
            .void => .void,
            .bool => .bool,
            .char => .char,
            .schar => .schar,
            .uchar => .uchar,

            .unsigned => .uint,
            .signed => .int,
            .short_int, .sshort_int, .short, .sshort => .short,
            .ushort, .ushort_int => .ushort,
            .int, .sint => .int,
            .uint => .uint,
            .long, .slong, .long_int, .slong_int => .long,
            .ulong, .ulong_int => .ulong,
            .long_long, .slong_long, .long_long_int, .slong_long_int => .long_long,
            .ulong_long, .ulong_long_int => .ulong_long,

            .float => .float,
            .double => .double,
            .long_double => .long_double,
            .complex_float => .complex_float,
            .complex_double => .complex_double,
            .complex_long_double => .complex_long_double,
            .complex, .complex_long => {
                const tok = p.tokens[p.tok_i];
                try p.pp.comp.diag.add(.{
                    .tag = .type_is_invalid,
                    .source_id = tok.source,
                    .loc_start = tok.loc.start,
                    .extra = .{ .str = spec.str() },
                });
                return error.ParsingFailed;
            },

            .atomic => return p.todo("atomic types"),
            .pointer => |data| {
                ty.specifier = .pointer;
                ty.data = .{ .pointer = data };
                return;
            },
            .func => |data| {
                ty.specifier = .func;
                ty.data = .{ .func = data };
                return;
            },
            .array => |data| {
                ty.specifier = .array;
                ty.data = .{ .array = data };
                return;
            },
            .static_array => |data| {
                ty.specifier = .static_array;
                ty.data = .{ .array = data };
                return;
            },
            .@"struct" => |data| {
                ty.specifier = .@"struct";
                ty.data = .{ .node = data };
                return;
            },
            .@"union" => |data| {
                ty.specifier = .@"union";
                ty.data = .{ .node = data };
                return;
            },
            .@"enum" => |data| {
                ty.specifier = .@"enum";
                ty.data = .{ .node = data };
                return;
            },
        };
    }

    pub fn cannotCombine(spec: *Builder, p: *Parser) Parser.Error {
        const tok = p.tokens[p.tok_i];
        try p.pp.comp.diag.add(.{
            .tag = .cannot_combine_spec,
            .source_id = tok.source,
            .loc_start = tok.loc.start,
            .extra = .{ .str = spec.str() },
        });
        return error.ParsingFailed;
    }

    pub fn combine(spec: *Builder, p: *Parser, new: Builder) Parser.Error!void {
        spec.* = switch (new) {
            .void, .bool, .@"enum", .@"struct", .@"union", .pointer, .array, .static_array, .func => switch (spec.*) {
                .none => new,
                else => return spec.cannotCombine(p),
            },
            .atomic => return p.todo("atomic types"),
            .signed => switch (spec.*) {
                .none => .signed,
                .char => .schar,
                .short => .sshort,
                .short_int => .sshort_int,
                .int => .sint,
                .long => .slong,
                .long_int => .slong_int,
                .long_long => .slong_long,
                .long_long_int => .slong_long_int,
                .sshort,
                .sshort_int,
                .sint,
                .slong,
                .slong_int,
                .slong_long,
                .slong_long_int,
                => return p.duplicateSpecifier("signed"),
                else => return spec.cannotCombine(p),
            },
            .unsigned => switch (spec.*) {
                .none => .unsigned,
                .char => .uchar,
                .short => .ushort,
                .short_int => .ushort_int,
                .int => .uint,
                .long => .ulong,
                .long_int => .ulong_int,
                .long_long => .ulong_long,
                .long_long_int => .ulong_long_int,
                .ushort,
                .ushort_int,
                .uint,
                .ulong,
                .ulong_int,
                .ulong_long,
                .ulong_long_int,
                => return p.duplicateSpecifier("unsigned"),
                else => return spec.cannotCombine(p),
            },
            .char => switch (spec.*) {
                .none => .char,
                .unsigned => .uchar,
                .signed => .schar,
                .char, .schar, .uchar => return p.duplicateSpecifier("float"),
                else => return spec.cannotCombine(p),
            },
            .short => switch (spec.*) {
                .none => .short,
                .unsigned => .ushort,
                .signed => .sshort,
                else => return spec.cannotCombine(p),
            },
            .int => switch (spec.*) {
                .none => .int,
                .signed => .sint,
                .unsigned => .uint,
                .short => .short_int,
                .sshort => .sshort_int,
                .ushort => .ushort_int,
                .long => .long_int,
                .slong => .slong_int,
                .ulong => .ulong_int,
                .long_long => .long_long_int,
                .slong_long => .slong_long_int,
                .ulong_long => .ulong_long_int,
                .int,
                .sint,
                .uint,
                .short_int,
                .sshort_int,
                .ushort_int,
                .long_int,
                .slong_int,
                .ulong_int,
                .long_long_int,
                .slong_long_int,
                .ulong_long_int,
                => return p.duplicateSpecifier("int"),
                else => return spec.cannotCombine(p),
            },
            .long => switch (spec.*) {
                .none => .long,
                .long => .long_long,
                .unsigned => .ulong,
                .signed => .long,
                .int => .long_int,
                .sint => .slong_int,
                .ulong => .ulong_long,
                .long_long, .ulong_long => return p.duplicateSpecifier("long"),
                else => return spec.cannotCombine(p),
            },
            .float => switch (spec.*) {
                .none => .float,
                .complex => .complex_float,
                .complex_float, .float => return p.duplicateSpecifier("float"),
                else => return spec.cannotCombine(p),
            },
            .double => switch (spec.*) {
                .none => .double,
                .long => .long_double,
                .complex_long => .complex_long_double,
                .complex => .complex_double,
                .long_double,
                .complex_long_double,
                .complex_double,
                .double,
                => return p.duplicateSpecifier("double"),
                else => return spec.cannotCombine(p),
            },
            .complex => switch (spec.*) {
                .none => .complex,
                .long => .complex_long,
                .float => .complex_float,
                .double => .complex_double,
                .long_double => .complex_long_double,
                .complex,
                .complex_long,
                .complex_float,
                .complex_double,
                .complex_long_double,
                => return p.duplicateSpecifier("_Complex"),
                else => return spec.cannotCombine(p),
            },
            else => unreachable,
        };
    }

    pub fn fromType(ty: Type) Builder {
        return switch (ty.specifier) {
            .void => .void,
            .bool => .bool,
            .char => .char,
            .schar => .schar,
            .uchar => .uchar,
            .short => .short,
            .ushort => .ushort,
            .int => .int,
            .uint => .uint,
            .long => .long,
            .ulong => .ulong,
            .long_long => .long_long,
            .ulong_long => .ulong_long,
            .float => .float,
            .double => .double,
            .long_double => .long_double,
            .complex_float => .complex_float,
            .complex_double => .complex_double,
            .complex_long_double => .complex_long_double,

            .pointer => .{ .pointer = ty.data.sub_type },
            .atomic => .{ .atomic = ty.data.sub_type },
            .func => .{ .func = ty.data.func },
            .array => .{ .array = ty.data.array },
            .static_array => .{ .static_array = ty.data.array },
            .@"struct" => .{ .@"struct" = ty.data.node },
            .@"union" => .{ .@"union" = ty.data.node },
            .@"enum" => .{ .@"enum" = ty.data.node },
        };
    }
};
