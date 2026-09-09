import os
import math

class ObjBuilder:
    def __init__(self, name="mesh", offset=(0.0, 0.0, 0.0)):
        self.name = name
        self.offset = offset
        self.vertices = []
        self.normals = []
        self.faces = []
        self.current_mat = "mat_stone"

    def set_material(self, mat_name):
        self.current_mat = mat_name

    def add_vertex(self, x, y, z):
        ox, oy, oz = self.offset
        self.vertices.append((round(x - ox, 4), round(y - oy, 4), round(z - oz, 4)))
        return len(self.vertices)

    def add_normal(self, nx, ny, nz):
        length = math.sqrt(nx*nx + ny*ny + nz*nz)
        if length > 0.00001:
            nx, ny, nz = nx/length, ny/length, nz/length
        else:
            nx, ny, nz = 0.0, 1.0, 0.0
        self.normals.append((round(nx, 4), round(ny, 4), round(nz, 4)))
        return len(self.normals)

    def add_triangle(self, v1, v2, v3):
        p1 = self.vertices[v1 - 1]
        p2 = self.vertices[v2 - 1]
        p3 = self.vertices[v3 - 1]
        ax, ay, az = p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2]
        bx, by, bz = p3[0] - p1[0], p3[1] - p1[1], p3[2] - p1[2]
        nx = ay * bz - az * by
        ny = az * bx - ax * bz
        nz = ax * by - ay * bx
        norm = self.add_normal(nx, ny, nz)
        self.faces.append((self.current_mat, [(v1, norm), (v2, norm), (v3, norm)]))

    def add_quad(self, v1, v2, v3, v4):
        self.add_triangle(v1, v2, v3)
        self.add_triangle(v1, v3, v4)

    def add_double_sided_quad(self, v1, v2, v3, v4):
        self.add_quad(v1, v2, v3, v4)
        self.add_quad(v4, v3, v2, v1)

    def add_double_sided_triangle(self, v1, v2, v3):
        self.add_triangle(v1, v2, v3)
        self.add_triangle(v3, v2, v1)

    def add_cylinder(self, rings):
        num_rings = len(rings)
        if num_rings < 2:
            return
        n_pts = len(rings[0])
        for r in range(num_rings - 1):
            r1 = rings[r]
            r2 = rings[r + 1]
            for i in range(n_pts):
                ni = (i + 1) % n_pts
                self.add_quad(r1[i], r2[i], r2[ni], r1[ni])

    def write_obj(self, filepath, mtl_filename):
        mat_groups = {}
        for mat, f_verts in self.faces:
            if mat not in mat_groups:
                mat_groups[mat] = []
            mat_groups[mat].append(f_verts)

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"# Low-Poly Prehistoric Asset: {self.name}\n")
            f.write(f"mtllib {mtl_filename}\n")
            f.write(f"o {self.name}\n\n")

            for v in self.vertices:
                f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
            f.write("\n")

            for n in self.normals:
                f.write(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}\n")
            f.write("\n")

            for mat, f_list in mat_groups.items():
                f.write(f"usemtl {mat}\n")
                f.write(f"s 1\n")
                for f_verts in f_list:
                    face_str = " ".join([f"{v}//{n}" for v, n in f_verts])
                    f.write(f"f {face_str}\n")
                f.write("\n")


