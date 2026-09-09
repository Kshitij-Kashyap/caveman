import os
import math

class ObjMeshBuilder:
    def __init__(self, name="mesh", offset=(0.0, 0.0, 0.0)):
        self.name = name
        self.offset = offset
        self.vertices = []
        self.normals = []
        self.faces = [] # (material, [(v_idx, n_idx), ...])
        self.current_mat = "mat_skin"

    def set_material(self, mat_name):
        self.current_mat = mat_name

    def add_vertex(self, x, y, z):
        ox, oy, oz = self.offset
        self.vertices.append((round(x - ox, 4), round(y - oy, 4), round(z - oz, 4)))
        return len(self.vertices) # 1-based index

    def add_normal(self, nx, ny, nz):
        length = math.sqrt(nx*nx + ny*ny + nz*nz)
        if length > 0.00001:
            nx, ny, nz = nx/length, ny/length, nz/length
        else:
            nx, ny, nz = 0.0, 1.0, 0.0
        self.normals.append((round(nx, 4), round(ny, 4), round(nz, 4)))
        return len(self.normals)

    def add_triangle(self, v1, v2, v3, norm=None):
        if norm is None:
            # Compute face normal for flat shading
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

    def add_quad(self, v1, v2, v3, v4, norm=None):
        self.add_triangle(v1, v2, v3, norm)
        self.add_triangle(v1, v3, v4, norm)

    def write_obj(self, filepath, mtl_filename="caveman.mtl"):
        # Group faces by material so each material produces exactly one surface
        mat_groups = {}
        for mat, f_verts in self.faces:
            if mat not in mat_groups:
                mat_groups[mat] = []
            mat_groups[mat].append(f_verts)

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"# How to Fish Style Low-Poly Caveman\n")
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
                for f_verts in f_list:
                    f_str = " ".join([f"{v}//{n}" for v, n in f_verts])
                    f.write(f"f {f_str}\n")


def build_faceted_sphere(builder, center, radius, rings=4, sectors=6, mat=None):
    """Generates a low-poly faceted polyhedron sphere."""
    if mat:
        builder.set_material(mat)
    cx, cy, cz = center
    vertex_grid = []

    # North pole
    p_top = builder.add_vertex(cx, cy + radius, cz)

    for r in range(1, rings):
        phi = math.pi * r / rings
        ring_v = []
        for s in range(sectors):
            theta = 2.0 * math.pi * s / sectors
            x = cx + radius * math.sin(phi) * math.sin(theta)
            y = cy + radius * math.cos(phi)
            z = cz + radius * math.sin(phi) * math.cos(theta)
            ring_v.append(builder.add_vertex(x, y, z))
        vertex_grid.append(ring_v)

    # South pole
    p_bot = builder.add_vertex(cx, cy - radius, cz)

    # Top cap
    for s in range(sectors):
        v1 = p_top
        v2 = vertex_grid[0][s]
        v3 = vertex_grid[0][(s + 1) % sectors]
        builder.add_triangle(v1, v2, v3)

    # Middle quads
    for r in range(len(vertex_grid) - 1):
        for s in range(sectors):
            v1 = vertex_grid[r][s]
            v2 = vertex_grid[r + 1][s]
            v3 = vertex_grid[r + 1][(s + 1) % sectors]
            v4 = vertex_grid[r][(s + 1) % sectors]
            builder.add_quad(v1, v2, v3, v4)

    # Bottom cap
    for s in range(sectors):
        v1 = vertex_grid[-1][(s + 1) % sectors]
        v2 = vertex_grid[-1][s]
        v3 = p_bot
        builder.add_triangle(v1, v2, v3)


