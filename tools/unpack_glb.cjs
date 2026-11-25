// Décompresse un GLB produit par gltfpack (EXT_meshopt_compression + KHR_mesh_quantization) en GLB standard,
// lisible par Godot : node tools/unpack_glb.cjs entree.glb sortie.glb
// Décodeur : meshoptimizer (js/meshopt_decoder.cjs), chemin dans MESHOPT (défaut /home/claude/vendor/mo/js).
const fs = require("fs");
const path = require("path");
const M = require(path.join(process.env.MESHOPT || "/home/claude/vendor/mo/js", "meshopt_decoder.cjs"));
const SIZE = { 5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4 };
const NC = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };
const MAX = { 5120: 127, 5121: 255, 5122: 32767, 5123: 65535 };

M.ready.then(() => {
  const [src, dst] = process.argv.slice(2);
  const b = fs.readFileSync(src);
  const jl = b.readUInt32LE(12);
  const j = JSON.parse(b.slice(20, 20 + jl).toString());
  const bin = b.slice(28 + jl, 28 + jl + b.readUInt32LE(20 + jl));
  // 1. vues décompressées
  const views = j.bufferViews.map((bv) => {
    const ext = bv.extensions && bv.extensions.EXT_meshopt_compression;
    if (!ext) return bin.slice(bv.byteOffset || 0, (bv.byteOffset || 0) + bv.byteLength);
    const out = new Uint8Array(ext.count * ext.byteStride);
    const s = bin.slice(ext.byteOffset || 0, (ext.byteOffset || 0) + ext.byteLength);
    M.decodeGltfBuffer(out, ext.count, ext.byteStride, new Uint8Array(s), ext.mode, ext.filter || "NONE");
    bv.byteStride = ext.mode === "ATTRIBUTES" ? ext.byteStride : bv.byteStride;
    return Buffer.from(out);
  });
  // 2. accesseurs réécrits en données compactes ; attributs quantifiés remis en flottants
  const attrs = new Set();
  for (const m of j.meshes) for (const p of m.primitives) for (const k in p.attributes) attrs.add(p.attributes[k]);
  const chunks = [];
  let off = 0;
  const push = (buf, target) => {
    const pad = (4 - (off % 4)) % 4;
    if (pad) { chunks.push(Buffer.alloc(pad)); off += pad; }
    chunks.push(buf);
    const v = { buffer: 0, byteOffset: off, byteLength: buf.length };
    if (target) v.target = target;
    off += buf.length;
    return v;
  };
  const newViews = [];
  j.accessors.forEach((a, i) => {
    const bv = j.bufferViews[a.bufferView];
    const data = views[a.bufferView];
    const n = NC[a.type], cs = SIZE[a.componentType], stride = bv.byteStride || n * cs;
    const toFloat = attrs.has(i) && a.componentType !== 5126;
    const out = Buffer.alloc(a.count * n * (toFloat ? 4 : cs));
    for (let e = 0; e < a.count; e++)
      for (let c = 0; c < n; c++) {
        const o = (a.byteOffset || 0) + e * stride + c * cs;
        let v = { 5120: () => data.readInt8(o), 5121: () => data.readUInt8(o), 5122: () => data.readInt16LE(o),
          5123: () => data.readUInt16LE(o), 5125: () => data.readUInt32LE(o), 5126: () => data.readFloatLE(o) }[a.componentType]();
        if (toFloat) { if (a.normalized) v = Math.max(v / MAX[a.componentType], -1); out.writeFloatLE(v, (e * n + c) * 4); }
        else data.copy(out, (e * n + c) * cs, o, o + cs);
      }
    if (toFloat) { a.componentType = 5126; delete a.normalized; }
    newViews.push(push(out, attrs.has(i) ? 34962 : 34963));
    a.bufferView = newViews.length - 1;
    a.byteOffset = 0;
  });
  for (const img of j.images || []) {
    if (img.bufferView === undefined) continue;
    newViews.push(push(views[img.bufferView]));
    img.bufferView = newViews.length - 1;
  }
  j.bufferViews = newViews;
  j.buffers = [{ byteLength: off }];
  for (const k of ["extensionsUsed", "extensionsRequired"])
    if (j[k]) { j[k] = j[k].filter((e) => !["EXT_meshopt_compression", "KHR_mesh_quantization"].includes(e)); if (!j[k].length) delete j[k]; }
  let js = Buffer.from(JSON.stringify(j));
  js = Buffer.concat([js, Buffer.alloc((4 - (js.length % 4)) % 4, 0x20)]);
  let body = Buffer.concat(chunks);
  body = Buffer.concat([body, Buffer.alloc((4 - (body.length % 4)) % 4)]);
  const head = Buffer.alloc(12); head.writeUInt32LE(0x46546c67, 0); head.writeUInt32LE(2, 4); head.writeUInt32LE(28 + js.length + body.length, 8);
  const h1 = Buffer.alloc(8); h1.writeUInt32LE(js.length, 0); h1.write("JSON", 4);
  const h2 = Buffer.alloc(8); h2.writeUInt32LE(body.length, 0); h2.write("BIN\0", 4);
  fs.writeFileSync(dst, Buffer.concat([head, h1, js, h2, body]));
  console.log("ok", dst, j.extensionsRequired || []);
});