# ---------------------------------------------------------------------------
# 1. LOW-POLY PALM TREE
# ---------------------------------------------------------------------------
def build_palm_tree():
    b = ObjBuilder("palm_tree")
    b.set_material("mat_wood")

    # Segmented curved trunk (height ~ 5.5m)
    trunk_segs = [
        # (y, radius, x_offset, z_offset)
        (0.0, 0.42, 0.0, 0.0),
        (1.0, 0.36, 0.05, 0.02),
        (2.2, 0.32, 0.16, 0.06),
        (3.4, 0.28, 0.28, 0.12),
        (4.4, 0.25, 0.40, 0.18),
        (5.2, 0.22, 0.48, 0.22),
    ]

    rings = []
    n_pts = 6
    for y, r, ox, oz in trunk_segs:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring.append(b.add_vertex(ox + math.cos(ang) * r, y, oz + math.sin(ang) * r))
        rings.append(ring)
    b.add_cylinder(rings)

    # Top crown leaves (mat_accent / green)
    b.set_material("mat_hair") # will map to lush leaf green
    top_ox, top_oy, top_oz = trunk_segs[-1][2], trunk_segs[-1][0], trunk_segs[-1][3]
    crown_pt = b.add_vertex(top_ox, top_oy + 0.3, top_oz)

    # 6 large drooping palm fronds
    num_fronds = 6
    for f in range(num_fronds):
        base_ang = f * (2.0 * math.pi / num_fronds)
        dir_x = math.cos(base_ang)
        dir_z = math.sin(base_ang)
        perp_x = -dir_z
        perp_z = dir_x

        # Frond spine points
        p0 = (top_ox, top_oy + 0.1, top_oz)
        p1 = (top_ox + dir_x * 1.4, top_oy + 0.6, top_oz + dir_z * 1.4)
        p2 = (top_ox + dir_x * 2.8, top_oy - 0.2, top_oz + dir_z * 2.8)
        p3 = (top_ox + dir_x * 3.6, top_oy - 1.2, top_oz + dir_z * 3.6)

        # Frond blade vertices (diamond cross sections)
        w1 = 0.55
        v0 = b.add_vertex(*p0)
        v1_l = b.add_vertex(p1[0] + perp_x * w1, p1[1], p1[2] + perp_z * w1)
        v1_r = b.add_vertex(p1[0] - perp_x * w1, p1[1], p1[2] - perp_z * w1)
        v1_c = b.add_vertex(p1[0], p1[1] + 0.1, p1[2])

        v2_l = b.add_vertex(p2[0] + perp_x * (w1 * 0.7), p2[1], p2[2] + perp_z * (w1 * 0.7))
        v2_r = b.add_vertex(p2[0] - perp_x * (w1 * 0.7), p2[1], p2[2] - perp_z * (w1 * 0.7))
        v2_c = b.add_vertex(p2[0], p2[1] + 0.08, p2[2])

        v3_tip = b.add_vertex(*p3)

        # Build frond quads/tris (double sided so leaves are visible from top and bottom)
        b.add_double_sided_triangle(v0, v1_l, v1_c)
        b.add_double_sided_triangle(v0, v1_c, v1_r)

        b.add_double_sided_quad(v1_l, v2_l, v2_c, v1_c)
        b.add_double_sided_quad(v1_c, v2_c, v2_r, v1_r)

        b.add_double_sided_triangle(v2_l, v3_tip, v2_c)
        b.add_double_sided_triangle(v2_c, v3_tip, v2_r)

    return b


# ---------------------------------------------------------------------------
# 2. CHUNKY PREHISTORIC WOODEN HUT
# ---------------------------------------------------------------------------
def build_primitive_hut():
    b = ObjBuilder("primitive_hut")

    # A-Frame logs (mat_wood)
    b.set_material("mat_wood")
    w, h, d = 2.4, 3.2, 3.0

    # 4 corner leaning log posts
    ridge_f = b.add_vertex(0.0, h, -d * 0.5)
    ridge_b = b.add_vertex(0.0, h,  d * 0.5)

    fl_bot = b.add_vertex(-w, 0.0, -d * 0.5)
    fr_bot = b.add_vertex( w, 0.0, -d * 0.5)
    bl_bot = b.add_vertex(-w, 0.0,  d * 0.5)
    br_bot = b.add_vertex( w, 0.0,  d * 0.5)

    # Ridge pole beam (double sided)
    b.add_double_sided_quad(ridge_f, ridge_b, ridge_b, ridge_f)

    # Animal hide canopy (mat_clothing)
    b.set_material("mat_clothing")

    # Left roof slope (double sided so visible inside and out)
    b.add_double_sided_quad(fl_bot, bl_bot, ridge_b, ridge_f)

    # Right roof slope (double sided)
    b.add_double_sided_quad(ridge_f, ridge_b, br_bot, fr_bot)

    # Back wall hide (double sided)
    b.add_double_sided_triangle(bl_bot, br_bot, ridge_b)

    # Wooden base support beams
    b.set_material("mat_wood")
    b.add_double_sided_quad(fl_bot, fr_bot, fr_bot, fl_bot)
    b.add_double_sided_quad(bl_bot, br_bot, br_bot, bl_bot)

    return b


