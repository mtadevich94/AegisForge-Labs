# Wireshark Cheat Sheet — Traffic Analysis

Keep this open next to the [Wireshark Lab Guide](Wireshark%20Lab%20Guide.md). It collects the filters, menu paths and lookup tables you'll reach for again and again.

> **How to use it:** find the question you're trying to answer in the left column, then do what the right column says. Always point at a specific packet or field when you write your answer.

---

## 1. Display filters

Type these in the green filter bar and press **Enter**. Replace `<IP>` and `<#>` with your own values.

| You want to see… | Filter |
|---|---|
| Only ping (ICMP) traffic | `icmp` |
| Packets **from** one host | `ip.src == <IP>` |
| Packets **to** one host | `ip.dst == <IP>` |
| Packets to **or** from one host | `ip.addr == <IP>` |
| DNS sent by one host | `ip.src == <IP> && dns` |
| One host's traffic on one TCP port | `ip.src == <IP> && tcp.port == <#>` |
| HTTP GET requests | `http.request.method == "GET"` |
| DNS queries asking for an A record | `dns.qry.type == 1` |
| DNS responses containing an A record | `dns.resp.type == 1` |
| Connection attempts (SYN, no ACK) | `tcp.flags.syn == 1 && tcp.flags.ack == 0` |
| Everything except ARP and ping noise | `!(arp \|\| icmp)` |

> **Display filter ≠ capture filter.** A display filter only changes what you *see*. A capture filter, set before you start recording, changes what Wireshark *keeps*.

---

## 2. Getting around

| Task | How |
|---|---|
| Jump to a packet number | `Ctrl+G`, then type the number |
| Find text inside packets | `Ctrl+F`, set the type to **String**, then pick **Packet bytes** (raw payload) or **Packet details** (decoded fields), then enter your term |
| Read a whole conversation (an email, an HTTP session) | Right-click a packet → **Follow → TCP Stream** (or UDP / HTTP Stream) |
| Pull a file out of a capture | **File → Export Objects → HTTP** |

---

## 3. Who is talking to whom

| Question | Where to look |
|---|---|
| Which hosts are talking, and is anyone port scanning? | **Statistics → Conversations**. One source hitting many different destination ports in quick succession is the classic port-scan signature. |
| What is this packet's MAC address? | Click the packet, expand **Ethernet II**. Source and Destination hold the MACs. (**Frame** only holds capture details like length and timestamp.) |
| Who made this network card? | Turn on **View → Name Resolution → Resolve MAC Addresses** (also check **Edit → Preferences → Name Resolution**). The vendor name then appears in brackets next to the MAC in Ethernet II. |
| What website or host is this? | Follow the TCP stream, or read the `Host:` header in an HTTP request, or the **Server Name Indication** in a TLS Client Hello. |
| What is the web server's IP? | Filter `http.request.method == "GET"`, select the packet, read the **Destination** address in its IP header. The client sends the request *to* the server, so destination = server. |

---

## 4. DNS lookups

Filter: `dns`

- The **name that was looked up** is in the Info column and under **Queries → Name**.
- The **IP address that came back** (the A record) is in the *response* packet under **Answers → Address**. It is not in the query. Make sure you're looking at the response.

---

## 5. HTTP: what was transferred?

- **Fastest way to find an object's URI:** **File → Export Objects → HTTP**, then browse the list.
- Or select the GET request packet and read the URI from the HTTP request line.

---

## 6. Inside a packet

| You want… | Do this |
|---|---|
| The size of the data portion | In Packet Details, expand the protocol layer (TCP or HTTP) and find **Data: length** |
| The TCP flags | Expand **Transmission Control Protocol → Flags** |

---

## 7. File signatures ("magic numbers")

When a file crosses the wire, its first bytes tell you what it really is, whatever its name says. In **Follow TCP Stream**, switch the view to **Hex Dump** to read them.

| File type | Hex signature | Shows as |
|---|---|---|
| `.pdf` | `25 50 44 46` | `%PDF` |
| `.exe` | `4D 5A` | `MZ` |
| `.zip` | `50 4B 03 04` | `PK..` |
| `.docx` (also `.xlsx`, `.pptx`) | `50 4B 03 04 14 00 06 00` | `PK..` |
| `.doc` (older Word) | `D0 CF 11 E0 A1 B1 1A E1` at the start of the file. Word marks its content further in, with `EC A5 C1 00` at byte 512. | `ÐÏ.à¡±.á` |
| `.jpg` / `.jpeg` / `.jfif` | `FF D8 FF E0` | `ÿØÿà..JFIF` |
| `.png` | `89 50 4E 47 0D 0A 1A 0A` | `.PNG....` |
| `.gif` | `47 49 46 38` | `GIF8` |
| `.7z` | `37 7A BC AF 27 1C` | `7z¼¯'.` |
| `.gz` | `1F 8B` | (unprintable) |
| Linux program (ELF) | `7F 45 4C 46` | `.ELF` |

**Things that trip people up**

- **`MZ`, not `MX`.** `4D 5A` is `MZ`, the Windows program marker (named for Mark Zbikowski, an early Microsoft engineer).
- **`.docx` and `.zip` start with the same bytes** (`PK..`), because a `.docx` is a zip file with a Word-shaped folder inside. Look further in, or at the file name in the HTTP request, to tell them apart.
- A zip made by WinZip may also contain the text `WinZip` (`57 69 6E 5A 69 70`). `50 4B 03 04` is still the signature to lead with.
- JPEGs straight from a camera or phone often start `FF D8 FF E1` (Exif) instead of `E0`. Same file type.

---

## 8. Guessing the operating system

### By TTL (from the IP header)

| TTL seen | Probably |
|---|---|
| 64 | Linux, macOS and most Unix-like systems |
| 128 | Windows |
| 255 | Network gear (routers, switches). Some Solaris/AIX systems also use 254 or 255. |

TTL drops by 1 at every router. The value you *see* is the starting value minus the hops crossed. A packet arriving with TTL **61** most likely started at **64** and crossed 3 routers. Round **up** to the nearest of 64 / 128 / 255.

### By `User-Agent` (from an HTTP request)

| Token in the User-Agent | Operating system |
|---|---|
| `Windows NT 10.0` | Windows 10 **or** Windows 11 (11 kept the same version number, so the User-Agent can't tell them apart) |
| `Windows NT 6.3` | Windows 8.1 |
| `Windows NT 6.2` | Windows 8 |
| `Windows NT 6.1` | Windows 7 |
| `Windows NT 6.0` | Windows Vista |
| `Windows NT 5.2` | Windows Server 2003 / XP x64 |
| `Windows NT 5.1` | Windows XP |

> A `User-Agent` is whatever the client *says* it is. It is easy to fake, so treat it as a clue and not as proof.
