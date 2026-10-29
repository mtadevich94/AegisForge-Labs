# Suricata Rule Primer

Part 1 asks you to write five rules. Neither Packet Watch nor the Gatehouse teaches rule syntax, so this page does. It is short on purpose. The official [Suricata rules documentation](https://docs.suricata.io/en/latest/rules/index.html) is the full reference, and looking things up there is part of the job.

## Anatomy of a rule

```
alert http any any -> any any (msg:"EXAMPLE scripted HTTP client"; flow:to_server,established; http.user_agent; content:"python-requests"; startswith; classtype:policy-violation; sid:9100090; rev:1;)
└─1─┘ └2─┘ └──3──┘ └4┘ └──3──┘ └──────────────────────────────────────── 5 ────────────────────────────────────────────────────┘
```

1. **Action.** `alert` writes a log line. (`drop` blocks, but only when Suricata runs inline. You will only use `alert`.)
2. **Protocol.** `tcp`, `udp`, or an application protocol Suricata understands: `http`, `dns`, `tls`.
3. **Source and destination**, as `address port`. `any any -> any any` means anything to anything. `$HOME_NET` is your own network. The arrow shows direction.
4. *(the arrow)*
5. **Options in parentheses**, each ending in a semicolon. They are checked in order.

## The options you will use

| Option | What it does |
|---|---|
| `msg:"..."` | The text in the alert. Make it say what was seen. |
| `flow:to_server,established;` | Only look at traffic going to a server, on an established connection. |
| `flags:S;` | A TCP packet with the SYN flag set and no ACK (the start of a new connection). |
| `http.method;` `http.uri;` `http.request_body;` `http.user_agent;` | **Sticky buffers.** They select which part of the HTTP message the *next* `content` checks. |
| `dns.query;` | The same idea, for the name being looked up. |
| `tls.sni;` | The server name a client asks for in the TLS handshake. It is visible even though the rest is encrypted. |
| `content:"text";` | Match these exact bytes in the selected buffer. Add `nocase;` to ignore case. |
| `startswith;` `endswith;` | Pin a `content` match to the start or end of the buffer. |
| `pcre:"/.../i";` | A regular expression, for patterns `content` can't express. Slower, so use it last. |
| `threshold: type both, track by_src, count 8, seconds 30;` | Count matches. Alert once when the count is reached within the time window, then stay quiet until the window ends. |
| `classtype:...;` | A label for the kind of alert. |
| `sid:9100090; rev:1;` | A unique rule ID and revision. Use the lab's range `9100001–9100099`. Change `rev` when you edit the rule. |

### Thresholds, in plain words

- `type limit`: alert on the first N matches in the window, then ignore the rest.
- `type threshold`: alert every Nth match.
- `type both`: alert **once** when N matches happen inside the window. This is what you want for "many attempts from one source".
- `track by_src` counts per source address; `by_dst` per destination.

Offline thresholds are not exact. Read the quirk note in the **[Detection Lab Setup](Detection%20Lab%20Setup.md)**.

## A worked example (not one of your five)

Say you want to know when something scripted, not a browser, talks HTTP. A scripted client often announces itself in its `User-Agent` header:

```
alert http any any -> any any (msg:"EXAMPLE scripted HTTP client"; flow:to_server,established; http.user_agent; content:"python-requests"; startswith; classtype:policy-violation; sid:9100090; rev:1;)
```

Tested here: it fires on `06-incident.pcap` (22 times: every request from the scripted client, not just the login guesses) and stays silent on `07-hunt.pcap`. Notice what it doesn't do. It doesn't tell you the requests were malicious, only that the client wasn't a browser. That is exactly the kind of sentence your rule comments should hold:

```
# CATCHES:        HTTP requests whose User-Agent starts with "python-requests"
# COULD WRONGLY CATCH: any legitimate script, monitoring job or internal tool written in Python
```

## Comment every rule this way

Above each rule in your file, add two lines: **what it catches** and **what it could wrongly catch**. The second line is the one analysts thank you for six months later.

## The test loop

```bash
suricata -T -S my.rules -c /etc/suricata/suricata.yaml        # check syntax only
rm -rf out && mkdir out
suricata -r 06-incident.pcap -S my.rules -l out -k none        # replay
cat out/fast.log                                               # read the alerts
```

`-T` is the fast one. It prints the exact line and the problem when a rule won't parse.

| Symptom | Likely cause |
|---|---|
| `error parsing signature` | A missing semicolon or quote, an option typed wrong, or a `content` with no sticky buffer in front of it for an application protocol. |
| No alerts at all | The rule loaded but never matched. Check the protocol keyword, the direction (`->`), and that you picked the right buffer. |
| Alerts on everything | The match is too loose. Add `flow`, tighten the `content`, or add a threshold. |
| Different alert counts per run | Thresholds in offline replay. Run it three times and report the range. |

## Keep your first draft

Part 1 asks for **at least one rule you tuned**. That is only possible if you can show the rule *before*. So:

1. Save your first working draft as `my-v1.rules` and copy the `07-hunt.pcap` alert output next to it.
2. Tune in `my.rules`.
3. In the report, show v1, the false positive it produced, the change, and the new result.

A rule that was right the first time is lucky, not skilled. Trying a **naive threshold** on the scan rule first is a good way to see a real false positive.
