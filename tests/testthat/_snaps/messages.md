# each condition's message reads as intended

    Code
      utf_valid("a", "EBCDIC")
    Condition
      Error in `utf_valid()`:
      ! `encoding` must be one of "UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE", "Latin-1", "ASCII", "UTF-16", "UTF-32", not "EBCDIC"

---

    Code
      base64_encode(raw(), line_length = 2)
    Condition
      Error in `base64_encode()`:
      ! `line_length` must be NULL or a whole number of at least 4

---

    Code
      utf_decode(list(raw(), as.raw(c(97, 255))), "UTF-8")
    Condition
      Error in `utf_decode()`:
      ! element 2 is ill-formed UTF-8 at offset 2

---

    Code
      utf_convert(as.raw(c(97, 0, 0, 78)), "UTF-16LE", "Latin-1")
    Condition
      Error in `utf_convert()`:
      ! element 1 has a code point at offset 2 that Latin-1 cannot represent

---

    Code
      utf_decode(as.raw(c(97, 0)), "UTF-8")
    Condition
      Error in `utf_decode()`:
      ! element 1 holds U+0000 at offset 2, which an R string cannot

---

    Code
      base64_decode("aGVsbG8", forgiving = FALSE)
    Condition
      Error in `base64_decode()`:
      ! invalid Base64 at offset 7

---

    Code
      zuutf:::raise_status(c(4, 3, 1, 1), "UTF-8", NULL)
    Condition
      Error:
      ! element 3 converts to more bytes than R can hold

---

    Code
      zuutf:::raise_status(c(5, 3, 1, 1), "UTF-8", NULL)
    Condition
      Error:
      ! unexpected status from the converter

