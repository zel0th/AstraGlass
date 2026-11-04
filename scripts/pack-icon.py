"""Package standard PNG representations into an ICNS container."""
import pathlib
import struct
import sys
root = pathlib.Path(sys.argv[1])
types = [('icp4', '16x16'), ('icp5', '32x32'), ('icp6', '32x32@2x'),
         ('ic07', '128x128'), ('ic08', '256x256'), ('ic09', '512x512'),
         ('ic10', '512x512@2x'), ('ic11', '16x16@2x'), ('ic12', '32x32@2x'),
         ('ic13', '128x128@2x'), ('ic14', '256x256@2x')]
chunks = []
for kind, suffix in types:
    data = (root / ('icon_' + suffix + '.png')).read_bytes()
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(data) + 8) + data)
body = b''.join(chunks)
pathlib.Path(sys.argv[2]).write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
