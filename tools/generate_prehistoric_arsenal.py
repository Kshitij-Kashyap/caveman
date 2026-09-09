import os
import math

class ObjBuilder:
    def __init__(self, name="model", offset=(0.0, 0.0, 0.0)):
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

    def add_cylinder_section(self, rings):
        num_rings = len(rings)
        if num_rings < 2:
            return
        n_per_ring = len(rings[0])
        for r in range(num_rings - 1):
            r1 = rings[r]
            r2 = rings[r + 1]
            for i in range(n_per_ring):
                ni = (i + 1) % n_per_ring
                self.add_quad(r1[i], r2[i], r2[ni], r1[ni])

    def write_obj(self, filepath, mtl_filename):
        mat_groups = {}
        for mat, f_verts in self.faces:
            if mat not in mat_groups:
                mat_groups[mat] = []
            mat_groups[mat].append(f_verts)

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"# Prehistoric Asset: {self.name}\n")
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
# 1. ANCIENT STONE WHEEL / STONE RING (CURRENCY)
# ---------------------------------------------------------------------------
def build_stone_wheel():
    b = ObjBuilder("stone_wheel")
    b.set_material("mat_stone")

    n_segs = 12
    r_outer = 0.35
    r_inner = 0.12
    half_h = 0.07

    # Slight hand-chiseled irregularities
    chisel_offsets = [0.015, -0.012, 0.008, -0.018, 0.012, -0.010, 0.016, -0.014, 0.010, -0.015, 0.013, -0.011]

    # Rings:
    # Outer top, Outer bottom, Inner top, Inner bottom
    outer_top = []
    outer_bot = []
    inner_top = []
    inner_bot = []

    for i in range(n_segs):
        ang = i * (2.0 * math.pi / n_segs)
        co = chisel_offsets[i]
        ro = r_outer + co
        ri = r_inner + co * 0.5
        cos_a = math.cos(ang)
        sin_a = math.sin(ang)

        outer_top.append(b.add_vertex(cos_a * ro, half_h, sin_a * ro))
        outer_bot.append(b.add_vertex(cos_a * ro, -half_h, sin_a * ro))
        inner_top.append(b.add_vertex(cos_a * ri, half_h, sin_a * ri))
        inner_bot.append(b.add_vertex(cos_a * ri, -half_h, sin_a * ri))

    for i in range(n_segs):
        ni = (i + 1) % n_segs
        # Outer rim quads (CCW outward)
        b.add_quad(outer_bot[i], outer_top[i], outer_top[ni], outer_bot[ni])
        # Inner hole rim quads (CCW facing inward hole)
        b.add_quad(inner_bot[ni], inner_top[ni], inner_top[i], inner_bot[i])
        # Top annular face (CCW pointing +Y up)
        b.add_quad(inner_top[i], inner_top[ni], outer_top[ni], outer_top[i])
        # Bottom annular face (CCW pointing -Y down)
        b.add_quad(outer_bot[i], outer_bot[ni], inner_bot[ni], inner_bot[i])

    return b


# ---------------------------------------------------------------------------
# 2. PREHISTORIC FLINT SPEAR
# ---------------------------------------------------------------------------
def build_spear():
    b = ObjBuilder("tool_spear")

    # A. Wooden Shaft (from y = -1.0 to y = 0.52)
    b.set_material("mat_wood")
    shaft_segs = [
        (-1.00, 0.022),
        (-0.60, 0.024),
        (-0.10, 0.025),
        (0.30, 0.024),
        (0.52, 0.021)
    ]
    rings = []
    n_pts = 6
    for y, r in shaft_segs:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring.append(b.add_vertex(math.cos(ang) * r, y, math.sin(ang) * r))
        rings.append(ring)
    b.add_cylinder_section(rings)

    # Cap bottom of shaft (-Y down)
    bot_center = b.add_vertex(0.0, -1.02, 0.0)
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(bot_center, rings[0][i], rings[0][ni])

    # B. Leather / Sinew Binding (socket wrap, y = 0.46 to 0.56)
    b.set_material("mat_clothing")
    wrap_rings = []
    for y in [0.46, 0.51, 0.56]:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            r = 0.028
            ring.append(b.add_vertex(math.cos(ang) * r, y, math.sin(ang) * r))
        wrap_rings.append(ring)
    b.add_cylinder_section(wrap_rings)

    # C. Knapped Flint / Obsidian Spearhead (y = 0.54 to 0.88)
    b.set_material("mat_stone")
    # Spear blade cross-sections: wide in X, thin in Z
    blade_segs = [
        # (y, half_width_x, half_thick_z)
        (0.54, 0.028, 0.014),
        (0.64, 0.048, 0.016),
        (0.74, 0.038, 0.012),
        (0.82, 0.020, 0.008),
    ]

    b_rings = []
    for y, wx, tz in blade_segs:
        # Diamond cross-section (4 points: Right, Back, Left, Front)
        p_right = b.add_vertex(wx, y, 0.0)
        p_back  = b.add_vertex(0.0, y, -tz)
        p_left  = b.add_vertex(-wx, y, 0.0)
        p_front = b.add_vertex(0.0, y, tz)
        b_rings.append([p_right, p_back, p_left, p_front])

    # Connect blade rings (CCW outward)
    for r in range(len(b_rings) - 1):
        r1 = b_rings[r]
        r2 = b_rings[r + 1]
        for i in range(4):
            ni = (i + 1) % 4
            b.add_quad(r1[i], r2[i], r2[ni], r1[ni])

    # Tip point
    tip = b.add_vertex(0.0, 0.88, 0.0)
    top_ring = b_rings[-1]
    for i in range(4):
        ni = (i + 1) % 4
        b.add_triangle(tip, top_ring[i], top_ring[ni])

    return b


