# ComputerCraft CDN
A read-only host-agnostic file system for distributing content across
ComputerCraft computers. Initially developed as a music player, it has
since expanded into a versatile file sharing application.

## Installation
All you have to do is run the following on your ComputerCraft computer:
```pastebin run jEAyuG5g```

Due to the integrated nature of pastebin into ComputerCraft in contrast to
github, a bootstrap script was needed to download and run the actual installer
script from this repository. That bootstrap script can be found in
[bootstrap.lua](bootstrap.lua). Updating the pastebin entry every time the
installer script needs changing would not be ideal.

## Extra Goodies
Much of the functionality used in the main CCCDN application has been
separated into multiple files so as to allow usage in different scenarios
by other developers. The instances where this is the case are the following:
- `libcdn.lua` for interfacing with the virtual file system,
  the core functionality of the application.
- `libqoa.lua` a decoder for the QOA format for when higher
  quality than that of DFPWM is desired during audio playback.
