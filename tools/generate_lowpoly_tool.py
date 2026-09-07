import os
import math

class ObjBuilder:
    def __init__(self, name="tool", offset=(0.0, 0.0, 0.0)):
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
        """rings is a list of lists of vertex indices (each list is 1 ring of N vertices)."""
        num_rings = len(rings)
        if num_rings < 2:
            return
        n_per_ring = len(rings[0])
        for r in range(num_rings - 1):
            r1 = rings[r]
            r2 = rings[r + 1]
            for i in range(n_per_ring):
                ni = (i + 1) % n_per_ring
                self.add_quad(r1[i], r1[ni], r2[ni], r2[i])

    def write_obj(self, filepath, mtl_filename):
        mat_groups = {}
        for mat, f_verts in self.faces:
            if mat not in mat_groups:
                mat_groups[mat] = []
            mat_groups[mat].append(f_verts)

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"# Prehistoric Pickaxe Low-Poly\n")
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

def build_pickaxe_mesh():
    b = ObjBuilder("pickaxe")

    # 1. WOODEN HANDLE (Y axis, from y = -0.35 to y = +0.28)
    # 6-sided faceted cross section with organic curve and knobby ends
    b.set_material("mat_wood")
    
    segments = [
        # (y, radius, x_offset, z_offset)
        (-0.36, 0.026, 0.000, -0.015), # bottom knob
        (-0.34, 0.022, 0.000, -0.010),
        (-0.25, 0.019, 0.002, -0.005),
        (-0.10, 0.018, 0.003, 0.000),  # grip area
        ( 0.05, 0.019, 0.002, 0.005),
        ( 0.18, 0.021, 0.000, 0.010),  # near head mount
        ( 0.24, 0.023, -0.001, 0.012), # head socket
        ( 0.28, 0.020, -0.002, 0.012), # top tip
    ]
    
    rings = []
    n_pts = 6
    for y, r, ox, oz in segments:
        ring = []
        for i in range(n_pts):
            angle = i * (2.0 * math.pi / n_pts)
            vx = ox + math.cos(angle) * r
            vz = oz + math.sin(angle) * r
            ring.append(b.add_vertex(vx, y, vz))
        rings.append(ring)

    b.add_cylinder_section(rings)
    
    # Cap bottom
    b_center = b.add_vertex(segments[0][2], segments[0][0] - 0.01, segments[0][3])
    r_bot = rings[0]
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(b_center, r_bot[ni], r_bot[i])

    # Cap top
    t_center = b.add_vertex(segments[-1][2], segments[-1][0] + 0.01, segments[-1][3])
    r_top = rings[-1]
    for i in range(n_pts):
        ni = (i + 1) % n_pts
        b.add_triangle(t_center, r_top[i], r_top[ni])

    # 2. STONE PICKAXE HEAD (Mounts across Y ~ 0.22, extending along Z axis)
    # Z- (Forward): Sharp curved pick point
    # Z+ (Backward): Blunt chipped hammer wedge
    b.set_material("mat_stone")

    # Stone pick sections along Z from back (+Z=0.18) to front tip (-Z=-0.36)
    # Each section is a 4-vertex diamond/rhombus cross section (X_half, Y_half)
    stone_sections = [
        # (z, x_half, y_top, y_bot)
        ( 0.16, 0.022, 0.240, 0.200), # Back hammer butt
        ( 0.12, 0.030, 0.248, 0.192),
        ( 0.04, 0.034, 0.252, 0.188), # Center through handle
        (-0.06, 0.032, 0.248, 0.190),
        (-0.16, 0.026, 0.238, 0.185), # Curving down
        (-0.26, 0.018, 0.220, 0.175), # Tapering pick point
        (-0.34, 0.008, 0.195, 0.165), # Sharp beak tip
    ]

    s_rings = []
    for z, xh, yt, yb in stone_sections:
        ym = (yt + yb) * 0.5
        v_top = b.add_vertex( 0.0, yt, z)
        v_rit = b.add_vertex(  xh, ym, z)
        v_bot = b.add_vertex( 0.0, yb, z)
        v_lft = b.add_vertex( -xh, ym, z)
        s_rings.append([v_top, v_rit, v_bot, v_lft])

    b.add_cylinder_section(s_rings)

    # Cap back hammer end
    back_center = b.add_vertex(0.0, (stone_sections[0][2] + stone_sections[0][3])*0.5, stone_sections[0][0] + 0.01)
    b.add_triangle(back_center, s_rings[0][0], s_rings[0][1])
    b.add_triangle(back_center, s_rings[0][1], s_rings[0][2])
    b.add_triangle(back_center, s_rings[0][2], s_rings[0][3])
    b.add_triangle(back_center, s_rings[0][3], s_rings[0][0])

    # Cap sharp pick beak tip
    tip_pt = b.add_vertex(0.0, (stone_sections[-1][2] + stone_sections[-1][3])*0.5 - 0.01, stone_sections[-1][0] - 0.025)
    b.add_triangle(tip_pt, s_rings[-1][1], s_rings[-1][0])
    b.add_triangle(tip_pt, s_rings[-1][2], s_rings[-1][1])
    b.add_triangle(tip_pt, s_rings[-1][3], s_rings[-1][2])
    b.add_triangle(tip_pt, s_rings[-1][0], s_rings[-1][3])

    # 3. LEATHER STRAPS / ROPE BINDING (Criss-cross wraps at wood/stone joint)
    b.set_material("mat_clothing") # uses leather/clothing texture
    # Wrap ring 1
    w1_y = 0.20
    w2_y = 0.24
    wrap_r = 0.038
    w_pts = 6
    w_ring1 = []
    w_ring2 = []
    for i in range(w_pts):
        angle = i * (2.0 * math.pi / w_pts)
        vx = math.cos(angle) * wrap_r
        vz = math.sin(angle) * wrap_r
        w_ring1.append(b.add_vertex(vx, w1_y, vz))
        w_ring2.append(b.add_vertex(vx, w2_y, vz))
    b.add_cylinder_section([w_ring1, w_ring2])

    return b

