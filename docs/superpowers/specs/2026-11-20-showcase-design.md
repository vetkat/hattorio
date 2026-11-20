# Showcase screenshots

Status: design, for approval by the owner.

## Intent

The mod page has two images: a render of the tiling and a render of the
bands. It has no screenshot of a factory that a player would recognise. The
owner wants 5 to 10 screenshots of each vanilla planet in a Space Age game.
The screenshots show a base that starts small and grows to a large base, not
a mega-base. They go on the mod page.

Nobody can play the game for this. The owner chose a scripted showcase: a
script builds the bases in the game, and the game renders the screenshots.

## Goals

- 5 to 10 screenshots for each of Nauvis, Vulcanus, Fulgora, Gleba and
  Aquilo: 25 to 50 in all.
- Each planet shows a base in stages, from a few buildings to a large base.
- Each screenshot is a real render of Factorio 2.1 with Space Age and
  Hattorio 1.1.1 at the default settings (cell size 41, band width 3).
- Every building stands inside a cell. The script places a building only
  where the game allows it, so no building stands on a band.
- The bases show what the mod changes:
  - buildings that fit the cell shapes
  - underground belts and pipes across bands, and rails across bands
  - on Aquilo and Fulgora, the dark band line over the ocean
- The screenshots are in the repository, and the mod page shows them.
- The pipeline can run again, for example after a new release.
- Video material for a later video, without voice: a silent clip of each
  stage on each planet, recorded in the same run as the screenshots.

## Non-goals

- A played game. The mod page says that a script built the bases.
- A working economy. Buildings can be idle. The screenshots do not claim
  that the base produces anything.
- A mega-base.
- The finished video: narration, music, titles and the edit. The owner
  makes it later from the clips, or edits the video by the author of
  Multi-Team Support.

## Anti-goals

- A building on a band, or a screenshot that hides a band under the GUI.
- Screenshots that look like a different mod: no editor tiles, no
  infinity chests or other hidden entities in view.
- A repository that gets heavy: no PNGs of several MB each, and no video
  in git.

## Constraints

- The game with graphics is the Steam copy of Factorio 2.1.24. It runs with
  its own config, mods and save folders in the scratch directory, and with
  `SteamAppId=427520`, as in the spike for #21. It opens a window on the
  owner's screen while it runs.
- `game.take_screenshot` writes at the end of the tick. A change and its
  screenshot must be in different ticks.
- The mod portal shows images in the long description from
  `raw.githubusercontent.com`. Its gallery takes uploads through
  `api/v2/mods/images/add` and an order through `images/edit`, with the
  same key permission as the description. The first image is probably the
  thumbnail. That needs a check on the portal.

## Approaches

- **A. A showcase mod that places buildings from layouts (chosen).** A
  small mod in `tools/showcase/` holds one layout per planet and stage: a
  list of buildings with offsets. For each layout it finds a cell near the
  base that fits it, with `surface.can_place_entity`. It places the
  buildings, connects cells with underground belts and rails, and takes
  the screenshots.
- **B. Blueprint strings.** The script would paste blueprints that a person
  made in the game. Nobody can make them here, and a blueprint does not
  adapt to the cell shapes.
- **C. Scripted gameplay.** A script that plays the game, with research and
  logistics, is far more work than the screenshots need.

The owner chose scripted bases. A is the way to build them, because it
adapts each layout to the cells, which is what the mod is about.

## Design