# ---------------------------------------------------------------------------
# 3. PREHISTORIC STONE CLUB
# ---------------------------------------------------------------------------
def build_club():
    b = ObjBuilder("tool_club")

    # A. Knotty Wood Handle (y = -0.45 to y = 0.05)
    b.set_material("mat_wood")
    handle_segs = [
        (-0.45, 0.032, 0.0),
        (-0.25, 0.034, 0.005),
        (-0.05, 0.038, 0.012),
        (0.08,  0.055, 0.022),
        (0.20,  0.078, 0.035),
        (0.32,  0.085, 0.040),
        (0.40,  0.065, 0.035)
    ]
    rings = []
    n_pts = 6
    for y, r, ox in handle_segs:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring.append(b.add_vertex(ox + math.cos(ang) * r, y, math.sin(ang) * r))
        rings.append(ring)
    b.add_cylinder_section(rings)

    # Cap bottom & top (-Y down, +Y up)
    bot_center = b.add_vertex(0.0, -0.47, 0.0)
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(bot_center, rings[0][i], rings[0][ni])

    top_center = b.add_vertex(0.04, 0.42, 0.0)
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(top_center, rings[-1][ni], rings[-1][i])

    # B. Embedded Stone Tooth on striking face
    b.set_material("mat_stone")
    st_base1 = b.add_vertex(0.10, 0.28, 0.03)
    st_base2 = b.add_vertex(0.10, 0.28, -0.03)
    st_base3 = b.add_vertex(0.10, 0.18, -0.025)
    st_base4 = b.add_vertex(0.10, 0.18, 0.025)
    st_point = b.add_vertex(0.18, 0.23, 0.0)

    b.add_quad(st_base4, st_base3, st_base2, st_base1)
    b.add_triangle(st_base1, st_base2, st_point)
    b.add_triangle(st_base2, st_base3, st_point)
    b.add_triangle(st_base3, st_base4, st_point)
    b.add_triangle(st_base4, st_base1, st_point)

    # C. Leather Grip Wrap
    b.set_material("mat_clothing")
    wrap_rings = []
    for wy in [-0.35, -0.20, -0.05]:
        w_ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            wr = 0.038
            w_ring.append(b.add_vertex(math.cos(ang) * wr, wy, math.sin(ang) * wr))
        wrap_rings.append(w_ring)
    b.add_cylinder_section(wrap_rings)

    return b