def build_faceted_cylinder(builder, p_start, p_end, r_start, r_end, sides=6, mat=None):
    """Generates a faceted low-poly tapered prism/cylinder with flat caps."""
    if mat:
        builder.set_material(mat)
    x1, y1, z1 = p_start
    x2, y2, z2 = p_end
    dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
    length = math.sqrt(dx*dx + dy*dy + dz*dz)
    if length < 0.0001:
        return

    # Create local orthogonal basis
    up = (0.0, 1.0, 0.0)
    if abs(dy / length) > 0.95:
        up = (0.0, 0.0, 1.0)
    fwd = (dx / length, dy / length, dz / length)
    right = (up[1]*fwd[2] - up[2]*fwd[1], up[2]*fwd[0] - up[0]*fwd[2], up[0]*fwd[1] - up[1]*fwd[0])
    rlen = math.sqrt(right[0]**2 + right[1]**2 + right[2]**2)
    right = (right[0]/rlen, right[1]/rlen, right[2]/rlen)
    up = (fwd[1]*right[2] - fwd[2]*right[1], fwd[2]*right[0] - fwd[0]*right[2], fwd[0]*right[1] - fwd[1]*right[0])

    ring1 = []
    ring2 = []
    for i in range(sides):
        angle = 2.0 * math.pi * i / sides
        c = math.cos(angle)
        s = math.sin(angle)

        px1 = x1 + r_start * (c * right[0] + s * up[0])
        py1 = y1 + r_start * (c * right[1] + s * up[1])
        pz1 = z1 + r_start * (c * right[2] + s * up[2])
        ring1.append(builder.add_vertex(px1, py1, pz1))

        px2 = x2 + r_end * (c * right[0] + s * up[0])
        py2 = y2 + r_end * (c * right[1] + s * up[1])
        pz2 = z2 + r_end * (c * right[2] + s * up[2])
        ring2.append(builder.add_vertex(px2, py2, pz2))

    # Side walls
    for i in range(sides):
        v1 = ring1[i]
        v2 = ring2[i]
        v3 = ring2[(i + 1) % sides]
        v4 = ring1[(i + 1) % sides]
        builder.add_quad(v1, v2, v3, v4)

    # Caps
    center1 = builder.add_vertex(x1, y1, z1)
    center2 = builder.add_vertex(x2, y2, z2)
    for i in range(sides):
        builder.add_triangle(center1, ring1[(i + 1) % sides], ring1[i])
        builder.add_triangle(center2, ring2[i], ring2[(i + 1) % sides])