- **How the game runs (builder's call, from the spike for #21).**
  `tools/showcase.sh` starts the Steam binary
  (`~/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio`) with
  `SteamAppId=427520` and `SteamGameId=427520`, so that it does not restart
  through Steam.

  A config file sets `write-data` to a scratch folder.
  `--mod-directory` points at a scratch folder. That folder holds links to
  Hattorio and the showcase mod, and a `mod-list.json` that turns on
  Space Age, Quality and Elevated Rails.

  The script creates a map with `--create` and loads it with
  `--load-game`. It waits for a log line, and then closes the game. The
  agent can run it unattended. The window shows on the owner's screen.
- **Where.** `tools/showcase/` holds the mod (`info.json`, `control.lua`
  and one layout file for each planet).

  `tools/showcase.sh` runs it. It
  makes the scratch folders and links Hattorio and the showcase mod. It
  creates a map and runs the game until the script logs its last line.
  Then it closes the game. The mod zip does not include `tools/`.
- **Stages.** Each planet has 5 stages. Each stage adds to the base of the
  stage before it:
  1. Start: a few miners on the nearest ore patch and a small power plant.
  2. Furnaces: rows of furnaces in a neighbouring cell. A belt feeds them,
     and it crosses a band with an underground belt.
  3. Production: assembler blocks in two or three more cells.
  4. Planet industry: the buildings of the planet. Foundries on
     Vulcanus, recyclers on Fulgora, agricultural towers and biochambers
     on Gleba, heating towers and ice platform on Aquilo, and labs on
     Nauvis.
  5. Large base: more cells filled, a rail line across several bands, and
     a roboport network.
- **Screenshots.** Each stage gets one screenshot at the zoom of a player
  (zoom 1). The last stage also gets a wide one (zoom 0.4). That is 6 for
  each planet, 30 in all. Size 1600 by 900, with no GUI, at midday.
- **Placement.** The script does not need to know where the cells are.
  For each layout it tries positions in a spiral around the base, and it
  places the layout only where every building can go. The game refuses a
  building on a band, because buildings collide with the band layer. So
  each layout ends up inside a cell. This needs no change to the remote
  interface and no new release (builder's call).
- **Power and fuel.** Buildings get power from solar panels and
  accumulators, or from steam on Nauvis. Burner buildings get coal. The
  script can insert items into buildings, so that some of them work and
  show smoke and light. It does not need to.
- **Files.** The script writes PNG. `tools/showcase.sh` converts each to
  JPEG at quality 85, about 200 to 400 kB, into
  `docs/preview/showcase/<planet>-<stage>.jpg`. 30 of them are about
  10 MB.
- **Video material.** After the screenshots of a stage, the camera pans
  slowly across the base for about 10 seconds. The script takes a
  screenshot each tick at 1920 by 1080, with no GUI.
  `tools/showcase.sh` joins the frames with `ffmpeg` into a silent H.264
  clip at 60 frames per second, `<planet>-<stage>.mp4`, in
  `~/Videos/hattorio-showcase/`, outside the repository. That is 25 clips
  of about 10 seconds.

  The frames stay in the scratch directory until `ffmpeg` makes the clip.
  Then the script deletes them. The game runs slowly while it
  records. That does not show in the clip.
- **The mod page.** `mod-description-long.md` gets a "Screenshots"
  section with one or two images per planet from the repository, and a
  line that says a script built the bases. A new script,
  `tools/portal_images.py`, uploads a selection to the portal gallery. It
  keeps the images that are in the gallery now and adds the new ones after
  them. The stage 5 wide shot of Nauvis goes first, so that it becomes the
  thumbnail (owner's choice). The owner runs it, because it changes the
  public page.
- **Two PRs.** The first PR adds the tool and the gallery script, with no
  images. The owner then looks at the screenshots. The second PR adds the
  JPEGs and the "Screenshots" section of `mod-description-long.md`, which
  `description.yml` sends to the portal when it merges.
- **Re-runs.** All 30 JPEGs go in the repository, about 10 MB. A re-run
  overwrites them in place. It happens only when the look of the mod
  changes, because each commit of new images adds about 10 MB to the
  history for good (owner's choice).

## Left to the builder

- The exact layouts. They must look like a plausible player base at each
  stage.
- The choice of screenshot centre and zoom within the rules above.
- Which items to insert so that buildings show activity.

## Tests

The showcase is a tool, not mod code. It has no in-game test. Its checks:

- `tools/showcase.sh` fails if the game logs an error, if fewer than 30
  screenshots appear, or if fewer than 25 clips appear.
- The script logs how many buildings it placed and refused for each stage.
  A stage with no buildings placed is an error.
- A person looks at every screenshot before it goes on the mod page.