# ---------------------------------------------------------------------------
# 3. OVERSIZED MAMMOTH BONE
# ---------------------------------------------------------------------------
def build_mammoth_bone():
    b = ObjBuilder("mammoth_bone")
    b.set_material("mat_accent") # Bone ivory white

    # Bone shaft along X axis (length ~ 2.2m)
    shaft_rings = [
        (-0.8, 0.12),
        (-0.4, 0.10),
        ( 0.0, 0.09),
        ( 0.4, 0.10),
        ( 0.8, 0.12),
    ]

    rings = []
    n_pts = 6
    for x, r in shaft_rings:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring.append(b.add_vertex(x, math.cos(ang) * r, math.sin(ang) * r))
        rings.append(ring)
    b.add_cylinder(rings)

    # Left knobs (two rounded lumps at X=-1.0)
    for sign_z in [-1, 1]:
        kx = -1.0
        kz = sign_z * 0.16
        kr = 0.18
        k_ring1 = []
        k_ring2 = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            k_ring1.append(b.add_vertex(kx + 0.12, math.cos(ang) * kr * 0.7, kz + math.sin(ang) * kr * 0.7))
            k_ring2.append(b.add_vertex(kx,        math.cos(ang) * kr,       kz + math.sin(ang) * kr))
        b.add_cylinder([k_ring1, k_ring2])
        tip = b.add_vertex(kx - 0.08, 0.0, kz)
        for i in range(n_pts):
            ni = (i + 1) % n_pts
            b.add_triangle(tip, k_ring2[i], k_ring2[ni])

    # Right knobs (two rounded lumps at X=+1.0)
    for sign_z in [-1, 1]:
        kx = 1.0
        kz = sign_z * 0.16
        kr = 0.18
        k_ring1 = []
        k_ring2 = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            k_ring1.append(b.add_vertex(kx - 0.12, math.cos(ang) * kr * 0.7, kz + math.sin(ang) * kr * 0.7))
            k_ring2.append(b.add_vertex(kx,        math.cos(ang) * kr,       kz + math.sin(ang) * kr))
        b.add_cylinder([k_ring1, k_ring2])
        tip = b.add_vertex(kx + 0.08, 0.0, kz)
        for i in range(n_pts):
            ni = (i + 1) % n_pts
            b.add_triangle(tip, k_ring2[ni], k_ring2[i])

    return b


# ---------------------------------------------------------------------------
# 4. CHUNKY WOODEN CRATE
# ---------------------------------------------------------------------------
def build_crate():
    b = ObjBuilder("primitive_crate")
    b.set_material("mat_wood")

    # Chunky box (0.9m x 0.9m x 0.9m)
    s = 0.45
    # 8 main corner vertices
    v1 = b.add_vertex(-s, 0.0,   -s)
    v2 = b.add_vertex( s, 0.0,   -s)
    v3 = b.add_vertex( s, s*2.0, -s)
    v4 = b.add_vertex(-s, s*2.0, -s)

    v5 = b.add_vertex(-s, 0.0,    s)
    v6 = b.add_vertex( s, 0.0,    s)
    v7 = b.add_vertex( s, s*2.0,  s)
    v8 = b.add_vertex(-s, s*2.0,  s)

    # 6 box faces (all outward CCW normals)
    b.add_quad(v1, v4, v3, v2) # Front (-Z)
    b.add_quad(v6, v7, v8, v5) # Back (+Z)
    b.add_quad(v5, v8, v4, v1) # Left (-X)
    b.add_quad(v2, v3, v7, v6) # Right (+X)
    b.add_quad(v4, v8, v7, v3) # Top (+Y)
    b.add_quad(v1, v2, v6, v5) # Bottom (-Y)

    # Leather/iron strap bindings around middle
    b.set_material("mat_clothing")
    strap_y1 = s * 0.8
    strap_y2 = s * 1.2
    st = s + 0.015

    s1 = b.add_vertex(-st, strap_y1, -st)
    s2 = b.add_vertex( st, strap_y1, -st)
    s3 = b.add_vertex( st, strap_y2, -st)
    s4 = b.add_vertex(-st, strap_y2, -st)

    s5 = b.add_vertex(-st, strap_y1,  st)
    s6 = b.add_vertex( st, strap_y1,  st)
    s7 = b.add_vertex( st, strap_y2,  st)
    s8 = b.add_vertex(-st, strap_y2,  st)

    b.add_quad(s1, s4, s3, s2)
    b.add_quad(s6, s7, s8, s5)
    b.add_quad(s5, s8, s4, s1)
    b.add_quad(s2, s3, s7, s6)

    return b