def build_head(builder, y_offset=0.0):
    """Builds the iconic 'How to Fish' elongated bean head with giant bulging faceted eyes."""
    builder.set_material("mat_skin")
    
    # 1. Elongated Faceted Head/Neck Rings (8-sided cross sections)
    # Heights from neck to crown:
    # Rings: (y, radius_x, radius_z, z_offset)
    rings_spec = [
        (0.00, 0.18, 0.18, 0.00), # Neck base
        (0.20, 0.17, 0.17, 0.01), # Mid neck
        (0.40, 0.20, 0.22, 0.03), # Jaw / lower face
        (0.60, 0.25, 0.26, 0.05), # Cheeks / mouth level
        (0.76, 0.26, 0.26, 0.04), # Eye level
        (0.92, 0.25, 0.25, 0.02), # Forehead / brow
        (1.05, 0.20, 0.20, 0.00), # Crown
    ]
    sides = 8
    rings_verts = []

    for y, rx, rz, z_off in rings_spec:
        v_ring = []
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            vx = rx * math.sin(angle)
            vy = y + y_offset
            vz = rz * math.cos(angle) + z_off
            v_ring.append(builder.add_vertex(vx, vy, vz))
        rings_verts.append(v_ring)

    # Connect rings
    for r in range(len(rings_verts) - 1):
        for i in range(sides):
            v1 = rings_verts[r][i]
            v2 = rings_verts[r + 1][i]
            v3 = rings_verts[r + 1][(i + 1) % sides]
            v4 = rings_verts[r][(i + 1) % sides]
            builder.add_quad(v1, v2, v3, v4)

    # Crown cap
    top_vertex = builder.add_vertex(0.0, rings_spec[-1][0] + y_offset + 0.08, 0.0)
    for i in range(sides):
        builder.add_triangle(top_vertex, rings_verts[-1][i], rings_verts[-1][(i + 1) % sides])

    # 2. Nose (Angular small pyramid between eyes)
    builder.set_material("mat_skin")
    n_top = builder.add_vertex(0.0, 0.76 + y_offset, 0.31)
    n_tip = builder.add_vertex(0.0, 0.69 + y_offset, 0.37)
    n_left = builder.add_vertex(-0.06, 0.66 + y_offset, 0.29)
    n_right = builder.add_vertex(0.06, 0.66 + y_offset, 0.29)
    builder.add_triangle(n_top, n_tip, n_left)
    builder.add_triangle(n_top, n_right, n_tip)
    builder.add_triangle(n_tip, n_right, n_left)

    # 3. Grimace / Flat Mouth Slit
    builder.set_material("mat_hair")
    m1 = builder.add_vertex(-0.11, 0.53 + y_offset, 0.27)
    m2 = builder.add_vertex(0.11, 0.53 + y_offset, 0.27)
    m3 = builder.add_vertex(0.10, 0.50 + y_offset, 0.26)
    m4 = builder.add_vertex(-0.10, 0.50 + y_offset, 0.26)
    builder.add_quad(m1, m2, m3, m4)

    # 4. Underbite Tusks / Fangs (Accent)
    builder.set_material("mat_accent")
    for sign in [-1, 1]:
        tx = sign * 0.07
        t_base = builder.add_vertex(tx, 0.51 + y_offset, 0.28)
        t_tip = builder.add_vertex(tx, 0.57 + y_offset, 0.30)
        t_w = builder.add_vertex(tx + sign * 0.025, 0.51 + y_offset, 0.275)
        builder.add_triangle(t_base, t_tip, t_w)

    # 5. The Iconic "How to Fish" Bulging Eyeballs (White Faceted Spheres + Dark Pupils)
    eye_radius = 0.095
    for sign in [-1, 1]:
        ex = sign * 0.14
        ey = 0.77 + y_offset
        ez = 0.26
        # White eyeball (faceted)
        build_faceted_sphere(builder, (ex, ey, ez), eye_radius, rings=4, sectors=6, mat="mat_eyes_white")

        # Derpy Black Pupil (small dark square facet on front)
        builder.set_material("mat_eyes_pupil")
        px = ex + sign * 0.015 # slight derpy inward gaze
        py = ey
        pz = ez + eye_radius * 0.98
        pw = 0.035
        p1 = builder.add_vertex(px - pw, py + pw, pz)
        p2 = builder.add_vertex(px + pw, py + pw, pz)
        p3 = builder.add_vertex(px + pw, py - pw, pz)
        p4 = builder.add_vertex(px - pw, py - pw, pz)
        builder.add_quad(p1, p2, p3, p4)

    # 6. Hair & Topknot Clump (Prehistoric Caveman flair)
    builder.set_material("mat_hair")
    build_faceted_sphere(builder, (0.0, 1.12 + y_offset, -0.02), 0.16, rings=3, sectors=5, mat="mat_hair")
    build_faceted_sphere(builder, (0.0, 1.22 + y_offset, -0.03), 0.11, rings=3, sectors=5, mat="mat_hair")

    # 7. Mammoth Bone through Hair (Accent)
    builder.set_material("mat_accent")
    build_faceted_cylinder(builder, (-0.24, 1.20 + y_offset, -0.03), (0.24, 1.20 + y_offset, -0.03), 0.03, 0.03, sides=5, mat="mat_accent")
    # Bone flared knobs
    build_faceted_sphere(builder, (-0.24, 1.20 + y_offset, -0.03), 0.05, rings=3, sectors=4, mat="mat_accent")
    build_faceted_sphere(builder, (0.24, 1.20 + y_offset, -0.03), 0.05, rings=3, sectors=4, mat="mat_accent")


