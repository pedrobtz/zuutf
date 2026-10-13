"""Write the Base64 fixtures of tests/testthat/fixtures as hex TSV, so that
the tests read them without a JSON parser.

  python3 tools/fixtures/make-base64-fixtures.py base64.json

base64.json is web-platform-tests' fetch/data-urls/resources/base64.json
(the WHATWG forgiving-base64 vectors), at the commit MANIFEST.tsv records.
Each input is written as the hex of its UTF-8 bytes, and each expected
output as hex, or NA where decoding must fail.
"""
import json
import sys

out = "tests/testthat/fixtures/"

vectors = json.load(open(sys.argv[1], encoding="utf-8"))
with open(out + "whatwg-base64.tsv", "w", encoding="ascii", newline="\n") as f:
    f.write("input_hex\toutput_hex\n")
    for text, expected in vectors:
        inp = text.encode("utf-8").hex()
        exp = "NA" if expected is None else bytes(expected).hex()
        f.write(f"{inp}\t{exp}\n")

# RFC 4648 section 10, standard alphabet, padded
rfc = [("", ""), ("f", "Zg=="), ("fo", "Zm8="), ("foo", "Zm9v"),
       ("foob", "Zm9vYg=="), ("fooba", "Zm9vYmE="), ("foobar", "Zm9vYmFy")]
with open(out + "rfc4648-base64.tsv", "w", encoding="ascii", newline="\n") as f:
    f.write("binary\tbase64\n")
    for binary, encoded in rfc:
        f.write(f"{binary}\t{encoded}\n")
print(len(vectors), "WHATWG vectors,", len(rfc), "RFC 4648 vectors")
