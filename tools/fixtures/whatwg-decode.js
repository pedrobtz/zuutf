// Decode a file as UTF-8 with the WHATWG decoder (replacement on errors)
// and write the result as UTF-8. Generates
// tests/testthat/fixtures/UTF-8-test.whatwg.txt from UTF-8-test.txt:
//
//   node tools/fixtures/whatwg-decode.js \
//     tests/testthat/fixtures/UTF-8-test.txt \
//     tests/testthat/fixtures/UTF-8-test.whatwg.txt
//
// CPython's bytes.decode("utf-8", "replace") gives the same bytes.
const fs = require('fs');
const raw = fs.readFileSync(process.argv[2]);
const text = new TextDecoder('utf-8', { fatal: false, ignoreBOM: true }).decode(raw);
fs.writeFileSync(process.argv[3], Buffer.from(text, 'utf8'));
console.log(raw.length, Buffer.byteLength(text, 'utf8'));
