# What Is a Beacon?

Read this before Part 2. The hunt only makes sense once you know what you are hunting and why it behaves the way it does. Nothing here is a how-to for attackers. It is the defender's picture.

## The problem the attacker has

Say an attacker gets a program running on one of your machines (a phishing attachment, a stolen password, a bad download). The program is called an **implant**. Now the attacker needs to **control it**: tell it what to do, and get results back.

The obvious way, connecting *in* to the machine, doesn't work. Firewalls and NAT block unsolicited inbound traffic, and your machine has no public address anyway. But almost every network lets machines connect **out**, because that is how people browse the web, check mail and update software.

So the implant does what a browser does. It reaches **out** to a server the attacker runs. That server is the **command-and-control** server, usually written **C2**.

## What a beacon is

A **beacon** is the implant's regular **check-in** with the C2 server. Each time, it is basically asking:

> "Anything for me to do? And here is what I've done so far."

If there are no instructions, the answer is tiny and the implant goes quiet until the next check-in. If there are, it runs them, and reports back at the next one.

This works on a timer for a good reason. The attacker doesn't want the implant holding a connection open all day (easy to spot). And it can't wait to be called (blocked). So it **polls**: wake up, check in, sleep, repeat.

## The two dials: sleep and jitter

- **Sleep** is the gap between check-ins. 5 seconds is chatty and noisy. An hour or a day is slow and quiet. Attackers who value stealth pick slow.
- **Jitter** is a random variation added to the sleep so the gaps aren't perfectly even. "60 seconds ± 10%" means anywhere from 54 to 66.

Without jitter a beacon ticks like a metronome, which is easy to find. With a lot of jitter and a long sleep it hides among normal traffic, but the attacker also gets slower control. **It is a trade between stealth and speed.** Remember this when you reach the "limits" section of your report.

Commercial and open-source attack frameworks (Cobalt Strike made the word "beacon" famous) expose these two settings as ordinary configuration options. Defenders talk about "sleep and jitter" for the same reason.

## What it travels over

C2 traffic is made to look like traffic that is already allowed:

| Channel | Looks like | What a defender can still see |
|---|---|---|
| **HTTPS** | Web browsing | The destination address and name, the timing, the sizes. (The content is encrypted.) |
| **DNS** | Name lookups | Every lookup. The names themselves can carry data. The `06-incident` capture has one. |
| **Cloud services** | Normal use of a popular site | Mostly timing and volume. Harder, because the destination is shared. |

Encryption hides **what** is said. It doesn't hide **that** it is said, **how often**, **how much** or **to whom**. That metadata is what this hunt uses.

## Why defenders can find it

A person browsing is irregular: bursts, long pauses, different sites. Software on a timer is not. A beacon tends to show:

| Sign | Why |
|---|---|
| **Steady gaps** | It runs on a timer, even with some jitter. |
| **Small, similar sizes** | "Anything for me?" and "no" are about the same size every time. |
| **One machine, one odd destination** | Normal services are used by many machines. A C2 server is used by the implant. |
| **An outside destination** | The attacker's server isn't inside your network. |
| **A strange or new name** | The domain may be recently created or look unlike anything your company uses. |
| **Odd hours or no human** | It keeps going when nobody is at the keyboard. |

## Why it is hard

**Each sign alone is also true of normal software.** Time sync, update checks, mail clients, monitoring agents and chat apps all run on timers. In `07-hunt.pcap` you will find several that are *more* regular than the beacon. That is deliberate. "Regular" is a lead, not a verdict, and the skill is telling a legitimate heartbeat from a malicious one by asking a few more questions about it.

That is also why detection comes in two flavors, and you do both in this challenge:

- **Rules (Part 1)** catch things you already *know* are bad: a known domain, a known pattern.
- **Hunting (Part 2)** finds things nobody has written a rule for yet, by looking for behavior.

## Where this sits in ATT&CK

MITRE ATT&CK catalogs command-and-control behavior. Good places to start reading:

- **Application Layer Protocol** (T1071), including the **DNS** variant (T1071.004)
- **Encrypted Channel** (T1573)
- **Command and Control** as a whole tactic

Look the IDs up on [attack.mitre.org](https://attack.mitre.org/), because identifiers change between versions.

## Check yourself

1. Why does an implant reach *out* to the attacker rather than waiting for a connection?
2. What does jitter do for the attacker, and what does it cost them?
3. Name two legitimate programs that would look "regular" in network data.
4. Encryption hides the content of a beacon. What does it leave visible?
5. Why would a one-hour sleep be harder to find in a fifty-minute capture than a one-minute sleep?

*(Answers are in your own notes. If you can answer 5, you understand the limits of your own hunt.)*