# ---------------------------------------------------------------------------
# 5. CHUNKY BOULDER / ROCK
# ---------------------------------------------------------------------------
def build_boulder():
    b = ObjBuilder("boulder")
    b.set_material("mat_stone")

    layer_data = [
        (0.00, 0.80, 0.0),
        (0.40, 1.15, 0.3),
        (0.85, 1.05, -0.2),
        (1.30, 0.65, 0.4),
    ]

    rings = []
    n_pts = 6
    radii_factors = [
        [0.9, 1.1, 0.85, 1.05, 0.95, 1.15],
        [1.15, 0.95, 1.2, 0.9, 1.1, 1.0],
        [0.85, 1.1, 0.95, 1.2, 0.9, 1.05],
        [1.0, 0.85, 1.15, 0.95, 1.1, 0.9],
    ]

    for l_idx, (y, base_r, rot) in enumerate(layer_data):
        ring = []
        for i in range(n_pts):
            ang = rot + i * (2.0 * math.pi / n_pts)
            r = base_r * radii_factors[l_idx][i]
            ring.append(b.add_vertex(math.cos(ang) * r, y, math.sin(ang) * r))
        rings.append(ring)

    b.add_cylinder(rings)

    # Bottom cap (pointing -Y down)
    b_center = b.add_vertex(0.0, -0.05, 0.0)
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(b_center, rings[0][i], rings[0][ni])

    # Top cap (pointing +Y up)
    t_center = b.add_vertex(0.05, 1.55, -0.05)
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(t_center, rings[-1][ni], rings[-1][i])

    return b


# ---------------------------------------------------------------------------
# 6. WOODEN BARREL
# ---------------------------------------------------------------------------
def build_barrel():
    b = ObjBuilder("primitive_barrel")
    b.set_material("mat_wood")

    segs = [
        (0.00, 0.40),
        (0.25, 0.48),
        (0.55, 0.52),
        (0.85, 0.48),
        (1.10, 0.40),
    ]

    rings = []
    n_pts = 8
    for y, r in segs:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring.append(b.add_vertex(math.cos(ang) * r, y, math.sin(ang) * r))
        rings.append(ring)

    b.add_cylinder(rings)

    # Caps (bottom -Y down, top +Y up)
    bot_c = b.add_vertex(0, 0, 0)
    top_c = b.add_vertex(0, 1.10, 0)
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(bot_c, rings[0][i], rings[0][ni])
        b.add_triangle(top_c, rings[-1][ni], rings[-1][i])

    # 2 metal hoops
    b.set_material("mat_stone")
    for hoop_y in [0.25, 0.85]:
        h_r1 = []
        h_r2 = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            vx = math.cos(ang) * 0.49
            vz = math.sin(ang) * 0.49
            h_r1.append(b.add_vertex(vx, hoop_y - 0.03, vz))
            h_r2.append(b.add_vertex(vx, hoop_y + 0.03, vz))
        b.add_cylinder([h_r1, h_r2])

    return b


if __name__ == "__main__":
    out_dir = r"d:\Godot\troll\assets\models\camp"
    os.makedirs(out_dir, exist_ok=True)

    mtl_path = os.path.join(out_dir, "camp_props.mtl")
    with open(mtl_path, "w", encoding="utf-8") as f:
        f.write("# Materials for Low-Poly Prehistoric Camp\n\n")
        f.write("newmtl mat_wood\nKd 0.44 0.28 0.16\nKs 0.05 0.05 0.05\nNs 5.0\n\n")
        f.write("newmtl mat_stone\nKd 0.35 0.36 0.38\nKs 0.10 0.10 0.10\nNs 10.0\n\n")
        f.write("newmtl mat_clothing\nKd 0.65 0.45 0.25\nKs 0.05 0.05 0.05\nNs 5.0\n\n")
        f.write("newmtl mat_hair\nKd 0.25 0.65 0.20\nKs 0.05 0.05 0.05\nNs 5.0\n\n")
        f.write("newmtl mat_accent\nKd 0.90 0.86 0.76\nKs 0.15 0.15 0.15\nNs 15.0\n\n")

    props = {
        "palm_tree.obj": build_palm_tree(),
        "primitive_hut.obj": build_primitive_hut(),
        "mammoth_bone.obj": build_mammoth_bone(),
        "primitive_crate.obj": build_crate(),
        "boulder.obj": build_boulder(),
        "primitive_barrel.obj": build_barrel(),
    }

    for fname, model in props.items():
        p = os.path.join(out_dir, fname)
        model.write_obj(p, "camp_props.mtl")
        print("Generated %s (vertices: %d, faces: %d)" % (fname, len(model.vertices), len(model.faces)))
