# Claude.md — Product Blueprint
## Project: Calm Adaptive Fitness App (Working Title)

---

# 1. Product Vision

## Core Promise
> In under 10 seconds per day, tell the user what to do to stay on track with their health, without stress, complexity, or guilt.

---

## Core Emotional Outcome
Every interaction must leave the user feeling:

- "I’m doing okay"
- "I know what to do next"
- "I’m making progress"

---

## Positioning
This is NOT:
- A calorie tracker
- A workout library
- A hardcore coaching app

This IS:
> A calm, adaptive daily decision system for health and fitness

---

# 2. Core Product Principles (Non-Negotiable)

1. Clarity over complexity  
2. Guidance over control  
3. Consistency over perfection  
4. Progress over precision  
5. Calm over pressure  

---

# 3. Core Features

## 3.1 Daily Readiness

### Inputs
- HRV (3-day average)
- Resting Heart Rate (3-day average)
- Sleep duration

### Output
- 🟢 Train
- 🟡 Go lighter
- 🔴 Recover

### Rules
- No single-day overreaction
- Always explain in one sentence
- Allow user override

---

## 3.2 Training System

### Templates
- 2–3 days → Full Body
- 4 days → Upper/Lower
- 5+ days → Push/Pull/Legs

### Structure
- 4–6 exercises per session
- Movement-based (push/pull/squat/hinge)

---

## 3.3 Progressive Overload Engine

### Per Exercise
Track:
- Weight
- Reps
- Sets

### Calculation
- e1RM = weight × (1 + reps / 30)

---

### Progression Rules

IF:
- All sets hit top rep range → increase weight

ELSE IF:
- Reps increased → keep weight

ELSE:
- Maintain and build

---

### Plateau Detection

Trigger:
- No improvement for 3 sessions

Action:
- Reduce weight by 5–8%
- Rebuild reps

---

## 3.4 Nutrition Tracking

### Input
- Photo (primary)
- Optional:
  - Portion size (S/M/L)
  - Oil/sauce (yes/no)

---

### Output
- Calories range
- Protein range (priority)
- Confidence level

---

### Targets
- Protein: ~2.2g/kg bodyweight
- Calories: TDEE - deficit

---

### UX
- Show ranges, not exact numbers
- Focus on:
  - "On track"
  - "Slight adjustment"
  - "Off track"

---

# 4. Daily User Flow

## Morning
- Readiness shown
- Workout suggestion
- 1 key action

---

## During Day
- Meal logging (photo)
- Protein guidance

---

## Post Workout
- Log sets (tap-based)
- Show improvement

---

## Evening
- Daily summary
- Reinforcement

---

# 5. UX Design Principles

## Rules

- <3 seconds to understand state
- <60 seconds to log workout
- <10 seconds to log meal

---

## Tone

Always:
- Calm
- Supportive
- Short
- Non-judgmental

---

## Replace:

| Bad UX | Good UX |
|------|--------|
| "You failed" | "Slight adjustment" |
| "Missed workout" | "Pick it up tomorrow" |
| "Over calories" | "Balance tomorrow" |

---

# 6. Today Screen Structure

## Sections

1. Greeting
2. Readiness Card
3. Workout Plan
4. Nutrition Status
5. Momentum
6. Micro-win

---

## Must Answer

- Can I train?
- What should I do?
- Am I doing okay?

---

# 7. Logging System

## Workout Logging

- Pre-filled exercises
- Suggested weights
- Tap-based reps input
- Auto progression

---

## Nutrition Logging

- Photo-first
- 1–2 taps max
- Repeat meals

---

## Health Data

- Pulled automatically via HealthKit
- No manual entry required

---

# 8. Retention System

## Daily Loop

Trigger → Action → Reward → Progress

---

## Key Mechanics

### 1. Momentum (not streaks)
- 2/3 pillars = success

### 2. Micro-wins
- Always show progress

### 3. Identity
- "You are consistent"

---

## Avoid

- Punishment
- Fragile streaks
- Over-precision

---

# 9. AI Strategy (Claude)

## Use AI for:

- Food estimation
- Weekly summaries
- Occasional insights

---

## Do NOT use AI for:

- Readiness logic
- Progression logic
- Daily decisions

---

## Food Prompt (System)

You estimate macros conservatively.  
Return ranges.  
Protein is priority.  
Output JSON only.

---

## Coaching Prompt

Tone:
- Supportive
- Short
- Practical

Output:
- 1 insight
- 1 encouragement
- 1 next step

---

# 10. Tech Architecture

## Frontend
- SwiftUI (iOS)
- WatchOS support

---

## Data
- SwiftData / CoreData
- HealthKit integration

---

## Backend (minimal)
- API for food recognition
- Auth + subscriptions

---

## AI
- Claude Haiku (default)
- Claude Sonnet (food + summaries)

---

## Cost Strategy
- Target: €1–€2 per user/month
- Cache aggressively
- Limit heavy usage

---

# 11. Pricing

## Recommended

- €7.99/month
- €59/year
- 7-day free trial

---

## Reasoning

- Strong perceived value
- Healthy margins
- Better retention than €5

---

# 12. Onboarding

## Steps

1. Goal (default: fat loss)
2. Training days
3. Gym type
4. HealthKit connect

---

## Output immediately:

- Readiness
- Today plan

---

## Rule
No tutorials. No friction.

---

# 13. First 7 Days (Habit Formation)

## Day 1
- Clarity

## Day 2
- First progress signal

## Day 3
- Introduce nutrition

## Day 4
- Identity reinforcement

## Day 5
- Adaptive behavior

## Day 6
- Consistency reward

## Day 7
- Weekly summary

---

# 14. Key Metrics

## Primary KPI
- % users active 5/7 days (week 1)

---

## Secondary
- Workout completion rate
- Meal logging frequency
- Retention (D7, D30)

---

# 15. What Will Kill This App

- Too many features
- Too much AI
- Too much input
- Poor accuracy without UX buffering
- Breaking emotional trust

---

# 16. Final Definition

This app succeeds if:

> It is easier to use than doing nothing

---

# 17. Final Test

After a bad day, user opens app.

If they feel:

"I’m okay, let’s keep going"

→ Product is working

If not:

→ Redesign immediately

---
