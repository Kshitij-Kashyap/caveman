import os
import math

class ObjBuilder:
    def __init__(self, name="model"):
        self.name = name
        self.vertices = []
        self.normals = []
        self.faces = []
        self.current_mat = "mat_bone"

    def set_material(self, mat_name):
        self.current_mat = mat_name

    def add_vertex(self, x, y, z):
        self.vertices.append((round(x, 4), round(y, 4), round(z, 4)))
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

    def add_pyramid_spike(self, base_center, tip, width=0.02, height_offset=(0,0,0)):
        # base_center: (x, y, z)
        # tip: (x, y, z)
        # construct 4 base vertices perpendicular to tip direction
        bx, by, bz = base_center
        tx, ty, tz = tip
        dx, dy, dz = tx - bx, ty - by, tz - bz
        d_len = math.sqrt(dx*dx + dy*dy + dz*dz)
        if d_len < 0.0001:
            dx, dy, dz = 1.0, 0.0, 0.0
        else:
            dx, dy, dz = dx/d_len, dy/d_len, dz/d_len

        # Up vector approx
        ux, uy, uz = 0.0, 1.0, 0.0
        if abs(dy) > 0.9:
            ux, uy, uz = 1.0, 0.0, 0.0

        # right = dir x up
        rx = dy * uz - dz * uy
        ry = dz * ux - dx * uz
        rz = dx * uy - dy * ux
        r_len = math.sqrt(rx*rx + ry*ry + rz*rz)
        rx, ry, rz = rx/r_len, ry/r_len, rz/r_len

        # real up = right x dir
        ux = ry * dz - rz * dy
        uy = rz * dx - rx * dz
        uz = rx * dy - ry * dx

        hw = width * 0.5
        b1 = self.add_vertex(bx + rx*hw + ux*hw, by + ry*hw + uy*hw, bz + rz*hw + uz*hw)
        b2 = self.add_vertex(bx - rx*hw + ux*hw, by - ry*hw + uy*hw, bz - rz*hw + uz*hw)
        b3 = self.add_vertex(bx - rx*hw - ux*hw, by - ry*hw - uy*hw, bz - rz*hw - uz*hw)
        b4 = self.add_vertex(bx + rx*hw - ux*hw, by + ry*hw - uy*hw, bz + rz*hw - uz*hw)
        t = self.add_vertex(tx, ty, tz)

        # Base
        self.add_quad(b4, b3, b2, b1)
        # 4 faces
        self.add_triangle(b1, b2, t)
        self.add_triangle(b2, b3, t)
        self.add_triangle(b3, b4, t)
        self.add_triangle(b4, b1, t)

    def write_obj(self, filepath):
        mat_groups = {}
        for mat, f_verts in self.faces:
            if mat not in mat_groups:
                mat_groups[mat] = []
            mat_groups[mat].append(f_verts)

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"# Prehistoric Weapon Attachment: {self.name}\n")
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
# Tier 2: Spiked Bone Club Attachments
# ---------------------------------------------------------------------------
def build_tier2_attachments():
    b = ObjBuilder("club_attachments_tier2")
    b.set_material("mat_bone")

    # Spikes around the club head (head center ~ (0.035, y, 0.0), radius ~0.08)
    spikes_def = [
        # (base_center, tip, width)
        ((-0.045, 0.22, 0.0),     (-0.115, 0.25, 0.0),    0.024),  # Back-facing spike
        ((-0.040, 0.32, 0.0),     (-0.110, 0.36, 0.0),    0.022),  # Upper back spike
        ((0.035,  0.24, 0.082),   (0.045,  0.27, 0.145),  0.022),  # +Z lateral spike
        ((0.035,  0.31, 0.078),   (0.042,  0.36, 0.138),  0.020),  # +Z upper spike
        ((0.035,  0.24, -0.082),  (0.045,  0.27, -0.145), 0.022),  # -Z lateral spike
        ((0.035,  0.31, -0.078),  (0.042,  0.36, -0.138), 0.020),  # -Z upper spike
        ((0.035,  0.41, 0.0),     (0.040,  0.48, 0.0),    0.026),  # Top crown bone spike
    ]

    for base_c, tip_p, w in spikes_def:
        b.add_pyramid_spike(base_c, tip_p, width=w)

    # Leather cross-cord wrap along upper handle (y = -0.12 to y = 0.06)
    b.set_material("mat_clothing")
    n_pts = 6
    for y_center in [-0.10, -0.02, 0.05]:
        r = 0.041
        ox = 0.010
        ring_top = []
        ring_bot = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            ring_top.append(b.add_vertex(ox + math.cos(ang) * (r + 0.003), y_center + 0.015, math.sin(ang) * (r + 0.003)))
            ring_bot.append(b.add_vertex(ox + math.cos(ang) * (r + 0.003), y_center - 0.015, math.sin(ang) * (r + 0.003)))
        for i in range(n_pts):
            ni = (i + 1) % n_pts
            b.add_quad(ring_top[i], ring_top[ni], ring_bot[ni], ring_bot[i])

    return b


