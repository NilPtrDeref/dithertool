# TODO

- [ ] Read PNG into memory in such a way that pixels can efficiently be indexed into or iterated over.
  - [ ] Load image.
    - [ ] Read each chunk.
  - [ ] Interface.
    - [ ] Iteration.
    - [ ] Indexing.
    - [ ] Clone.
    - [ ] Set pixel.
    - [ ] Resize?
  - [ ] Encode image interface to writer as PNG.
- [ ] Implement basic dither functionality on in memory image.
- [ ] Build interface to load/present image and dither it live, allowing the user to change settings and see changes immediately. (Using Raylib?)