def build_torso(builder):
    """Builds the chunky faceted torso with pelt overalls / tunic and straps."""
    builder.set_material("mat_clothing")
    # Torso rings: (y, width_x, depth_z)
    torso_spec = [
        (1.05, 0.36, 0.22), # Shoulders
        (0.85, 0.38, 0.24), # Chest
        (0.60, 0.33, 0.21), # Waist
        (0.40, 0.34, 0.22), # Hips
    ]
    sides = 8
    rings_verts = []

    for y, rx, rz in torso_spec:
        v_ring = []
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            vx = rx * math.sin(angle)
            vy = y
            vz = rz * math.cos(angle)
            v_ring.append(builder.add_vertex(vx, vy, vz))
        rings_verts.append(v_ring)

    # Torso sides
    for r in range(len(rings_verts) - 1):
        for i in range(sides):
            v1 = rings_verts[r][i]
            v2 = rings_verts[r + 1][i]
            v3 = rings_verts[r + 1][(i + 1) % sides]
            v4 = rings_verts[r][(i + 1) % sides]
            builder.add_quad(v1, v2, v3, v4)

    # Bottom loincloth flap
    builder.set_material("mat_clothing")
    f1 = builder.add_vertex(-0.18, 0.40, 0.22)
    f2 = builder.add_vertex(0.18, 0.40, 0.22)
    f3 = builder.add_vertex(0.15, 0.08, 0.25)
    f4 = builder.add_vertex(-0.15, 0.08, 0.25)
    builder.add_quad(f1, f2, f3, f4)

    # Overalls Shoulder Straps (Accent / pelt strap)
    builder.set_material("mat_accent")
    for sign in [-1, 1]:
        s_front = builder.add_vertex(sign * 0.18, 0.90, 0.24)
        s_top   = builder.add_vertex(sign * 0.18, 1.06, 0.10)
        s_back  = builder.add_vertex(sign * 0.18, 0.88, -0.22)
        sw = 0.05
        s_front_w = builder.add_vertex(sign * 0.18 + sign * sw, 0.90, 0.24)
        s_top_w   = builder.add_vertex(sign * 0.18 + sign * sw, 1.06, 0.10)
        s_back_w  = builder.add_vertex(sign * 0.18 + sign * sw, 0.88, -0.22)
        builder.add_quad(s_front, s_top, s_top_w, s_front_w)
        builder.add_quad(s_top, s_back, s_back_w, s_top_w)

    # Tooth Necklace (Accent)
    for i in range(5):
        angle = -0.6 + i * 0.3
        tx = math.sin(angle) * 0.26
        ty = 0.95 - abs(angle) * 0.08
        tz = math.cos(angle) * 0.24 + 0.04
        build_faceted_sphere(builder, (tx, ty, tz), 0.03, rings=2, sectors=4, mat="mat_accent")


def build_arm(builder, side="left"):
    """Builds a faceted low-poly arm with mitten hand and wrist wrap."""
    sign = -1.0 if side == "left" else 1.0
    builder.set_material("mat_skin")

    # Upper arm
    p_shoulder = (sign * 0.44, 0.98, 0.0)
    p_elbow    = (sign * 0.50, 0.60, 0.02)
    build_faceted_cylinder(builder, p_shoulder, p_elbow, 0.11, 0.09, sides=5, mat="mat_skin")

    # Arm wrap band (Accent)
    p_mid1 = (sign * 0.47, 0.82, 0.01)
    p_mid2 = (sign * 0.48, 0.74, 0.01)
    build_faceted_cylinder(builder, p_mid1, p_mid2, 0.12, 0.12, sides=5, mat="mat_accent")

    # Lower arm
    p_wrist = (sign * 0.52, 0.26, 0.06)
    build_faceted_cylinder(builder, p_elbow, p_wrist, 0.09, 0.08, sides=5, mat="mat_skin")

    # Mitten Hand (Chunky faceted)
    build_faceted_sphere(builder, (sign * 0.53, 0.14, 0.08), 0.10, rings=3, sectors=5, mat="mat_skin")
    # Thumb
    build_faceted_sphere(builder, (sign * 0.53 + sign * 0.06, 0.17, 0.13), 0.045, rings=2, sectors=4, mat="mat_skin")


def build_leg(builder, side="left"):
    """Builds a faceted low-poly leg and wedge foot."""
    sign = -1.0 if side == "left" else 1.0

    # Upper leg (Thigh)
    p_hip  = (sign * 0.20, 0.38, 0.0)
    p_knee = (sign * 0.20, 0.02, 0.02)
    build_faceted_cylinder(builder, p_hip, p_knee, 0.13, 0.11, sides=5, mat="mat_clothing")

    # Lower leg (Calf)
    p_ankle = (sign * 0.20, -0.34, 0.0)
    build_faceted_cylinder(builder, p_knee, p_ankle, 0.11, 0.09, sides=5, mat="mat_skin")

    # Chunky flat wedge Foot
    builder.set_material("mat_skin")
    fx = sign * 0.20
    fy = -0.42
    # Flat base quad
    f1 = builder.add_vertex(fx - 0.10, fy, -0.08)
    f2 = builder.add_vertex(fx + 0.10, fy, -0.08)
    f3 = builder.add_vertex(fx + 0.10, fy, 0.26)
    f4 = builder.add_vertex(fx - 0.10, fy, 0.26)
    # Top ankle connection
    t1 = builder.add_vertex(fx - 0.08, fy + 0.12, 0.0)
    t2 = builder.add_vertex(fx + 0.08, fy + 0.12, 0.0)
    # Toe tip
    toe = builder.add_vertex(fx, fy + 0.04, 0.28)

    # Foot faces
    builder.add_quad(f1, f2, f3, f4) # Sole
    builder.add_quad(f1, t1, t2, f2) # Heel back
    builder.add_triangle(t1, f4, toe) # Left side
    builder.add_triangle(t2, toe, f3) # Right side
    builder.add_triangle(t1, toe, t2) # Bridge
    builder.add_triangle(f4, f3, toe) # Toe front