# ---------------------------------------------------------------------------
# 4. PREHISTORIC FIRE TORCH
# ---------------------------------------------------------------------------
def build_torch():
    b = ObjBuilder("tool_torch")

    # A. Weathered Wooden Branch Handle (y = -0.45 to y = 0.12)
    b.set_material("mat_wood")
    handle_segs = [
        (-0.45, 0.024),
        (-0.25, 0.026),
        (-0.05, 0.028),
        ( 0.12, 0.032)
    ]
    rings = []
    n_pts = 6
    for y, r in handle_segs:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring.append(b.add_vertex(math.cos(ang) * r, y, math.sin(ang) * r))
        rings.append(ring)
    b.add_cylinder_section(rings)

    # Bottom cap (-Y down)
    bot_center = b.add_vertex(0.0, -0.47, 0.0)
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(bot_center, rings[0][i], rings[0][ni])

    # B. Bound Grass & Pitch Bundle Head (y = 0.10 to y = 0.30)
    b.set_material("mat_clothing")
    head_segs = [
        (0.10, 0.038),
        (0.18, 0.062),
        (0.26, 0.058),
        (0.32, 0.048)
    ]
    h_rings = []
    for y, r in head_segs:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring.append(b.add_vertex(math.cos(ang) * r, y, math.sin(ang) * r))
        h_rings.append(ring)
    b.add_cylinder_section(h_rings)

    # C. Glowing Ember / Fire Flame Mesh on top (y = 0.28 to y = 0.46)
    b.set_material("mat_fire")
    f_rings = []
    flame_segs = [
        (0.28, 0.042),
        (0.36, 0.052),
        (0.42, 0.032)
    ]
    for y, r in flame_segs:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring.append(b.add_vertex(math.cos(ang) * r, y, math.sin(ang) * r))
        f_rings.append(ring)
    b.add_cylinder_section(f_rings)

    # Flame tip
    flame_tip = b.add_vertex(0.0, 0.48, 0.0)
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(flame_tip, f_rings[-1][i], f_rings[-1][ni])

    return b

# ---------------------------------------------------------------------------
# 5. PREHISTORIC STONE AXE (CHOPPER & WEAPON)
# ---------------------------------------------------------------------------
def build_axe():
    b = ObjBuilder("tool_axe")

    # A. Wooden Handle (y = -0.36 to y = 0.26)
    b.set_material("mat_wood")
    handle_segs = [
        (-0.36, 0.026, 0.000, -0.012),
        (-0.33, 0.022, 0.000, -0.008),
        (-0.24, 0.019, 0.002, -0.004),
        (-0.10, 0.018, 0.002,  0.000),
        ( 0.06, 0.019, 0.001,  0.005),
        ( 0.16, 0.021, 0.000,  0.009),
        ( 0.22, 0.023, -0.001, 0.012),
        ( 0.26, 0.020, -0.002, 0.012),
    ]
    rings = []
    n_pts = 6
    for y, r, ox, oz in handle_segs:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            vx = ox + math.cos(ang) * r
            vz = oz + math.sin(ang) * r
            ring.append(b.add_vertex(vx, y, vz))
        rings.append(ring)
    b.add_cylinder_section(rings)

    # Cap handle bottom & top (-Y down, +Y up)
    bot_center = b.add_vertex(handle_segs[0][2], handle_segs[0][0] - 0.01, handle_segs[0][3])
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(bot_center, rings[0][i], rings[0][ni])

    top_center = b.add_vertex(handle_segs[-1][2], handle_segs[-1][0] + 0.01, handle_segs[-1][3])
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(top_center, rings[-1][ni], rings[-1][i])

    # B. Flaked Flint / Chipped Stone Axe Blade
    # Stretches along Z: +Z is poll/butt hammer, -Z is wide crescent chopping edge
    b.set_material("mat_stone")
    # Diamond/faceted profile: (z, x_half, y_top, y_bot)
    blade_sections = [
        # (z, x_half, y_top, y_bot)
        ( 0.08, 0.024, 0.240, 0.160), # Blunt poll butt
        ( 0.04, 0.030, 0.250, 0.150), # Back socket
        (-0.02, 0.032, 0.260, 0.140), # Mid shaft socket
        (-0.08, 0.022, 0.275, 0.125), # Expanding neck
        (-0.14, 0.012, 0.295, 0.105), # Blade flare
        (-0.19, 0.003, 0.315, 0.085), # Sharp crescent cutting edge
    ]
    b_rings = []
    for z, xh, yt, yb in blade_sections:
        ym = (yt + yb) * 0.5
        v_top = b.add_vertex( 0.0, yt, z)
        v_rit = b.add_vertex(  xh, ym, z)
        v_bot = b.add_vertex( 0.0, yb, z)
        v_lft = b.add_vertex( -xh, ym, z)
        b_rings.append([v_top, v_rit, v_bot, v_lft])
    b.add_cylinder_section(b_rings)

    # Cap blade butt (+Z)
    back_center = b.add_vertex(0.0, (blade_sections[0][2] + blade_sections[0][3]) * 0.5, blade_sections[0][0] + 0.01)
    b.add_triangle(back_center, b_rings[0][0], b_rings[0][1])
    b.add_triangle(back_center, b_rings[0][1], b_rings[0][2])
    b.add_triangle(back_center, b_rings[0][2], b_rings[0][3])
    b.add_triangle(back_center, b_rings[0][3], b_rings[0][0])

    # Cap sharp cutting edge (-Z)
    edge_center = b.add_vertex(0.0, (blade_sections[-1][2] + blade_sections[-1][3]) * 0.5, blade_sections[-1][0] - 0.01)
    b.add_triangle(edge_center, b_rings[-1][1], b_rings[-1][0])
    b.add_triangle(edge_center, b_rings[-1][2], b_rings[-1][1])
    b.add_triangle(edge_center, b_rings[-1][3], b_rings[-1][2])
    b.add_triangle(edge_center, b_rings[-1][0], b_rings[-1][3])

    # C. Sinew / Leather Cord Binding at Haft & Stone Junction
    b.set_material("mat_clothing")
    wrap_rings = []
    for wy in [0.17, 0.20, 0.23]:
        w_ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            wr = 0.036
            w_ring.append(b.add_vertex(math.cos(ang) * wr, wy, math.sin(ang) * wr))
        wrap_rings.append(w_ring)
    b.add_cylinder_section(wrap_rings)

    return b


