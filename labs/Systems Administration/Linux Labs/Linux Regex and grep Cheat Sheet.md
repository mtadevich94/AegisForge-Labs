# Linux Regex & grep Cheat Sheet

A regular expression ("regex") describes a *shape* of text, and `grep` prints the lines that match it. This sheet pairs with **Module 5** of the [Linux Administration Lab Guide](Linux%20Administration%20Lab%20Guide.md).

> **Golden rule:** always use `grep -E` (extended regex). It lets you write `{7}`, `+`, `?` and `|` directly. Without `-E` you would have to put a backslash in front of each one.

---

## 1. grep basics

```bash
grep -E 'pattern' file                # extended regex (use this one)
egrep 'pattern' file                  # older name for grep -E, same thing
grep -e cat -e dog file               # match EITHER word (two patterns, OR logic)
grep -E 'cat|dog' file                # same thing, written as one pattern
grep -i 'pattern' file                # ignore upper/lower case
grep -v 'pattern' file                # show lines that do NOT match
grep -n 'pattern' file                # show line numbers
grep -c 'pattern' file                # count matching lines
```

Reading from a pipe works the same way: `cat file | grep -E 'pattern'` is the same as `grep -E 'pattern' file`.

---

## 2. Building blocks

### Anchors

| Symbol | Meaning |
|---|---|
| `^` | start of the line |
| `$` | end of the line |
| `\<` | start of a word |
| `\>` | end of a word |

`\<` and `\>` make a pattern match a **whole word** instead of a piece of a longer one. You need them for any "exactly N letters" puzzle.

### Quantifiers (how many?)

| Symbol | Meaning |
|---|---|
| `{n}` | exactly *n* of the thing before it |
| `{n,m}` | between *n* and *m* |
| `?` | zero or one (optional) |
| `+` | one or more |
| `*` | zero or more |

A quantifier applies only to the **single character or class directly before it**.

### Character classes (which characters?)

| Class | Matches |
|---|---|
| `[A-Z]` | one uppercase letter |
| `[a-z]` | one lowercase letter |
| `[A-Za-z]` | one letter of either case |
| `[0-9]` | one digit |
| `[aeiou]` | one lowercase vowel |
| `[B-DF-HJ-NP-TV-Z]` | one **uppercase consonant** (all capitals except A, E, I, O, U) |
| `[. _-]` | one of: period, space, underscore, hyphen |
| `.` | any one character (outside brackets) |

> **The hyphen trap.** Inside `[ ]`, a `-` between two characters means a **range**. `[. -_]` looks like "period, space, hyphen, underscore", but it really means "period, **or everything from space to underscore**". That range includes digits and capital letters, so the pattern quietly accepts text you meant to reject. Put the hyphen **first or last** in the brackets: `[. _-]`.

---

## 3. Worked examples

Each example uses a file with one word per line. Try them against your own text files.

### Example 1: a 7-letter word, capitalized, starting with a consonant and ending with a vowel

```bash
grep -E '\<[B-DF-HJ-NP-TV-Z][A-Za-z]{5}[aeiou]\>' words.txt
```

| Part | Means |
|---|---|
| `\<` | the word starts here |
| `[B-DF-HJ-NP-TV-Z]` | 1 uppercase consonant |
| `[A-Za-z]{5}` | 5 more letters |
| `[aeiou]` | 1 lowercase vowel |
| `\>` | the word ends here |

That is 1 + 5 + 1 = **7 letters**.

> You'll see the long way written as `[A-Za-z][A-Za-z][A-Za-z][A-Za-z][A-Za-z]`. It works, but `{5}` says the same thing and is much easier to count.

### Example 2: a 10-letter word, same shape

```bash
grep -E '\<[B-DF-HJ-NP-TV-Z][a-z]{8}[aeiou]\>' words.txt
```

1 consonant + 8 letters + 1 vowel = **10 letters**. When a length requirement gets long, reach for `{n}`.

### Example 3: two words joined by a hyphen (10 letters, then 6 letters)

```bash
grep -E '\<[A-Za-z]{10}-[A-Za-z]{6}\>' words.txt
```

Without the `\<` and `\>`, this same pattern would also match inside a longer word such as `Tallahatchie-Pontoc` (an 11-letter first word). The anchors are what make it exact.

### Example 4: two capitalized words with an optional separator

**Requirements:** a first word of 4–8 letters, then an *optional* separator (period, space, underscore or hyphen), then a second word of 6–10 letters. Both words start with a capital.

```bash
grep -E '^[A-Z][A-Za-z]{3,7}[. _-]?[A-Z][A-Za-z]{5,9}$' file
```

| Part | Means |
|---|---|
| `^` | the line starts here |
| `[A-Z][A-Za-z]{3,7}` | 1 capital + 3 to 7 letters = a **4–8 letter** word |
| `[. _-]?` | zero or one separator |
| `[A-Z][A-Za-z]{5,9}` | 1 capital + 5 to 9 letters = a **6–10 letter** word |
| `$` | the line ends here |

---

## 4. Common traps

| Trap | What goes wrong | Fix |
|---|---|---|
| **Off by one on `{n}`** | You already wrote one letter by hand, then ask for `{7}` more | Count the explicit letters first. A 7-letter word with 1 explicit letter needs `{6}`. |
| **No `\<` `\>`** | A 7-letter pattern matches *inside* a 12-letter word | Anchor whole-word matches. |
| **The hyphen range** | `[. -_]` accepts digits and capitals | Put `-` first or last: `[. _-]` |
| **Forgetting `-E`** | `grep '[a-z]{7}'` finds nothing, because plain grep takes `{` literally | Use `grep -E`. |
| **`?` covers one thing** | `[. _-]?` means "zero or one of these characters", not "an optional group" | Use `( )?` to make a group optional. |
| **Pattern in the wrong quotes** | The shell eats `$` and `\` | Wrap patterns in **single quotes**: `'^abc$'` |

---

## 5. Companion text tools

These are often paired with `grep` in the lab:

```bash
cut -d : -f 1,6,7 /etc/passwd             # split on ":" and keep fields 1, 6 and 7
cut -d : -f 1,6,7 /etc/passwd | tr : -    # ...then swap each ":" for "-"
tr 'a-z' 'A-Z' < file                     # upper-case everything (original file is untouched)
sort file                                 # alphabetical
sort -t : -k 3 -n /etc/passwd             # numeric sort on field 3 (the UID)
wc -l file                                # count lines (-w words, -c bytes)
```

For `/etc/passwd`, the fields are: `username : password : UID : GID : comment : home : shell`.
