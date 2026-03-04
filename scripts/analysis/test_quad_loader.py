#!/usr/bin/env python3
"""
Generate a simple Wavefront OBJ file with quad and triangle topology
to test the quad-aware OBJ loader.
"""

def generate_quad_obj(filename="quad_test.obj"):
    """Create a test OBJ with both triangles and quads"""
    with open(filename, 'w') as f:
        # Write header
        f.write("# Test OBJ with mixed quad and triangle topology\n")
        f.write("# 4 vertices forming a quad\n")
        f.write("v -1.0 -1.0 0.0\n")  # v1
        f.write("v  1.0 -1.0 0.0\n")  # v2
        f.write("v  1.0  1.0 0.0\n")  # v3
        f.write("v -1.0  1.0 0.0\n")  # v4
        
        f.write("\n# 3 vertices forming a triangle (displaced in Z)\n")
        f.write("v -1.0 -1.0 -2.0\n")  # v5
        f.write("v  1.0 -1.0 -2.0\n")  # v6
        f.write("v  0.0  1.0 -2.0\n")  # v7
        
        f.write("\n# Quad face (4 vertices)\n")
        f.write("f 1 2 3 4\n")
        
        f.write("\n# Triangle face (3 vertices)\n")
        f.write("f 5 6 7\n")
    
    print(f"Generated {filename}")
    with open(filename, 'r') as f:
        print("Content:")
        print(f.read())

def generate_cube_quad_obj(filename="cube_quad_test.obj"):
    """Create a cube using all quads (6 faces)"""
    with open(filename, 'w') as f:
        f.write("# Cube made entirely of quads\n")
        # Define 8 vertices of a cube
        f.write("v -1.0 -1.0 -1.0\n")  # 1
        f.write("v  1.0 -1.0 -1.0\n")  # 2
        f.write("v  1.0  1.0 -1.0\n")  # 3
        f.write("v -1.0  1.0 -1.0\n")  # 4
        f.write("v -1.0 -1.0  1.0\n")  # 5
        f.write("v  1.0 -1.0  1.0\n")  # 6
        f.write("v  1.0  1.0  1.0\n")  # 7
        f.write("v -1.0  1.0  1.0\n")  # 8
        
        f.write("\n# 6 quad faces\n")
        f.write("f 1 2 3 4\n")  # front
        f.write("f 5 8 7 6\n")  # back
        f.write("f 1 5 6 2\n")  # bottom
        f.write("f 4 3 7 8\n")  # top
        f.write("f 1 4 8 5\n")  # left
        f.write("f 2 6 7 3\n")  # right
    
    print(f"Generated {filename}")
    with open(filename, 'r') as f:
        print("Content:")
        print(f.read())

if __name__ == "__main__":
    generate_quad_obj("quad_test.obj")
    print("\n" + "="*60 + "\n")
    generate_cube_quad_obj("cube_quad_test.obj")
