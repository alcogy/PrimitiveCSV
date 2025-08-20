# PrimitiveCSV
PrimitiveCSV is a primitive csv library for zig.


## How to use.
### read file
```
const csv = @import("primitive_csv");
pub fn main() !void {
    var allocator = std.testing.allocator;
    const table = try read(&allocator, "sample.csv");
    defer {
        for (table) |row| {
            for (row) |cell| {
                allocator.free(cell);
            }
            allocator.free(row);
        }
        allocator.free(table);
    }

    // some code...
    // table[0][1];
}

```
### write file
```
const csv = @import("primitive_csv");
pub fn main() !void {
    const data: [][][]const u8 = getting_csv_data();
    try write("test.csv", data);
}
```