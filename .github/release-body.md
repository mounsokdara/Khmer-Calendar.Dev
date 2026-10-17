## Changes log:
**Khmer Calendar V1.0.4:**

## Added:
- Activity XML
- Text stroke on months grids
- Full calendar details for widget
- A ring overlay to mark today (the current day) in months
- More filters for the Events tab

## Bug fixes:
- The highlight overwrote the event color of the calendar grid text
- The navigation bar always stayed black
- Vibration is now included only on mobile devices; other devices (Windows, macOS, Linux, etc.) no longer load it
- Widget did not load calendar events on older dates properly
- Snackbar stayed behind the navigation bar (z-index) when going to different pages, so you couldn't read it

## Improvements:
- Widget style
- About page layout
- Months widget: instead of the boring arrow buttons, we now use a scroll picker for a better user experience
- Instead of re-inserting the scroll picker sounds every time, we replay them to reduce lag
- Scroll picker is now more curved
- Sparkle ripple is now applied to every build
- Events tab has no scrolling limit at certain years anymore
- Cut the empty noise at the start of the audio, leaving only the clip that has sound
