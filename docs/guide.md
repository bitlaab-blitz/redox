# Developer Guide

If you are using previous release of Redox for some reason, you can generate documentation for that release by following these steps:

- Install [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/getting-started/) on your platform.

- Download and extract `Source code (zip)` for your target release at [**Redox Repo**](https://github.com/bitlaab-blitz/redox)

- Now, `cd` into your release directory and run:

```sh
mkdocs serve --dev-addr=0.0.0.0:3001
```

## Generate Code Documentation

To generate Zig's API documentation, navigate to your project directory and run:

```sh
zig build-lib -femit-docs=docs/zig-docs src/root.zig
```

Now, clean up any unwanted generated file and make sure to link `zig-docs/index.html` to your `reference.md` file.

## Build HiRedis from Source

To build the Hiredis static library (`libhiredis.a`), follow these steps:

```sh
git clone https://github.com/redis/hiredis.git
cd hiredis
make static
```

This produces the static library on the current directory.

**Remarks:** Make sure to build this for both `aarch64` and `x86_64` platforms.