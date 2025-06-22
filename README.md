# redox

**High-level HiRedis Wrapper**

Redox is a lightweight wrapper over the C-based [hiredis](https://github.com/redis/hiredis) library, implemented in Zig for projects that require direct Redis access with minimal overhead and thread safety.

## Platform Support

Redox currently supports only Linux on **aarch64** and **x86_64** architectures.

## Dependency

Redox uses `libhiredis.a` (Static Library) along with the necessary header files.

No additional step is required to use this project as a package dependency.

## Documentation

For most up-to-date documentation see - [**Redox Documentation**](https://bitlaabredox.web.app/).