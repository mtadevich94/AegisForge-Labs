# tools/

Maintainer scripts — **students don't need these**.

`make_pcaps.py` + `flowlib.py` regenerate the six lab pcaps from scratch using [Scapy](https://scapy.net/). The packets are hand-crafted (not captured), which is why the lab is fully reproducible and contains no real-world data.

```bash
pip install scapy
python3 make_pcaps.py ../pcaps
```

If you change the story (usernames, passwords, ports), regenerate the pcaps **and** update the Answer Key and the setup scripts so they stay in sync. Then regenerate `SHA256SUMS`:

```bash
cd .. && sha256sum pcaps/*.pcap *.sh *.ps1 > SHA256SUMS
```
