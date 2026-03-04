import numpy as np
from PIL import Image
import sys

def check_ppm(path):
    try:
        img = Image.open(path)
        data = np.array(img)
        print(f"Image size: {img.size}")
        print(f"Mean brightness: {data.mean()}")
        print(f"Max value: {data.max()}")
        print(f"Min value: {data.min()}")
        # Count non-zero pixels
        nz = np.count_nonzero(data.sum(axis=-1))
        print(f"Non-zero pixels: {nz} ({nz/(data.shape[0]*data.shape[1])*100:.2f}%)")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_ppm("output_gpu.ppm")
