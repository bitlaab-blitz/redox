# How to use

First, import Redox on your Zig source file.

```zig
const redox = @import("redox");
```

Now, import common redox modules to use through out the examples.

```zig
const Dt = quill.Types;
const Uuid = quill.Uuid;
const Quill = quill.Quill;
const Qb = quill.QueryBuilder;
```

Initialize the General Propose Allocator (GPA) within the `main` function.

```zig
var gpa_mem = std.heap.DebugAllocator(.{}).init;
defer std.debug.assert(gpa_mem.deinit() == .ok);
const heap = gpa_mem.allocator();
```

## Initial Setup

Let's Initialize an on disk database with global configuration.

```zig
try Quill.init(.Serialized);
defer Quill.deinit();

var db = try Quill.open(heap, "hello.db");
defer db.close();
```

