import struct
import json
import math

def process_all():
    # -------------------------------------------------------------
    # 1. CAMPFIRE
    # -------------------------------------------------------------
    print("Processing campfire.glb...")
    with open('d:/Godot/troll/assets/models/camp/campfire.glb', 'rb') as f:
        magic, version, length = struct.unpack('<4sII', f.read(12))
        chunk_len, chunk_type = struct.unpack('<I4s', f.read(8))
        json_data = f.read(chunk_len).decode('utf-8')
        gltf = json.loads(json_data)
        bin_offset = 12 + 8 + chunk_len
        f.seek(bin_offset)
        bin_len, bin_type = struct.unpack('<I4s', f.read(8))
        bin_data = f.read(bin_len)

    bv_pos = gltf['bufferViews'][0]
    bv_norm = gltf['bufferViews'][1]
    bv_uv = gltf['bufferViews'][2]
    bv_ind = gltf['bufferViews'][3]

    pos_bytes = bin_data[bv_pos['byteOffset']:bv_pos['byteOffset']+bv_pos['byteLength']]
    norm_bytes = bin_data[bv_norm['byteOffset']:bv_norm['byteOffset']+bv_norm['byteLength']]
    uv_bytes = bin_data[bv_uv['byteOffset']:bv_uv['byteOffset']+bv_uv['byteLength']]
    ind_bytes = bin_data[bv_ind['byteOffset']:bv_ind['byteOffset']+bv_ind['byteLength']]

    num_verts = gltf['accessors'][0]['count']
    num_inds = gltf['accessors'][3]['count']

    # Shift so bottom of stones (y = -0.5119) rests right on ground y = 0
    y_shift = 0.512
    positions = []
    for i in range(num_verts):
        x, y, z = struct.unpack('<fff', pos_bytes[i*12:(i+1)*12])
        positions.append((x, y + y_shift, z))

    normals = [struct.unpack('<fff', norm_bytes[i*12:(i+1)*12]) for i in range(num_verts)]
    uvs = [struct.unpack('<ff', uv_bytes[i*8:(i+1)*8]) for i in range(num_verts)]
    indices = [struct.unpack('<H', ind_bytes[i*2:(i+1)*2])[0] for i in range(num_inds)]

    # Connected components
    vert_pos_map = {}
    for i, pos in enumerate(positions):
        k = (round(pos[0], 3), round(pos[1], 3), round(pos[2], 3))
        vert_pos_map.setdefault(k, []).append(i)

    parent = {}
    def find(i):
        if parent.setdefault(i, i) != i:
            parent[i] = find(parent[i])
        return parent[i]
    def union(i, j):
        ri, rj = find(i), find(j)
        if ri != rj:
            parent[ri] = rj

    for k, vlist in vert_pos_map.items():
        for v in vlist[1:]:
            union(vlist[0], v)
    for t in range(0, len(indices), 3):
        union(indices[t], indices[t+1])
        union(indices[t+1], indices[t+2])

    components = {}
    for t in range(0, len(indices), 3):
        root = find(indices[t])
        components.setdefault(root, []).append(t // 3)

    base_tris = []
    flame_tris = []
    for r, tri_list in components.items():
        tri_verts = []
        for tri in tri_list:
            tri_verts.extend([indices[tri*3], indices[tri*3+1], indices[tri*3+2]])
        ys = [positions[v][1] for v in tri_verts]
        # Flame reaches higher up (above 0.9m after shift)
        if max(ys) > 0.95:
            flame_tris.extend(tri_list)
        else:
            base_tris.extend(tri_list)

    print(f"Campfire: {len(base_tris)} base tris, {len(flame_tris)} flame tris")

    def write_campfire_obj(filepath, tri_list):
        with open(filepath, 'w') as f:
            f.write("mtllib campfire.mtl\n")
            f.write("usemtl mat_campfire\n")
            for p in positions:
                f.write(f"v {p[0]:.4f} {p[1]:.4f} {p[2]:.4f}\n")
            for u in uvs:
                f.write(f"vt {u[0]:.4f} {1.0 - u[1]:.4f}\n")
            for n in normals:
                f.write(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}\n")
            for tri in tri_list:
                i1 = indices[tri*3] + 1
                i2 = indices[tri*3+1] + 1
                i3 = indices[tri*3+2] + 1
                f.write(f"f {i1}/{i1}/{i1} {i2}/{i2}/{i2} {i3}/{i3}/{i3}\n")

    write_campfire_obj('d:/Godot/troll/assets/models/camp/campfire_base.obj', base_tris)
    write_campfire_obj('d:/Godot/troll/assets/models/camp/campfire_flames.obj', flame_tris)
    with open('d:/Godot/troll/assets/models/camp/campfire.mtl', 'w') as f:
        f.write("newmtl mat_campfire\n")
        f.write("map_Kd campfire_palette.png\n")
        f.write("Kd 1.0 1.0 1.0\n")

    # -------------------------------------------------------------
    # 2. WOOD LOG (Quaternius)
    # -------------------------------------------------------------
    print("Processing wood_log.glb...")
    with open('d:/Godot/troll/assets/models/items/wood_log.glb', 'rb') as f:
        magic, version, length = struct.unpack('<4sII', f.read(12))
        chunk_len, chunk_type = struct.unpack('<I4s', f.read(8))
        json_data = f.read(chunk_len).decode('utf-8')
        gltf = json.loads(json_data)
        bin_offset = 12 + 8 + chunk_len
        f.seek(bin_offset)
        bin_len, bin_type = struct.unpack('<I4s', f.read(8))
        bin_data = f.read(bin_len)

    # WoodLog has 2 primitives: 0 is Wood (bark), 1 is LightWood (ends)
    # Node 1 transform:
    # rotation: [-0.66784, -0.232357, -0.232357, 0.66784]
    # scale: [198.943, 198.943, 198.943]
    # We bake this transform so log rests horizontally centered
    node = gltf['nodes'][1]
    qx, qy, qz, qw = node['rotation']
    sx, sy, sz = node['scale']

    # Normalize log size to ~0.7m length, ~0.2m radius for loot drops
    target_scale = 0.45

    # Quaternion rotation matrix
    r00 = 1.0 - 2.0*(qy*qy + qz*qz)
    r01 = 2.0*(qx*qy - qz*qw)
    r02 = 2.0*(qx*qz + qy*qw)
    r10 = 2.0*(qx*qy + qz*qw)
    r11 = 1.0 - 2.0*(qx*qx + qz*qz)
    r12 = 2.0*(qy*qz - qx*qw)
    r20 = 2.0*(qx*qz - qy*qw)
    r21 = 2.0*(qy*qz + qx*qw)
    r22 = 1.0 - 2.0*(qx*qx + qy*qy)

    def transform_pt(p):
        # scale
        x, y, z = p[0]*sx*target_scale, p[1]*sy*target_scale, p[2]*sz*target_scale
        # rotate
        rx = r00*x + r01*y + r02*z
        ry = r10*x + r11*y + r12*z
        rz = r20*x + r21*y + r22*z
        return (rx, ry, rz)

    with open('d:/Godot/troll/assets/models/items/wood_log.mtl', 'w') as f:
        f.write("# Materials for Quaternius Wood Log\n")
        f.write("newmtl Wood\nKd 0.38 0.22 0.12\nKs 0.05 0.05 0.05\nNs 10.0\n\n")
        f.write("newmtl LightWood\nKd 0.62 0.48 0.32\nKs 0.05 0.05 0.05\nNs 10.0\n\n")

    log_verts = []
    log_normals = []
    prims_faces = [] # list of (mat_name, faces)

    vert_offset = 0
    for p_idx, prim in enumerate(gltf['meshes'][0]['primitives']):
        mat_name = gltf['materials'][prim['material']]['name']
        p_acc = gltf['accessors'][prim['attributes']['POSITION']]
        n_acc = gltf['accessors'][prim['attributes']['NORMAL']]
        i_acc = gltf['accessors'][prim['indices']]

        p_bv = gltf['bufferViews'][p_acc['bufferView']]
        n_bv = gltf['bufferViews'][n_acc['bufferView']]
        i_bv = gltf['bufferViews'][i_acc['bufferView']]

        p_bytes = bin_data[p_bv['byteOffset']:p_bv['byteOffset']+p_bv['byteLength']]
        n_bytes = bin_data[n_bv['byteOffset']:n_bv['byteOffset']+n_bv['byteLength']]
        i_bytes = bin_data[i_bv['byteOffset']:i_bv['byteOffset']+i_bv['byteLength']]

        p_count = p_acc['count']
        i_count = i_acc['count']

        sub_verts = []
        for i in range(p_count):
            raw_p = struct.unpack('<fff', p_bytes[i*12:(i+1)*12])
            tp = transform_pt(raw_p)
            sub_verts.append(tp)
            log_verts.append(tp)

            raw_n = struct.unpack('<fff', n_bytes[i*12:(i+1)*12])
            tn = transform_pt(raw_n)
            l = math.sqrt(tn[0]**2 + tn[1]**2 + tn[2]**2) or 1.0
            log_normals.append((tn[0]/l, tn[1]/l, tn[2]/l))

        faces = []
        for i in range(0, i_count, 3):
            i1 = struct.unpack('<H', i_bytes[i*2:(i+1)*2])[0] + vert_offset + 1
            i2 = struct.unpack('<H', i_bytes[(i+1)*2:(i+2)*2])[0] + vert_offset + 1
            i3 = struct.unpack('<H', i_bytes[(i+2)*2:(i+3)*2])[0] + vert_offset + 1
            faces.append((i1, i2, i3))

        vert_offset += p_count
        prims_faces.append((mat_name, faces))

    # Shift so bottom rests on y = 0
    min_y = min(v[1] for v in log_verts)
    log_verts = [(v[0], v[1] - min_y, v[2]) for v in log_verts]

    with open('d:/Godot/troll/assets/models/items/wood_log.obj', 'w') as f:
        f.write("# Quaternius Wood Log\n")
        f.write("mtllib wood_log.mtl\n")
        for v in log_verts:
            f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
        for n in log_normals:
            f.write(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}\n")
        for mat_name, faces in prims_faces:
            f.write(f"usemtl {mat_name}\n")
            for f1, f2, f3 in faces:
                f.write(f"f {f1}//{f1} {f2}//{f2} {f3}//{f3}\n")

    print(f"Exported wood_log.obj: {len(log_verts)} vertices")

    # -------------------------------------------------------------
    # 3. TREE (Poly by Google)
    # -------------------------------------------------------------
    print("Processing tree.glb...")
    with open('d:/Godot/troll/assets/models/nature/tree.glb', 'rb') as f:
        magic, version, length = struct.unpack('<4sII', f.read(12))
        chunk_len, chunk_type = struct.unpack('<I4s', f.read(8))
        json_data = f.read(chunk_len).decode('utf-8')
        gltf = json.loads(json_data)
        bin_offset = 12 + 8 + chunk_len
        f.seek(bin_offset)
        bin_len, bin_type = struct.unpack('<I4s', f.read(8))
        bin_data = f.read(bin_len)

    p_acc = gltf['accessors'][0]
    uv_acc = gltf['accessors'][1]
    i_acc = gltf['accessors'][2]

    p_bv = gltf['bufferViews'][p_acc['bufferView']]
    uv_bv = gltf['bufferViews'][uv_acc['bufferView']]
    i_bv = gltf['bufferViews'][i_acc['bufferView']]

    p_bytes = bin_data[p_bv['byteOffset']:p_bv['byteOffset']+p_bv['byteLength']]
    uv_bytes = bin_data[uv_bv['byteOffset']:uv_bv['byteOffset']+uv_bv['byteLength']]
    i_bytes = bin_data[i_bv['byteOffset']:i_bv['byteOffset']+i_bv['byteLength']]

    t_count = p_acc['count']
    ti_count = i_acc['count']

    tree_scale = 0.01 # convert cm to m (height ~ 5.09m)
    tree_verts = []
    tree_uvs = []
    for i in range(t_count):
        x, y, z = struct.unpack('<fff', p_bytes[i*12:(i+1)*12])
        u, v = struct.unpack('<ff', uv_bytes[i*8:(i+1)*8])
        tree_verts.append((x * tree_scale, y * tree_scale, z * tree_scale))
        tree_uvs.append((u, 1.0 - v))

    tree_faces = []
    for i in range(0, ti_count, 3):
        i1 = struct.unpack('<H', i_bytes[i*2:(i+1)*2])[0] + 1
        i2 = struct.unpack('<H', i_bytes[(i+1)*2:(i+2)*2])[0] + 1
        i3 = struct.unpack('<H', i_bytes[(i+2)*2:(i+3)*2])[0] + 1
        tree_faces.append((i1, i2, i3))

    with open('d:/Godot/troll/assets/models/nature/tree.mtl', 'w') as f:
        f.write("newmtl Mat\n")
        f.write("map_Kd tree_0.png\n")
        f.write("Kd 1.0 1.0 1.0\n")

    with open('d:/Godot/troll/assets/models/nature/tree.obj', 'w') as f:
        f.write("# Poly by Google Tree\n")
        f.write("mtllib tree.mtl\n")
        f.write("usemtl Mat\n")
        for v in tree_verts:
            f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
        for u in tree_uvs:
            f.write(f"vt {u[0]:.4f} {u[1]:.4f}\n")
        for f1, f2, f3 in tree_faces:
            f.write(f"f {f1}/{f1} {f2}/{f2} {f3}/{f3}\n")

    print(f"Exported tree.obj: {len(tree_verts)} vertices, height: {max(v[1] for v in tree_verts):.2f}m")

if __name__ == '__main__':
    process_all()
