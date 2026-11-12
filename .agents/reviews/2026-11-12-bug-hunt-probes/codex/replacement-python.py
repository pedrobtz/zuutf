for e,b in [('utf-16-le',bytes.fromhex('00d841')),('utf-16-be',bytes.fromhex('d80041'))]:
 print(e,b.hex(),b.decode(e,errors='replace').encode().hex())
