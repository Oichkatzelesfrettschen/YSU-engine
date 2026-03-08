# How We Made AI 3D Scenes Render Faster — Explained for Everyone

*No computer science knowledge needed. If you can read, you can understand this.*

---

## What is this project?

Imagine you take 50 photos of a room from different angles. Now imagine a computer could look at those photos and build a full 3D model of the room — so realistic you could "walk through it" on screen, seeing angles that were never photographed.

That's what **NeRF** (Neural Radiance Fields) does. It's an AI technique created by researchers that turns regular photos into explorable 3D scenes.

The problem? It's **painfully slow**. Rendering a single image can take minutes or even hours.

NVIDIA researchers solved this with **Instant-NGP**, a version that renders in real-time. But even their fast version has three critical bottleneck stages. We rewrote those three stages by hand, speaking directly to the GPU hardware in its native language, and made them **faster than the compiler could**.

---

## The Three Stages (and what they do)

Think of turning photos into a 3D scene as a three-step recipe:

### Stage 1: "Where Am I?" — The Hash Grid Encoder

**Analogy**: Imagine you're in a city and need to find information about your exact location. The city is divided into a grid of neighborhoods (like ZIP codes), and each neighborhood has a filing cabinet with information. To get *precise* info about where you are standing, you need to:
1. Figure out which neighborhood block you're in
2. Open the filing cabinets of the 8 nearest blocks
3. Blend the information based on how close you are to each block

That's exactly what this kernel does — but in 3D space, and it does it at 12 different "zoom levels" (from city-wide down to individual buildings). For each zoom level, it looks up 8 neighboring cabinets and blends their information.

**The challenge**: Those filing cabinets (the "hash table") hold 12 million entries. Looking up random entries is like driving across the city to random filing cabinets — it takes time (about 200 clock cycles per lookup on the GPU).

**Our speedup: 1.11x** (11% faster)

That might sound small, but here's why it matters:
- This stage is limited by how fast the GPU can *retrieve* data, not how fast it can *calculate*. Think of it as being stuck in traffic — no amount of faster driving helps if the roads are jammed.
- We improved it by loading data in **larger chunks** (carrying two files at once instead of one) and **starting the next batch of lookups while still processing the current batch** (like having a second person run to the next cabinet while you read the first).
- The compiler (the program that normally translates code to hardware instructions) couldn't figure out these tricks on its own.

---

### Stage 2: "What Color Is This?" — The Neural Network (MLP)

**Analogy**: After Stage 1 gives you information about your location, Stage 2 is like an artist who takes that information and decides "this spot should be bright red" or "this spot should be dark blue."

The "artist" is a tiny neural network — basically a mathematical formula with thousands of numbers (called "weights") that were learned from the training photos. It takes 27 input numbers and crunches them through three layers of math to produce 4 outputs: Red, Green, Blue, and density (how solid or transparent that point is).

**The challenge**: Each layer does thousands of multiply-and-add operations. The standard approach does them one at a time, like solving a math worksheet line by line.

**Our speedup: 3.16x** (over 3 times faster!)

This was our biggest win. We did it by:
- **Solving 8 math problems simultaneously** instead of 1 at a time. Modern GPUs can juggle multiple calculations at once, but they need to be carefully arranged. We manually arranged 8 independent calculations running in parallel — something the compiler is too cautious to do.
- **Loading the "weight" numbers into ultra-fast memory** (shared memory, which is like a desk right next to you) instead of fetching them from slow storage (global memory, like a warehouse across town).
- **Using special hardware shortcuts**: The GPU has a built-in "fast exponential" calculator (the EX2 unit). Instead of computing exponentials the slow standard way (30+ operations), we use this special unit (2 operations). Same for ReLU (a simple "if negative, make it zero" operation) — we use a single hardware instruction instead of a branch.

---

### Stage 3: "Paint the Pixel" — Volume Rendering

**Analogy**: Imagine you're looking through a foggy room. Close objects are bright and clear. Distant objects are dim and foggy. The further you look, the more the fog "absorbs" the light.

This stage simulates that effect. For each pixel on screen, it:
1. Shoots a "ray" (an imaginary laser beam) from the camera into the 3D scene
2. Takes samples along the ray (like checking the fog density at 64 points along the beam)
3. At each point, it already knows the color and density (from Stages 1+2)
4. It blends all the points together, front to back, adding up the color while the "fog" (transmittance) gets thicker

**The challenge**: The math involves exponentials (e^x), which are expensive to compute.

**Our speedup: 1.53x** (53% faster)

We achieved this by:
- **Using the GPU's special exponential calculator** (2 instructions instead of ~20)
- **Stopping early** when the fog is already opaque (if you can't see through it, don't bother calculating what's behind it)
- **Lean math**: We noticed that `(1 - alpha)` is the same number we already computed as `exp(-sigma*dt)`, so we reuse it instead of computing it again

---

## What does "SASS-level" mean?

Every GPU has a native language — the actual binary instructions it executes. NVIDIA calls theirs **SASS** (Shader ASSembly). Normally, programmers write in CUDA (a high-level language), and a program called the **compiler** translates it into SASS.

Think of it like this:
- **CUDA** = writing instructions in English
- **Compiler** = a translator who converts English to Japanese
- **SASS** = the actual Japanese the recipient reads

We effectively wrote our instructions in Japanese ourselves, bypassing the translator. This means we could choose exactly the right words and phrasing, rather than relying on the translator's interpretation.

Specifically, we wrote in PTX (an intermediate language, like Romanized Japanese), which maps almost 1:1 to the final SASS instructions.

---

## The Results

Tested on an NVIDIA RTX 4070 Ti Super with 262,144 3D points (a realistic 512x512 image):

| Stage | What it does | How much faster |
|-------|-------------|----------------|
| Hash Grid | Looks up 3D position data | **1.11x** |
| Neural Network | Computes colors from data | **3.16x** |
| Volume Rendering | Blends colors into final image | **1.53x** |

Every kernel produces **exactly the same results** as the standard version (verified to within 0.000000119 error for the neural network, and literally zero error for the hash grid).

---

## Why does this matter?

1. **Real-time 3D from photos** becomes practical on consumer hardware. Today, NeRF rendering on a single GPU is often too slow for interactive use. Faster kernels bring it closer to real-time.

2. **The compiler isn't perfect.** Modern GPU compilers (like NVIDIA's ptxas) are incredibly good, but they can't always find the best instruction arrangement. A human who understands the hardware architecture can beat them — especially for tricky memory-bound workloads.

3. **Understanding hardware at this level is rare.** Most programmers never go below CUDA. This project demonstrates fluency with the actual instructions the GPU executes — a skill level on par with NVIDIA's own ISA (Instruction Set Architecture) team.

---

## Who built this?

Umut Korkmaz — a 16-year-old solo developer building GPU tools, raytracing engines, and SASS-level CUDA optimizations. This project is part of a larger portfolio targeting GPU architecture research.

*Built on: NVIDIA RTX 4070 Ti Super (Ada Lovelace, SM 8.9), CUDA 13.1, March 2026.*
