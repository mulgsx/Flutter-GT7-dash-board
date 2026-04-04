# GT7 Telemetry — Protocol & Decryption Reference

**Version:** 1.0 | **Game:** Gran Turismo 7 (PS4/PS5)
**Read alongside:** `packet_structure.md` (packet offsets, field types, computed values)

---

## 1. How It Works

GT7 broadcasts vehicle telemetry over UDP when it receives a periodic heartbeat from a client on the same local network. No special configuration is needed on the PS5.

```
[Your App]  ──── "A" every 100 ms ────►  [PS5 :33739]
[Your App]  ◄──── encrypted ~60 Hz ──────  [PS5 :33740]
```

---

## 2. Network Setup

### Ports

| Direction | Port | Description |
|-----------|------|-------------|
| Send (app → PS5) | **33739** | Heartbeat destination |
| Receive (PS5 → app) | **33740** | Bind your UDP socket here |

### Heartbeat

- Send a single ASCII byte `"A"` (`0x41`) to the PS5's IP on port **33739**
- Repeat every **100 ms** — if GT7 stops receiving it, the telemetry stream stops within a few seconds
- Use any source port (ephemeral is fine); GT7 does not care

### Minimal Flow

```
socket_recv = udp_bind("0.0.0.0", 33740)

timer_every(100ms):
    udp_send(data="A", dest_ip=ps5_ip, dest_port=33739)

loop:
    (data, src_ip) = socket_recv.receive()
    if src_ip != ps5_ip: continue      // ignore other senders

    packet = decrypt(data)
    if packet == null: continue        // magic check failed

    parse(packet)                      // see packet_structure.md
```

---

## 3. Decryption (Salsa20)

Every packet is Salsa20-encrypted. You must decrypt before reading any field.

### 3.1 Key

The 32-byte key is the **first 32 bytes** of this ASCII string:

```
"Simulator Interface Packet GT7 ver 0.0"
```

Hex bytes:
```
53 69 6D 75 6C 61 74 6F 72 20 49 6E 74 65 72 66
61 63 65 20 50 61 63 6B 65 74 20 47 54 37 20 76
```

### 3.2 IV Construction

The 8-byte IV is derived from bytes **[64:68]** of the **raw encrypted** packet.

```
Step 1: iv_source = encrypted_bytes[64:68]          // 4 bytes
Step 2: iv1 = read_uint32_little_endian(iv_source)
Step 3: iv2 = iv1 XOR 0xDEADBEAF                   // note: BEAF not BEEF
Step 4: iv  = to_bytes_LE(iv2, 4) + to_bytes_LE(iv1, 4)   // 8 bytes total
```

> The bytes layout of the IV:
> ```
> [0:4] = iv2 in little-endian
> [4:8] = iv1 in little-endian
> ```

### 3.3 Decryption Steps

1. Verify the raw packet is at least **68 bytes** (otherwise the IV source is missing)
2. Build the IV as described in 3.2
3. Initialize Salsa20 with the 32-byte key and 8-byte IV
4. Decrypt **the entire encrypted packet** (from byte 0, full length)
5. Read the magic number from offset `0x00` of the decrypted bytes
6. If magic ≠ `0x47375330`, discard the packet

### 3.4 Magic Number

| Value | ASCII | Meaning |
|-------|-------|---------|
| `0x47375330` | `GT70` | Valid packet — safe to parse |

### 3.5 Pseudocode

```
KEY = ascii("Simulator Interface Packet GT7 ver 0.0")[0:32]

func decrypt(encrypted: bytes) -> bytes | null:
    if len(encrypted) < 68:
        return null

    iv1 = uint32_le(encrypted[64:68])
    iv2 = iv1 XOR 0xDEADBEAF
    iv  = to_le_bytes(iv2, 4) + to_le_bytes(iv1, 4)

    decrypted = salsa20_decrypt(key=KEY, iv=iv, data=encrypted)

    if uint32_le(decrypted[0:4]) != 0x47375330:
        return null

    return decrypted
```

---

## 4. Packet Types

The heartbeat byte controls which packet type GT7 sends.

| Heartbeat | Type | Size | Extra Content | Restriction |
|-----------|------|------|---------------|-------------|
| `"A"` (0x41) | Packet A | **296 bytes** | Base telemetry | None |
| `"B"` (0x42) | Packet B | **316 bytes** | + Inertial forces, wheel rotation | Not available in Sport Mode |
| `"~"` (0x7E) | Packet C | **344 bytes** | + Active aero, energy recovery | Not available in Replay |

For field definitions of each packet type, see **`packet_structure.md`**.

---

## 5. Implementation Checklist

- [ ] Bind UDP socket on port **33740** (all interfaces, `0.0.0.0`)
- [ ] Send `"A"` to `<PS5_IP>:33739` every **100 ms**
- [ ] Filter incoming packets by source IP (reject non-PS5 senders)
- [ ] Check raw packet length ≥ 68 bytes before attempting decryption
- [ ] Extract bytes `[64:68]` from the **encrypted** buffer for IV derivation
- [ ] Apply `XOR 0xDEADBEAF` (not `0xDEADBEEF`)
- [ ] Assemble IV as `[iv2_LE | iv1_LE]` (iv2 first, iv1 second)
- [ ] Decrypt full packet with Salsa20
- [ ] Validate magic `0x47375330` at offset `0x00` before parsing
- [ ] Cancel heartbeat timer and close socket on disconnect

---

## 6. Common Pitfalls

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Magic number always wrong | IV byte order or XOR constant wrong | Verify `iv2` = `iv1 XOR 0xDEADBEAF`; check bytes go `iv2_LE` then `iv1_LE` |
| No packets received | Heartbeat not reaching PS5 | Confirm port **33739** for send, **33740** for receive |
| Stream stops after ~5 seconds | Heartbeat interval too long | Send every **100 ms**, not 1 s |
| Garbled values | Wrong endianness | All fields are **little-endian** |
| Packets from wrong sender | No source IP filter | Compare `src_ip == ps5_ip` and drop mismatches |

---

## 7. Salsa20 Libraries by Language

| Language | Recommended Library |
|----------|--------------------|
| **Swift** | SwiftSodium (wraps libsodium) — `CryptoKit` does not support Salsa20 |
| Python | `salsa20` or `pysodium` (pip) |
| JavaScript / Node.js | `libsodium-wrappers` (npm) |
| Go | `golang.org/x/crypto/salsa20` |
| Rust | `salsa20` crate (crates.io) |
| Kotlin / Java | Bouncy Castle |
| Dart / Flutter | `pointycastle` |
| C / C++ | `libsodium` |

---

*Reverse-engineered GT7 protocol. Verified against GT7 as of 2025. Packet layout may change with game updates.*
