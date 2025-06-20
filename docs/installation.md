# How to Install

Navigate to your project directory. e.g., `cd my_awesome_project`

### Install the Nightly Version

Fetch **redox** as external package dependency by running:

```sh
zig fetch --save \
https://github.com/bitlaab-blitz/redox/archive/refs/heads/main.zip
```

### Install the Release Version

Fetch **redox** as external package dependency by running:

```sh
zig fetch --save \
https://github.com/bitlaab-blitz/redox/archive/refs/tags/v0.0.0.zip
```

Make sure to edit `v0.0.0` with the latest release version.

## Import Module

Now, import **redox** as external package module to your project by coping following code:

```zig title="build.zig"
const redox = b.dependency("redox", .{});
exe.root_module.addImport("redox", redox.module("redox"));
lib.root_module.addImport("redox", redox.module("redox"));
```

**Remarks:** You may need to link **libc** with your project executable - (e.g., `exe.linkLibC()`) if it hasn't been linked already.
