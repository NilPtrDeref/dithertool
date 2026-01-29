# TODO

- [x] Create standard image memory format
  - [x] Indexable

- [ ] Input Formats
  - [ ] Image
    - [x] PNG
      - [x] Read critical chunk types
      - [x] Interpret data to get pixel information

    - [ ] Jpg/Jpeg

    - [ ] Webp

    - [ ] PPM

- [ ] Output Formats
  - [ ] Image
    - [ ] PNG
    - [ ] PPM

- [ ] Editting
  - [ ] Pixel Sort
  - [ ] Dithering
    - [ ] Floyd-Steinberg
    - [ ] ...

- [ ] User Interface (Using OpenGL)
  - [x] Open Window
  - [x] Basic Texture Rendering
  - [x] Load image
  - [x] Present image
  - [ ] Menu
  - [ ] Live dither image

## Future Development

- [ ] Update UI Code
  - [ ] Make Userdata/Callbacks easier to use (Think about replacing some callback with an event queue?)

- [ ] Upgrade standard image format
  - [ ] Iterable
  - [ ] Copyable
  - [ ] Editable
  - [ ] Resizable

- [ ] PNG Input
  - [ ] Ancillary Chunk Type Ingestion

- [ ] Video
  - [ ] Mp4
  - [ ] Webm
  - [ ] Gif?
