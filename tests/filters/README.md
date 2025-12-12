# Lua Filter Tests

This directory contains unit tests for Lua filters used in AWS for Fluent Bit.

## Prerequisites

- Lua 5.1 or later
- LuaRocks package manager
- Busted test framework

### Installation Steps (Amazon Linux 2023)

#### 1. Install Lua Development Files

```bash
sudo dnf install lua-devel
```

#### 2. Install LuaRocks from Source

```bash
# Download LuaRocks
wget https://luarocks.org/releases/luarocks-3.12.2.tar.gz
tar zxpf luarocks-3.12.2.tar.gz
cd luarocks-3.12.2

# Build and install
./configure && make && sudo make install
```

#### 3. Install Busted Test Framework

```bash
sudo luarocks install busted
```

## Running Tests

```bash
# Run all tests
sudo busted ./aws-for-fluent-bit/tests/filters/

# Run specific test suite
sudo busted ./aws-for-fluent-bit/tests/filters/replace_dots_spec.lua
```

## Expected Output

When all tests pass with Busted, you should see:

```
●●●●●●●●●●●●
12 successes / 0 failures / 0 errors / 0 pending : 0.007689 seconds
```

## Resources

- [Busted Documentation](https://lunarmodules.github.io/busted/)
- [Busted Assertions](https://lunarmodules.github.io/busted/#asserts)
