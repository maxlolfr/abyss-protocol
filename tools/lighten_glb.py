"""Version allégée d'un modèle GLB (Tripo) pour le jeu : textures réduites et réencodées en JPEG.

Usage : python3 -I tools/lighten_glb.py entree.glb sortie.glb [taille_max=1024]
Les originaux de Max ne sont jamais publiés : seule la version allégée entre dans le dépôt.
"""
import io
import json
import struct
import sys

from PIL import Image


def lighten(src: str, dst: str, size: int = 1024) -> None:
    b = open(src, "rb").read()
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jlen])
    bin_off = 20 + jlen + 8
    blob = b[bin_off:bin_off + struct.unpack("<I", b[20 + jlen:24 + jlen])[0]]
    images = {i["bufferView"]: n for n, i in enumerate(j.get("images", []))}
    out = bytearray()
    for n, bv in enumerate(j["bufferViews"]):
        data = blob[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        if n in images:
            im = Image.open(io.BytesIO(data)).convert("RGB")
            if max(im.size) > size:
                im = im.resize((size, size), Image.LANCZOS)
            buf = io.BytesIO()
            im.save(buf, "JPEG", quality=88, optimize=True)
            data = buf.getvalue()
            j["images"][images[n]]["mimeType"] = "image/jpeg"
        while len(out) % 4:
            out.append(0)
        bv["byteOffset"] = len(out)
        bv["byteLength"] = len(data)
        out += data
    while len(out) % 4:
        out.append(0)
    j["buffers"] = [{"byteLength": len(out)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(out), b"BIN\x00") + out)


if __name__ == "__main__":
    lighten(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1024)
