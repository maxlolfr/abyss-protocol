"""Réduit le nombre de triangles d'un GLB (un maillage Tripo) pour le téléphone, textures et UV gardés.

Usage : python3 -I tools/reduce_glb.py entree.glb sortie.glb triangles_max
La simplification est celle de Godot (niveaux de détail de l'import, via godot/tests/lods.gd) : on garde le niveau le
plus fin qui tient dans le budget. Godot : variable GODOT, sinon /home/claude/bin/Godot_v4.7.2-stable_linux.x86_64.
"""
import json
import os
import struct
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.environ.get("GODOT", "/home/claude/bin/Godot_v4.7.2-stable_linux.x86_64")
DT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read(path):
    b = open(path, "rb").read()
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jlen])
    blen = struct.unpack("<I", b[20 + jlen:24 + jlen])[0]
    return j, b[28 + jlen:28 + jlen + blen]


def write(path, j, blob):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    blob = bytes(blob) + b"\0" * (-len(blob) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(blob)))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\x00") + blob)


def levels(src):
    out = tempfile.mktemp(suffix=".bin")
    subprocess.run([GODOT, "--headless", "--path", os.path.join(HERE, "..", "godot"), "-s", "res://tests/lods.gd", "--",
                    os.path.abspath(src), out], check=True, capture_output=True)
    d = open(out, "rb").read()
    os.remove(out)
    n, pos, res = struct.unpack("<I", d[:4])[0], 4, []
    for _ in range(n):
        c = struct.unpack("<I", d[pos:pos + 4])[0]
        res.append(np.frombuffer(d[pos + 4:pos + 4 + c * 4], np.int32).copy())
        pos += 4 + c * 4
    return res


def reduce(src, dst, budget):
    j, blob = read(src)
    prims = [p for m in j["meshes"] for p in m["primitives"]]
    acc = j["accessors"]

    def get(i):
        a = acc[i]
        bv = j["bufferViews"][a["bufferView"]]
        k = NC[a["type"]]
        return np.frombuffer(blob, DT[a["componentType"]], a["count"] * k,
                             bv.get("byteOffset", 0) + a.get("byteOffset", 0)).reshape(-1, k)

    tris = sum(acc[p["indices"]]["count"] // 3 for p in prims)
    if len(prims) != 1 or tris <= budget:
        write(dst, j, blob)
        return tris, tris
    p = prims[0]
    pick = get(p["indices"]).ravel().astype(np.int64)
    for lv in levels(src):  # du plus fin au plus grossier
        pick = lv.astype(np.int64)
        if len(pick) // 3 <= budget:
            break
    keep, remap = np.unique(pick, return_inverse=True)
    used = {p["indices"], *p["attributes"].values()}
    out, views, newacc = bytearray(), [], {}
    for n, bv in enumerate(j["bufferViews"]):  # vues non touchées (textures…) recopiées
        if any(a.get("bufferView") == n for i, a in enumerate(acc) if i in used):
            views.append(None)
            continue
        while len(out) % 4:
            out.append(0)
        data = blob[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        views.append({**bv, "byteOffset": len(out), "byteLength": len(data)})
        out += data

    def add(arr, target=None):
        nonlocal out
        while len(out) % 4:
            out.append(0)
        data = arr.tobytes()
        v = {"buffer": 0, "byteOffset": len(out), "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        out += data
        return len(views) - 1

    for name, i in p["attributes"].items():
        arr = np.ascontiguousarray(get(i)[keep])
        a = {**acc[i], "bufferView": add(arr, 34962), "byteOffset": 0, "count": len(keep)}
        if name == "POSITION":
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        newacc[i] = a
    idx = remap.astype(np.uint32)
    newacc[p["indices"]] = {"bufferView": add(idx, 34963), "byteOffset": 0, "componentType": 5125, "count": len(idx),
                            "type": "SCALAR"}
    # vues supprimées -> renumérotation
    order = [n for n, v in enumerate(views) if v is not None]
    ren = {o: n for n, o in enumerate(order)}
    j["bufferViews"] = [views[o] for o in order]
    j["accessors"] = [newacc.get(i, a) for i, a in enumerate(acc)]
    for a in j["accessors"]:
        a["bufferView"] = ren[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = ren[im["bufferView"]]
    j["buffers"] = [{"byteLength": len(out) + (-len(out) % 4)}]
    write(dst, j, out)
    return tris, len(idx) // 3


if __name__ == "__main__":
    a, b = reduce(sys.argv[1], sys.argv[2], int(sys.argv[3]))
    print("%d -> %d triangles" % (a, b))
