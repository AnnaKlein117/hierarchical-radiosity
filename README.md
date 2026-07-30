# hierarchical-radiosity

A hierarchical radiosity system for global illumination, using mipmaps as implicit octrees to store per-surface radiosity values, with adaptive subdivision to concentrate detail where it's needed.

<!-- TODO: add a screenshot showing rendered scene(s), ideally with a before/after or a visualization of the adaptive subdivision -->
<!-- ![demo](docs/demo.png) -->

## What it does

Radiosity simulates diffuse light transport between surfaces. This implementation stores radiosity values in a mipmap hierarchy per surface texture, acting as an implicit octree without needing an explicit tree data structure. Subdivision is applied adaptively, based on contrast thresholds — surfaces subdivide further in high-variance regions (e.g. shadow boundaries, areas with rapid lighting change) while staying coarse elsewhere, improving accuracy where it matters and limiting computational overhead everywhere else.

## What I built
Developed as a university project at the University of Koblenz-Landau. Built on top of the RT_CVK framework by the computer graphics institute. 
My own contributions:
- The mipmap-based implicit octree data structure for storing per-texel radiosity
- Contrast-threshold-based adaptive subdivision logic
- Compute shader implementation of the radiosity solver

## Tech stack

C++ · OpenGL · GLSL · Compute Shaders 

## Why this approach

Classic hierarchical radiosity relies on explicit octree/quadtree data structures per patch, which adds bookkeeping overhead. Using mipmaps as an implicit hierarchy leverages hardware-accelerated mip generation and sampling, simplifying the implementation while keeping the adaptive-detail benefit of the hierarchical approach.
