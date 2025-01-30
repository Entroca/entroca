# hashmap

## API

### Init

```zig
const hash_map = try HashMap.init(allocator, 1024);
```

### Get

```zig
const value = try hash_map.get(hash, key);
```

### Put

```zig
_ = try hash_map.put(hash, key, value);
```

### Del

```zig
_ = try hash_map.del(hash, key);
```