def main():

    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    char_dir = os.path.join(root_dir, "assets", "models", "character")
    item_dir = os.path.join(root_dir, "assets", "models", "items")
    os.makedirs(char_dir, exist_ok=True)
    os.makedirs(item_dir, exist_ok=True)

    # Update/create materials file for items & weapons
    items_mtl = os.path.join(item_dir, "items.mtl")
    with open(items_mtl, "w", encoding="utf-8") as f:
        f.write("# Materials for Prehistoric Items\n")
        f.write("newmtl mat_stone\nKd 0.48 0.46 0.44\nKs 0.08 0.08 0.08\nNs 10.0\n\n")
        f.write("newmtl mat_wood\nKd 0.45 0.28 0.16\nKs 0.05 0.05 0.05\nNs 5.0\n\n")

    char_mtl = os.path.join(char_dir, "tools.mtl")
    with open(char_mtl, "w", encoding="utf-8") as f:
        f.write("# Materials for Prehistoric Tools & Weapons\n")
        f.write("newmtl mat_wood\nKd 0.44 0.28 0.16\nKs 0.05 0.05 0.05\nNs 5.0\n\n")
        f.write("newmtl mat_stone\nKd 0.24 0.26 0.28\nKs 0.15 0.15 0.15\nNs 15.0\n\n")
        f.write("newmtl mat_clothing\nKd 0.55 0.36 0.22\nKs 0.05 0.05 0.05\nNs 5.0\n\n")
        f.write("newmtl mat_fire\nKd 1.0 0.45 0.1\nKs 0.2 0.2 0.2\nNs 20.0\n\n")

    # Build and write models
    # 1. Stone Wheel
    sw = build_stone_wheel()
    sw_path = os.path.join(item_dir, "stone_wheel.obj")
    sw.write_obj(sw_path, "items.mtl")
    print(f"Generated stone_wheel.obj ({len(sw.vertices)} verts, {len(sw.faces)} faces)")

    # 2. Spear
    spear = build_spear()
    spear_path = os.path.join(char_dir, "tool_spear.obj")
    spear.write_obj(spear_path, "tools.mtl")
    print(f"Generated tool_spear.obj ({len(spear.vertices)} verts, {len(spear.faces)} faces)")

    # 3. Club
    club = build_club()
    club_path = os.path.join(char_dir, "tool_club.obj")
    club.write_obj(club_path, "tools.mtl")
    print(f"Generated tool_club.obj ({len(club.vertices)} verts, {len(club.faces)} faces)")

    # 4. Torch
    torch = build_torch()
    torch_path = os.path.join(char_dir, "tool_torch.obj")
    torch.write_obj(torch_path, "tools.mtl")
    print(f"Generated tool_torch.obj ({len(torch.vertices)} verts, {len(torch.faces)} faces)")

    # 5. Stone Axe (Woodchopping / Combat)
    axe = build_axe()
    axe_path = os.path.join(char_dir, "tool_axe.obj")
    axe.write_obj(axe_path, "tools.mtl")
    print(f"Generated tool_axe.obj ({len(axe.vertices)} verts, {len(axe.faces)} faces)")

if __name__ == "__main__":
    main()

