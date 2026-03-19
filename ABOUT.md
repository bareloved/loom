# Loom

**A quiet time tracker that lives in your menu bar.**

Loom watches what app you're using and automatically logs your time to your Mac's calendar. No manual timers, no clicking start/stop every time you switch tasks. Just start a session, say what you're working on, and Loom handles the rest.

## What it does

When you start a session, you pick a category — like Coding, Music, or Design — and optionally write what you're working on ("fixing the login bug", "mixing track 3", etc.).

From there, Loom quietly monitors which app is in the foreground. It groups your time into sessions and writes them as events to a dedicated "Loom" calendar, so when you open Calendar at the end of the day, you can see exactly where your time went.

## How it keeps you focused

Loom knows which apps belong to which category. If you're in a Coding session and you drift to YouTube for too long, it'll pop up a gentle nudge asking if you want to get back on track or keep going.

If you do get distracted, Loom logs it. When the session ends, your calendar event will show what pulled you away and for how long — like "Distractions: Safari (3m 20s)". No judgement, just awareness.

## The smart bits

- **It ignores quick switches.** Glancing at Slack for 30 seconds won't start a new session. Loom waits 5 minutes before deciding you've actually switched activities.
- **It handles idle time.** Walk away from your Mac and Loom pauses automatically. Come back and it asks if you want to resume or start fresh.
- **It reads browser tabs.** If you're in Safari or Chrome, Loom can categorize based on the URL — so Stack Overflow counts as Coding, not Browsing.

## What you see

- A small icon in the menu bar with a live timer
- A dropdown showing your current session and focus goals
- A main window with your daily timeline, weekly calendar view, and stats

## What ends up in your calendar

Each session becomes a calendar event:
- **Title:** the category (and your intention if you set one)
- **Duration:** when you started and stopped
- **Notes:** your intention + any distractions with how long each lasted

## Setup

Loom needs two permissions:
1. **Accessibility** — to read window titles and browser URLs
2. **Calendar** — to create the tracking events

It runs as a menu bar app (no dock icon) and uses a global hotkey (Option+Shift+T) to quickly pause/resume.

## Who it's for

Anyone who wants to understand where their time goes without the friction of manual tracking. It's especially useful if you work across many apps and want an honest picture of your day.