# ---------------------------------------------------------------------------
# Tier 3: Obsidian Macuahuitl Attachments
# ---------------------------------------------------------------------------
def build_tier3_attachments():
    b = ObjBuilder("club_attachments_tier3")
    b.set_material("mat_obsidian")

    # Double-row obsidian glass cleaver blades along +Z and -Z flanks
    # Each blade is a trapezoidal facet with a razor blade edge
    flank_y = [0.14, 0.20, 0.26, 0.32, 0.38]
    for y in flank_y:
        # +Z side blade
        # Base embedded in wood, edge extending out
        b1 = b.add_vertex(0.015, y - 0.022, 0.076)
        b2 = b.add_vertex(0.055, y - 0.022, 0.076)
        b3 = b.add_vertex(0.055, y + 0.022, 0.076)
        b4 = b.add_vertex(0.015, y + 0.022, 0.076)
        # Razor tip
        t1 = b.add_vertex(0.025, y - 0.016, 0.138)
        t2 = b.add_vertex(0.045, y + 0.016, 0.138)

        b.add_quad(b1, b2, t2, t1)
        b.add_quad(b2, b3, t2, t2)
        b.add_quad(b3, b4, t1, t2)
        b.add_quad(b4, b1, t1, t1)
        b.add_triangle(t1, t2, b2)

        # -Z side blade
        z1 = b.add_vertex(0.015, y - 0.022, -0.076)
        z2 = b.add_vertex(0.055, y - 0.022, -0.076)
        z3 = b.add_vertex(0.055, y + 0.022, -0.076)
        z4 = b.add_vertex(0.015, y + 0.022, -0.076)
        zt1 = b.add_vertex(0.025, y - 0.016, -0.138)
        zt2 = b.add_vertex(0.045, y + 0.016, -0.138)

        b.add_quad(z2, z1, zt1, zt2)
        b.add_quad(z3, z2, zt2, zt2)
        b.add_quad(z4, z3, zt2, zt1)
        b.add_quad(z1, z4, zt1, zt1)
        b.add_triangle(zt2, zt1, z2)

    # Top crown obsidian spike
    b.add_pyramid_spike((0.035, 0.41, 0.0), (0.042, 0.50, 0.0), width=0.032)

    # Dark sinew reinforcement bands around the socket grooves
    b.set_material("mat_clothing")
    for band_y in [0.11, 0.40]:
        n_pts = 8
        r = 0.072 if band_y < 0.2 else 0.068
        ox = 0.025 if band_y < 0.2 else 0.038
        b_top = []
        b_bot = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            b_top.append(b.add_vertex(ox + math.cos(ang) * (r + 0.004), band_y + 0.012, math.sin(ang) * (r + 0.004)))
            b_bot.append(b.add_vertex(ox + math.cos(ang) * (r + 0.004), band_y - 0.012, math.sin(ang) * (r + 0.004)))
        for i in range(n_pts):
            ni = (i + 1) % n_pts
            b.add_quad(b_top[i], b_top[ni], b_bot[ni], b_bot[i])

    return b


# ---------------------------------------------------------------------------
# Tier 4: Chieftain Volcanic Totem Attachments
# ---------------------------------------------------------------------------
def build_tier4_attachments():
    b = ObjBuilder("club_attachments_tier4")

    # Mammoth Ivory Bands (Upper & Lower Head)
    b.set_material("mat_bone")
    for collar_y, r, ox, h in [(0.12, 0.068, 0.026, 0.035), (0.36, 0.082, 0.038, 0.040)]:
        n_pts = 10
        c_top = []
        c_bot = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            # slight carved bevel
            c_top.append(b.add_vertex(ox + math.cos(ang) * (r + 0.008), collar_y + h*0.5, math.sin(ang) * (r + 0.008)))
            c_bot.append(b.add_vertex(ox + math.cos(ang) * (r + 0.008), collar_y - h*0.5, math.sin(ang) * (r + 0.008)))
        for i in range(n_pts):
            ni = (i + 1) % n_pts
            b.add_quad(c_top[i], c_top[ni], c_bot[ni], c_bot[i])

    # Volcanic Magma Spikes (Glowing Ember Teeth)
    b.set_material("mat_volcanic")
    volcanic_spikes = [
        # Large front volcanic tooth on striking face
        ((0.10, 0.23, 0.0),     (0.24, 0.23, 0.0),    0.040),
        # Lateral magma fangs
        ((0.035, 0.28, 0.085),  (0.050, 0.31, 0.165), 0.030),
        ((0.035, 0.28, -0.085), (0.050, 0.31, -0.165),0.030),
        # Crown volcanic monolith spike
        ((0.038, 0.41, 0.0),    (0.045, 0.54, 0.0),   0.038),
        # Back counter-spikes
        ((-0.045, 0.28, 0.0),   (-0.130, 0.31, 0.0),  0.032),
    ]

    for base_c, tip_p, w in volcanic_spikes:
        b.add_pyramid_spike(base_c, tip_p, width=w)

    return b


def main():
    out_dir = "d:/Godot/troll/assets/models/character"
    os.makedirs(out_dir, exist_ok=True)

    t2 = build_tier2_attachments()
    p2 = os.path.join(out_dir, "club_attachments_tier2.obj")
    t2.write_obj(p2)
    print(f"Generated: {p2} (verts: {len(t2.vertices)}, faces: {len(t2.faces)})")

    t3 = build_tier3_attachments()
    p3 = os.path.join(out_dir, "club_attachments_tier3.obj")
    t3.write_obj(p3)
    print(f"Generated: {p3} (verts: {len(t3.vertices)}, faces: {len(t3.faces)})")

    t4 = build_tier4_attachments()
    p4 = os.path.join(out_dir, "club_attachments_tier4.obj")
    t4.write_obj(p4)
    print(f"Generated: {p4} (verts: {len(t4.vertices)}, faces: {len(t4.faces)})")

if __name__ == "__main__":
    main()