def build_arm_mesh():
    b = ObjBuilder("viewmodel_arm")
    b.set_material("mat_skin")

    # Chunky caveman forearm coming from bottom-right into the screen to grip handle at Y=-0.10
    # Elbow base at (X=0.28, Y=-0.42, Z=0.24)
    # Wrist at (X=0.08, Y=-0.18, Z=0.08)
    # Fist around (X=0.00, Y=-0.10, Z=0.00)
    arm_segments = [
        # (x, y, z, rx, ry)
        (0.26, -0.42, 0.22, 0.070, 0.065), # Base/elbow
        (0.19, -0.32, 0.16, 0.060, 0.055), # Forearm
        (0.12, -0.22, 0.10, 0.050, 0.045), # Near wrist
        (0.07, -0.15, 0.05, 0.042, 0.040), # Wrist joint
    ]

    rings = []
    n_pts = 6
    for cx, cy, cz, rx, ry in arm_segments:
        ring = []
        for i in range(n_pts):
            ang = i * (2.0 * math.pi / n_pts)
            vx = cx + math.cos(ang) * rx
            vy = cy + math.sin(ang) * ry
            vz = cz + math.sin(ang) * 0.02
            ring.append(b.add_vertex(vx, vy, vz))
        rings.append(ring)

    b.add_cylinder_section(rings)

    # Chunky fist wrapping around handle at (0, -0.10, 0)
    # Fist box (clenched fingers and thumb)
    # Vertices of chunky low-poly fist
    f_xmin, f_xmax = -0.045, 0.055
    f_ymin, f_ymax = -0.15, -0.05
    f_zmin, f_zmax = -0.045, 0.045

    f1 = b.add_vertex(f_xmin, f_ymin, f_zmin)
    f2 = b.add_vertex(f_xmax, f_ymin, f_zmin)
    f3 = b.add_vertex(f_xmax, f_ymax, f_zmin)
    f4 = b.add_vertex(f_xmin, f_ymax, f_zmin)
    f5 = b.add_vertex(f_xmin, f_ymin, f_zmax)
    f6 = b.add_vertex(f_xmax, f_ymin, f_zmax)
    f7 = b.add_vertex(f_xmax, f_ymax, f_zmax)
    f8 = b.add_vertex(f_xmin, f_ymax, f_zmax)

    # 6 quad faces of fist
    b.add_quad(f1, f2, f3, f4) # front
    b.add_quad(f6, f5, f8, f7) # back
    b.add_quad(f5, f1, f4, f8) # left
    b.add_quad(f2, f6, f7, f3) # right
    b.add_quad(f4, f3, f7, f8) # top
    b.add_quad(f5, f6, f2, f1) # bottom

    # Chunky thumb resting on top
    th1 = b.add_vertex(-0.03, -0.05, -0.03)
    th2 = b.add_vertex( 0.02, -0.05, -0.03)
    th3 = b.add_vertex( 0.02, -0.02, -0.01)
    th4 = b.add_vertex(-0.03, -0.02, -0.01)
    b.add_quad(th1, th2, th3, th4)

    return b

def write_pickaxe_mtl(filepath):
    with open(filepath, "w", encoding="utf-8") as f:
        f.write("# Materials for Prehistoric Tools\n\n")
        
        f.write("newmtl mat_wood\n")
        f.write("Kd 0.40 0.28 0.16\n")
        f.write("Ks 0.05 0.05 0.05\n")
        f.write("Ns 10.0\n\n")

        f.write("newmtl mat_stone\n")
        f.write("Kd 0.22 0.24 0.26\n")
        f.write("Ks 0.15 0.15 0.15\n")
        f.write("Ns 20.0\n\n")

        f.write("newmtl mat_clothing\n")
        f.write("Kd 0.52 0.35 0.20\n")
        f.write("Ks 0.05 0.05 0.05\n")
        f.write("Ns 5.0\n\n")

        f.write("newmtl mat_skin\n")
        f.write("Kd 0.82 0.58 0.42\n")
        f.write("Ks 0.05 0.05 0.05\n")
        f.write("Ns 5.0\n\n")

if __name__ == "__main__":
    out_dir = r"d:\Godot\troll\assets\models\character"
    os.makedirs(out_dir, exist_ok=True)
    
    mtl_path = os.path.join(out_dir, "tool_pickaxe.mtl")
    write_pickaxe_mtl(mtl_path)
    
    pickaxe = build_pickaxe_mesh()
    pickaxe.write_obj(os.path.join(out_dir, "tool_pickaxe.obj"), "tool_pickaxe.mtl")
    print("Generated tool_pickaxe.obj (vertices: %d, faces: %d)" % (len(pickaxe.vertices), len(pickaxe.faces)))

    arm = build_arm_mesh()
    arm.write_obj(os.path.join(out_dir, "viewmodel_arm.obj"), "tool_pickaxe.mtl")
    print("Generated viewmodel_arm.obj (vertices: %d, faces: %d)" % (len(arm.vertices), len(arm.faces)))