def build_full_caveman(out_dir):
    """Generates the full unified low-poly Caveman mesh."""
    b = ObjMeshBuilder("CaveRaiderCaveman")

    # 1. Torso
    build_torso(b)

    # 2. Head & Face (positioned on top of torso at y=1.05)
    build_head(b, y_offset=1.02)

    # 3. Arms
    build_arm(b, "left")
    build_arm(b, "right")

    # 4. Legs
    build_leg(b, "left")
    build_leg(b, "right")

    obj_path = os.path.join(out_dir, "caveman.obj")
    b.write_obj(obj_path, "caveman.mtl")
    print(f"Generated unified model: {obj_path} ({len(b.vertices)} vertices, {len(b.faces)} faces)")

    # Also generate individual modular limb meshes so animation/ragdoll can pivot limbs independently!
    # Head mesh (local origin at neck pivot)
    b_head = ObjMeshBuilder("CavemanHead", offset=(0.0, 0.0, 0.0))
    build_head(b_head, y_offset=0.0)
    b_head.write_obj(os.path.join(out_dir, "part_head.obj"), "caveman.mtl")

    # Torso mesh (local origin at center of hips/waist)
    b_torso = ObjMeshBuilder("CavemanTorso", offset=(0.0, 0.70, 0.0))
    build_torso(b_torso)
    b_torso.write_obj(os.path.join(out_dir, "part_torso.obj"), "caveman.mtl")

    # Arm L (local origin at shoulder pivot)
    b_arml = ObjMeshBuilder("CavemanArmL", offset=(-0.44, 0.98, 0.0))
    build_arm(b_arml, "left")
    b_arml.write_obj(os.path.join(out_dir, "part_arm_l.obj"), "caveman.mtl")

    # Arm R (local origin at shoulder pivot)
    b_armr = ObjMeshBuilder("CavemanArmR", offset=(0.44, 0.98, 0.0))
    build_arm(b_armr, "right")
    b_armr.write_obj(os.path.join(out_dir, "part_arm_r.obj"), "caveman.mtl")

    # Leg L (local origin at hip pivot)
    b_legl = ObjMeshBuilder("CavemanLegL", offset=(-0.20, 0.38, 0.0))
    build_leg(b_legl, "left")
    b_legl.write_obj(os.path.join(out_dir, "part_leg_l.obj"), "caveman.mtl")

    # Leg R (local origin at hip pivot)
    b_legr = ObjMeshBuilder("CavemanLegR", offset=(0.20, 0.38, 0.0))
    build_leg(b_legr, "right")
    b_legr.write_obj(os.path.join(out_dir, "part_leg_r.obj"), "caveman.mtl")

    # Write MTL file
    mtl_path = os.path.join(out_dir, "caveman.mtl")
    with open(mtl_path, "w", encoding="utf-8") as f:
        f.write("""# Prehistoric Palette Materials
newmtl mat_skin
Kd 0.76 0.54 0.38
Ka 0.1 0.1 0.1
Ks 0.05 0.05 0.05
Ns 10

newmtl mat_clothing
Kd 0.62 0.40 0.22
Ka 0.1 0.1 0.1
Ks 0.05 0.05 0.05
Ns 10

newmtl mat_hair
Kd 0.18 0.12 0.08
Ka 0.1 0.1 0.1
Ks 0.05 0.05 0.05
Ns 10

newmtl mat_accent
Kd 0.92 0.88 0.78
Ka 0.1 0.1 0.1
Ks 0.1 0.1 0.1
Ns 20

newmtl mat_eyes_white
Kd 0.96 0.96 0.94
Ka 0.2 0.2 0.2
Ks 0.1 0.1 0.1
Ns 30

newmtl mat_eyes_pupil
Kd 0.08 0.08 0.08
Ka 0.05 0.05 0.05
Ks 0.0 0.0 0.0
Ns 5
""")
    print(f"Generated material library: {mtl_path}")

if __name__ == "__main__":
    out_directory = os.path.abspath("d:/Godot/troll/assets/models/character")
    os.makedirs(out_directory, exist_ok=True)
    build_full_caveman(out_directory)
