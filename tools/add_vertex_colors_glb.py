import struct
import json
import os

in_glb = "d:/Godot/troll/assets/models/character/rafael/rigged_character.glb"
out_glb = "d:/Godot/troll/assets/models/character/rafael/rigged_character.glb" # We can overwrite or save

with open(in_glb, 'rb') as f:
    magic, version, length = struct.unpack('<4sII', f.read(12))
    chunk_len, chunk_type = struct.unpack('<I4s', f.read(8))
    json_data = f.read(chunk_len).decode('utf-8')
    gltf = json.loads(json_data)
    bin_offset = 12 + 8 + chunk_len
    f.seek(bin_offset)
    bin_len, bin_type = struct.unpack('<I4s', f.read(8))
    bin_data = bytearray(f.read(bin_len))

skin = gltf['skins'][0]
joints = skin['joints']
prim = gltf['meshes'][0]['primitives'][0]
j_acc = gltf['accessors'][prim['attributes']['JOINTS_0']]
j_bv = gltf['bufferViews'][j_acc['bufferView']]
j_bytes = bin_data[j_bv['byteOffset']:j_bv['byteOffset']+j_bv['byteLength']]

num_verts = gltf['accessors'][prim['attributes']['POSITION']]['count']

# Generate RGBA color bytes (unsigned byte 0..255 normalized or float)
# glTF COLOR_0 supports componentType 5121 (UNSIGNED_BYTE) with normalized=true, 4 bytes per vert!
color_bytes = bytearray(num_verts * 4)

for i in range(num_verts):
    if j_acc['componentType'] == 5121:
        j0 = j_bytes[i*4]
    else:
        j0 = struct.unpack('<H', j_bytes[i*8:i*8+2])[0]
        
    b_name = gltf['nodes'][joints[j0]].get('name', '')
    
    # Classify bone
    if 'Head' in b_name or 'Neck' in b_name:
        # Skin (Head)
        r, g, b, a = 255, 0, 0, 255
    elif 'Hand' in b_name or 'Thumb' in b_name or 'Index' in b_name or 'Middle' in b_name or 'Ring' in b_name or 'Pinky' in b_name:
        # Skin (Hands)
        r, g, b, a = 255, 128, 0, 255
    elif 'Spine' in b_name or 'Shoulder' in b_name or 'Arm' in b_name:
        # Clothing (Torso & Sleeves)
        r, g, b, a = 0, 255, 0, 255
    elif 'Hips' in b_name or 'UpLeg' in b_name or 'Leg' in b_name:
        # Pants
        r, g, b, a = 0, 0, 255, 255
    elif 'Foot' in b_name or 'Toe' in b_name:
        # Shoes
        r, g, b, a = 40, 40, 40, 255
    else:
        r, g, b, a = 0, 255, 0, 255
        
    color_bytes[i*4 : (i+1)*4] = bytes([r, g, b, a])

# Pad bin_data to 4-byte alignment
while len(bin_data) % 4 != 0:
    bin_data.append(0)

color_offset = len(bin_data)
bin_data.extend(color_bytes)

# Pad again
while len(bin_data) % 4 != 0:
    bin_data.append(0)

# Add bufferView
bv_color_idx = len(gltf['bufferViews'])
gltf['bufferViews'].append({
    'buffer': 0,
    'byteOffset': color_offset,
    'byteLength': len(color_bytes)
})

# Add accessor
acc_color_idx = len(gltf['accessors'])
gltf['accessors'].append({
    'bufferView': bv_color_idx,
    'byteOffset': 0,
    'componentType': 5121, # UNSIGNED_BYTE
    'count': num_verts,
    'type': 'VEC4',
    'normalized': True
})

# Attach to primitive
prim['attributes']['COLOR_0'] = acc_color_idx

# Update buffer length
gltf['buffers'][0]['byteLength'] = len(bin_data)

# Re-encode GLB
json_str = json.dumps(gltf, separators=(',', ':'))
json_bytes = json_str.encode('utf-8')
while len(json_bytes) % 4 != 0:
    json_bytes += b' '

total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_data)

with open(out_glb, 'wb') as f:
    f.write(struct.pack('<4sII', b'glTF', 2, total_len))
    f.write(struct.pack('<I4s', len(json_bytes), b'JSON'))
    f.write(json_bytes)
    f.write(struct.pack('<I4s', len(bin_data), b'BIN\x00'))
    f.write(bin_data)

print(f"Successfully generated {out_glb} with COLOR_0! Total size: {total_len} bytes")
