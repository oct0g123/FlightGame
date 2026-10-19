# Game Design

> Status: draft for discussion. All numbers are starting points that live in
> data files and get tuned through play and headless bot runs (see
> [ARCHITECTURE.md](ARCHITECTURE.md#13-testing-and-tooling)).

## Pitch

An air-traffic-control arcade game. Aircraft arrive from the edges of the
map. You drag a line from each one to the runway that matches it, and you
keep them from hitting each other. Traffic keeps building until two of them
collide. Rounds are short, and the next round is one tap away. Later maps
stack traffic at up to three heights, so aircraft can pass over and under
each other.

On iPhone, iPad and Mac it is a tilted, miniature-looking airfield. On Apple
Vision Pro it is a real diorama sitting on your table, with aircraft
descending onto it, and you set an aircraft's height by raising or lowering
your hand as you draw.

### On the name

The game you remember is **Flight Control** (Firemint, 2009, later EA). Game
mechanics can't be owned, but the name, art, sounds and UI can. We use our
own name and our own look throughout. The repo/module prefix is `Flight` for
now. The final title is an open question (see [ROADMAP.md](ROADMAP.md#open-questions)).

## Core loop

1. **Warning.** An edge marker shows the incoming aircraft's type about 2 s
   before it appears.
2. **Arrival.** The aircraft flies in from outside the map on a straight
   heading.
3. **Draw.** The player touches the aircraft and drags a path. The aircraft
   starts following the path while it is still being drawn. Touching the
   aircraft again replaces the path. On maps with flight levels, the player
   can also move an aircraft up or down (see [Flight levels](#flight-levels)).
4. **Commit.** If the path ends in the approach zone of a matching runway and
   roughly lines up with it, the path locks. It snaps onto the centreline and
   changes to the runway's colour, with a soft click and a haptic tap. Further
   dragging is ignored.
5. **Land.** The aircraft descends, touches down and rolls out. While landing
   it can't collide with anything. Score +1.
6. **Unguided aircraft** fly straight. When they reach the edge of the map
   they turn back in.
7. **Conflict.** When two aircraft at about the same height get close, both
   show a pulsing warning ring and a beep plays. If they touch, they crash and the game is over.
8. **Escalation.** Over time aircraft spawn more often, more of them are in
   the air at once, and the mix of types gets harder.

## Aircraft (v1)

Each runway class has both a **colour** and a **glyph**. The glyph is painted
on the aircraft and on its runway, so the game is fully playable without
relying on colour.

| Kind        | Speed (u/s) | Lands on      | Class colour / glyph | Notes                              |
|-------------|-------------|---------------|----------------------|------------------------------------|
| Light prop  | 7           | Short runway  | Yellow ●             | The first aircraft you see.        |
| Jet         | 10          | Long runway   | Red ▲                | Fast and larger, so it needs more room. |
| Helicopter  | 5           | Helipad       | Green ■              | Can approach the pad from any direction. |

`u` = field units. The playfield is 160 × 100 u, so a light prop takes about
23 s to cross the long axis.

**Later candidates:** seaplane (lands on a water lane), emergency aircraft
(fuel timer, flashing, takes priority), formation pair (two aircraft that
share one path), banner plane (can't land, only has to be kept clear until it
leaves), and wind that drifts unguided aircraft.

## Paths

- **Generous grab.** A touch selects the nearest aircraft within about 44 pt
  of the finger. On Vision Pro, aircraft get enlarged hover targets plus the
  same nearest-aircraft snapping.
- **Live follow.** The aircraft follows the path as it is drawn. The part of
  the path behind the aircraft is used up and fades out.
- **Smoothing.** Finger jitter is removed. Each aircraft has a maximum turn
  rate, so a tight scribble becomes a smooth arc, and the model banks into the
  turn.
- **Commit feedback.** While you drag an aircraft, the runways it can use glow
  softly. A path ending at the wrong runway doesn't lock and its end flashes
  red briefly. There is no penalty.
- **Multi-touch.** You can draw several paths at once with several fingers on
  iPhone and iPad, and possibly with both hands on Vision Pro if the input
  spike confirms it works.
- Paths are clamped to just inside the map edge.

## Landing

- **Runway:** a threshold point, a heading, a length, an approach zone (a
  capture radius plus a heading tolerance of ±35°), and the aircraft classes
  it accepts.
- **Helipad:** a circular zone that accepts any heading.
- **Sequence:** on commit, the end of the path is replaced with a clean glide
  segment along the centreline. At the threshold, the aircraft enters
  *landing*: it descends to the ground, decelerates over the runway length,
  then taxis off or fades out. A landing aircraft can't collide with anything.
- **Height:** on maps with flight levels, an aircraft has to get down to the
  ground by the threshold. A path too short to do that doesn't lock (see
  [Flight levels](#flight-levels)).

## Separation and crashes

- **Radii:** every kind has a collision radius (props and helicopters about
  2.5 u, jets about 3 u). The warning starts at roughly twice the collision
  distance. On maps with flight levels, aircraft also have to be at about
  the same height to conflict.
- **Warning:** a pulsing ring on both aircraft, a beep, and one haptic tick
  per conflict, so it doesn't buzz continuously.
- **Crash:** about 1.5 s of slow motion and a small camera nudge toward the
  crash, then the game-over panel. With Reduce Motion on, there is no slow
  motion and no camera nudge.
- **Relaxed mode:** three strikes instead of one, no leaderboard.

## Flight levels

A map can have one to three flight levels stacked above the ground. Aircraft
at different levels pass over and under each other safely, which is how real
air traffic control separates traffic. A map with one level plays exactly
like the classic game, with no level controls shown.

- **Which maps:** Coastal Field has one level, so new players learn the
  basics first. Island Strip adds a second level, and Mountain Valley has
  three.
- **Separation:** two aircraft conflict only when they're close horizontally
  *and* at about the same height.
- **Changing level takes time,** about 3 s per level depending on the kind.
  Between levels an aircraft can conflict with traffic on either one, so
  timing matters: "drop the jet under the prop before they cross."
- **Arrivals** come in at levels that depend on the kind. Arrival levels are
  limited to the levels a map has, and the arrival warning shows the level.

  | Kind       | Arrives at     | Highest level |
  |------------|----------------|---------------|
  | Light prop | Level 1 or 2   | 3             |
  | Jet        | Level 2 or 3   | 3             |
  | Helicopter | Level 1        | 2             |

- **Landing from altitude:**
  - Every aircraft has to be on the ground at the runway threshold.
  - When a path locks onto a runway, the game schedules the descent to start
    as late as possible while still reaching the ground in time. That keeps
    high traffic out of the lower levels for as long as possible. The path
    shows where the descent starts.
  - If the path is too short to get down from the aircraft's height, it
    doesn't lock. Its end flashes amber ("too high"), and the player can keep
    drawing to lengthen it or loop around.
  - The final glide from level 1 to the ground is short (about 6 u), so on
    single-level maps no path is ever too high.
- **Obstacles:** on Mountain Valley, peaks block the lower levels. An aircraft
  below a peak's top crashes into it, and one above flies over. Later ideas:
  storm cells drifting through one level, radio masts that block level 1, and
  departures that climb out through a gate at a set height.

### Changing level

| Platform     | Control                                                          |
|--------------|------------------------------------------------------------------|
| Vision Pro   | While drawing, raise or lower your hand and the path steps up or down, snapping to the nearest level. Faint level planes appear while you draw. Pinching an aircraft and flicking up or down changes its level without redrawing. |
| iPhone, iPad | Tap an aircraft (instead of dragging) to show ▲/▼ buttons next to it for about 2 s. |
| Mac          | Scroll over an aircraft, or press ↑/↓ while hovering. Clicking also shows ▲/▼. |

The rules are identical everywhere. Only the control differs. If testing
shows hand height isn't reliable on Vision Pro, pinch-and-flick becomes the
main control there.

### Reading height

- A **chevron badge** on each aircraft (one to three chevrons), so height
  never depends on colour.
- A thin **drop line** from each aircraft to its ground shadow, with a tick at
  each level.
- The **shadow** sits further from the aircraft the higher it flies. The
  tilted camera on flat screens makes height visible, and on Vision Pro you
  can lean in and look along the traffic.
- All of this is hidden on single-level maps.

### Why not fully free 3D flight

We considered letting aircraft fly at any height and deferred it:

- Judging whether two aircraft will collide at arbitrary heights is much
  harder than with three clear levels, so crashes would feel unfair.
- With indirect pinch, steering a path accurately in depth isn't reliable.
- Flat screens couldn't play the same rules.

It could come back as an experimental Vision Pro-only mode after launch.

## Difficulty

Difficulty is controlled by a few curves of elapsed time, defined per mode in
data:

| Parameter              | Start | Approaches          | Shape                         |
|------------------------|-------|---------------------|-------------------------------|
| Spawn interval         | 6.0 s | 1.6 s               | Exponential, 90 s half-life   |
| Max aircraft airborne  | 3     | 16 (at about 6 min) | Piecewise linear              |
| Mix                    | props only | props 45 / jets 35 / helis 20 % | Steps at 30 s and 90 s |
| Speed scale            | 1.0   | 1.1 (at 5 min)      | Linear, kept small            |

**Fairness rules:**

- Never spawn into an immediate conflict. The game projects the new
  aircraft's straight-line course for about 4 s against current traffic. If it
  would conflict, it picks another edge or delays the spawn.
- Two aircraft never appear from the same edge spot within a few seconds of
  each other.
- An entry warning always precedes an arrival.
- The first 60 s are deliberately gentle.

## Modes

| Mode            | Rules                                              | v1? |
|-----------------|----------------------------------------------------|-----|
| Classic         | Endless. One crash ends the run. Per-map leaderboard. | Yes |
| Daily Challenge | A fixed seed per day, the same arrivals for everyone, one daily leaderboard. | Yes |
| Relaxed         | Slower curve, three strikes, no leaderboard.       | Yes (it's only different parameters) |
| Tutorial        | A scripted first run that teaches one aircraft and one runway, then a second type. | Yes |
| Rush / Night    | Faster curve, or reduced visibility.               | Later |
| Co-op           | Shared airspace over SharePlay.                    | Later |

## Maps

v1 ships with three maps. Each one adds one twist.

1. **Coastal Field.** One flight level. One long runway, one short runway and
   one helipad. Teaches the basics.
2. **Island Strip.** Two flight levels and crossing runways, so traffic
   landing on one runway crosses the other's approach. Moving one aircraft up
   a level is the clean way to handle a crossing.
3. **Mountain Valley.** Three flight levels. Peaks block the lower levels, so
   aircraft can also crash into terrain unless they're high enough to clear
   it.

Later: an aircraft carrier with a moving deck, a night airport, and a map with
wind.

## Scoring and progression

- **Score** is the number of aircraft landed. Landing streaks get visual
  feedback only, so the score stays simple.
- **Unlocks:** maps unlock by lifetime landings. Whether to do this or unlock
  everything from the start is an open question.
- **Game Center:** a leaderboard per map, a recurring daily leaderboard, and
  about 15 achievements (for example: 100 lifetime landings, three landings in
  three seconds, surviving five near-misses in one run).

## Look and feel

The goal is clean and attractive without being flashy.

- **Style:** a low-poly diorama with matte materials and soft daylight. On
  flat screens the camera is slightly tilted, which gives a miniature,
  tilt-shift feel.
- **Palette:** each map uses a restrained palette. Saturated colours are
  reserved for runway classes and warnings, so information that matters to
  play stands out.
- **Motion:** aircraft bank into turns, propellers spin, rotors blur, and a
  soft grounding shadow shows altitude. Jets get faint contrails. On maps
  with flight levels, a thin drop line connects each aircraft to its shadow.
- **UI:** SwiftUI with system materials (Liquid Glass on iOS and macOS 26,
  glass on visionOS) and SF Pro Rounded. The in-game HUD is minimal: score,
  best score and a pause button.
- **Audio:** a soft engine hum per aircraft (spatial on visionOS), a tower
  chime on landing, a warning beep, and ambient sound per map (wind, sea,
  birds). Calm optional music.
- **Attract mode:** behind the title menu, the airfield is live, with the
  autopilot landing traffic.

## Accessibility

- A glyph alongside every colour, and a chevron badge for flight level, so
  neither runway class nor height depends on colour.
- Relaxed mode and an adjustable game speed.
- Reduce Motion support: no camera shake or slow motion, and softer pulses.
- VoiceOver and Dynamic Type for all menus. During play, VoiceOver announces
  arrivals and conflicts, but drawing paths stays a visual skill.
- Haptics and sound toggles, and a left-handed HUD layout on iPhone.
