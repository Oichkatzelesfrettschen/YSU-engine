#!/usr/bin/env python3
"""
Download NeRF synthetic lego dataset from alternative sources
"""
import urllib.request
import zipfile
import os
from tqdm import tqdm

class DownloadProgressBar(tqdm):
    def update_to(self, b=1, bsize=1, tsize=None):
        if tsize is not None:
            self.total = tsize
        self.update(b * bsize - self.n)

def download_url(url, output_path):
    with DownloadProgressBar(unit='B', unit_scale=True, miniters=1, desc=url.split('/')[-1]) as t:
        urllib.request.urlretrieve(url, filename=output_path, reporthook=t.update_to)

# Try alternative hosting
urls = [
    "https://huggingface.co/datasets/baihua/NeRF-synthetic/resolve/main/nerf_synthetic.zip",
    "http://cseweb.ucsd.edu/~viscomp/projects/LF/papers/ECCV20/nerf/nerf_synthetic.zip"
]

output_file = "nerf_synthetic.zip"
for url in urls:
    try:
        print(f"Trying to download from: {url}")
        download_url(url, output_file)
        print(f"\nDownloaded to: {output_file}")
        print(f"File size: {os.path.getsize(output_file) / 1e9:.2f} GB")
        
        # Extract
        print("Extracting...")
        with zipfile.ZipFile(output_file, 'r') as zip_ref:
            zip_ref.extractall(".")
        
        print("\nExtracted! Now move the lego folder:")
        print("  Move-Item nerf_synthetic/lego DataNeRF/data/nerf/lego")
        break
    except Exception as e:
        print(f"Failed: {e}")
        continue
