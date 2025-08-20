const std = @import("std");
const p = std.debug.print;

// pub fn main() !void {
//     if (std.os.argv.len < 2) {
//         p("You need a file path\n", .{});
//         return;
//     }
//     const file_path: []u8 = std.mem.span(std.os.argv[1]);

//     const file = try std.fs.cwd().openFile(file_path, .{});
//     defer file.close();

//     const size = try file.getEndPos();

//     var allocator = std.heap.page_allocator;
//     const buffer = try allocator.alloc(u8, size);
//     defer allocator.free(buffer);

//     _ = try file.readAll(buffer);

//     const table = try read_csv(&allocator, buffer);
//     defer {
//         for (table) |row| {
//             for (row) |cell| {
//                 allocator.free(cell);
//             }
//             allocator.free(row);
//         }
//         allocator.free(table);
//     }

//     for (table) |row| {
//         for (row) |cell| {
//             p("{s}, ", .{cell});
//         }
//         p("\n", .{});
//     }
// }

pub fn read(path: []const u8) ![][][]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const size = try file.getEndPos();

    var allocator = std.heap.page_allocator;
    const buffer = try allocator.alloc(u8, size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    const table = try read_csv(&allocator, buffer);
    defer {
        for (table) |row| {
            for (row) |cell| {
                allocator.free(cell);
            }
            allocator.free(row);
        }
        allocator.free(table);
    }
    return table;
}

pub fn write(filename: []const u8, data: [][][]const u8) !void {
    var allocator = std.heap.page_allocator;

    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    var rows = std.ArrayList([]const u8).init(allocator);
    defer {
        for (rows.items) |row| {
            allocator.free(row);
        }
        rows.deinit();
    }

    for (data) |row| {
        var new_cells = std.ArrayList([]const u8).init(allocator);
        defer {
            for (new_cells.items) |cell| {
                allocator.free(cell);
            }
            new_cells.deinit();
        }

        for (row) |cell| {
            const replaced = try replace(&allocator, cell, "\"", "\"\"");
            defer allocator.free(replaced);

            const item = try std.fmt.allocPrint(allocator, "\"{s}\"", .{replaced});
            try new_cells.append(item);
        }

        const line = try std.mem.join(allocator, ",", new_cells.items);
        try rows.append(line);
    }

    const result = try std.mem.join(allocator, "\n", rows.items);
    defer allocator.free(result);

    try file.writeAll(result);
}

fn read_csv(allocator: *std.mem.Allocator, str: []const u8) ![][][]const u8 {
    const out1 = try replace(allocator, str, "\r", "");
    defer allocator.free(out1);

    const out2 = try replace(allocator, out1, "\"\"", "\r");
    defer allocator.free(out2);

    var in_str = false;
    var has_quat = false;

    var chars = std.ArrayList(u8).init(allocator.*);
    var row = std.ArrayList([]u8).init(allocator.*);
    var table = std.ArrayList([][]u8).init(allocator.*);

    for (out2) |c| {
        if (!in_str and c != ',') {
            if (c == '"' and !in_str) {
                has_quat = true;
            } else if (c != '"' and !in_str) {
                has_quat = false;
                try chars.append(c);
            }
            in_str = true;
            continue;
        }

        if (c == '"' and in_str) {
            in_str = false;
            continue;
        }

        if (c == ',' and (!has_quat or (has_quat and !in_str))) {
            try row.append(try chars.toOwnedSlice());
            in_str = false;
            continue;
        }

        if (c == '\n' and (!has_quat or (has_quat and !in_str))) {
            try row.append(try chars.toOwnedSlice());
            try table.append(try row.toOwnedSlice());
            in_str = false;
            continue;
        }

        if (c == '\r') {
            try chars.append('\"');
            continue;
        }
        try chars.append(c);
    }

    if (chars.items.len > 0) {
        try row.append(try chars.toOwnedSlice());
        try table.append(try row.toOwnedSlice());
    }

    return try table.toOwnedSlice();
}

fn replace(allocator: *std.mem.Allocator, str: []const u8, before: []const u8, after: []const u8) ![]u8 {
    const replace_size = std.mem.replacementSize(u8, str, before, after);
    const buffer = try allocator.alloc(u8, replace_size);

    _ = std.mem.replace(u8, str, before, after, buffer);

    return buffer;
}

test "replace" {
    const base: []const u8 = "My name is John.\nHello World!";

    var allocator = std.testing.allocator;
    const str = try replace(&allocator, base, "Hello ", "");
    defer allocator.free(str);
    try std.testing.expect(std.mem.eql(u8, str, "My name is John.\nWorld!"));
}

test "read_csv" {
    var allocator = std.testing.allocator;
    const str = "header1,header2\n\"body1\",\"bo\"\"dy\n2\"";
    const table = try read_csv(&allocator, str);
    defer {
        for (table) |row| {
            for (row) |cell| {
                allocator.free(cell);
            }
            allocator.free(row);
        }
        allocator.free(table);
    }

    try std.testing.expect(std.mem.eql(u8, table[0][0], "header1"));
    try std.testing.expect(std.mem.eql(u8, table[0][1], "header2"));
    try std.testing.expect(std.mem.eql(u8, table[1][0], "body1"));
    try std.testing.expect(std.mem.eql(u8, table[1][1], "bo\"dy\n2"));
}

test "write_csv" {
    var allocator = std.testing.allocator;
    const str = "header1,header2\n\"body1\",\"bo\"\"dy\n2\"";
    const table = try read_csv(&allocator, str);
    defer {
        for (table) |row| {
            for (row) |cell| {
                allocator.free(cell);
            }
            allocator.free(row);
        }
        allocator.free(table);
    }

    try write("test.csv", table);
}
