# GigSmart Relative Time Shifting Analysis

**Date:** 2026-01-15
**Feature:** Dynamic DateTime/Date parsing with relative shifts and modifiers

---

## Overview

GigSmart has implemented a sophisticated relative time parsing system that allows GraphQL clients to express dates and times using intuitive relative syntax. This feature dramatically improves the developer experience for temporal queries.

## Feature Capabilities

### 1. ISO8601 Duration Shifts

Uses `+` or `-` prefix with ISO8601 duration format:

```
+P1D          → Tomorrow (1 day from now)
-P1M          → 1 month ago
+P1Y2M3D      → 1 year, 2 months, 3 days from now
+P1DT2H30M    → 1 day, 2 hours, 30 minutes from now
-P7D          → 7 days ago (last week)
```

**ISO8601 Duration Components:**
- `P` = Period prefix (required)
- Years: `1Y`, `2Y`, etc.
- Months: `1M`, `3M`, etc.
- Weeks: `1W`, `4W`, etc.
- Days: `1D`, `30D`, etc.
- `T` = Time separator (before hours/minutes/seconds)
- Hours: `2H`, `24H`, etc.
- Minutes: `30M`, `45M`, etc.
- Seconds: `15S`, `30S`, etc.

### 2. Relative to Specific Date

Append shift to any ISO date/datetime:

```
2024-09-16+P1D                      → Sept 17, 2024
2024-09-16T23:03:39+00:00+P1D      → Sept 17, 2024 at 23:03:39 UTC
2024-09-16-P3M                      → June 16, 2024 (3 months before)
```

### 3. Beginning/End Modifiers

Snap to beginning (`^`) or end (`$`) of time period:

```
^PY     → Beginning of this year (Jan 1, 00:00:00)
$PY     → End of this year (Dec 31, 23:59:59)
^PQ     → Beginning of this quarter
$PQ     → End of this quarter
^PM     → Beginning of this month
$PM     → End of this month
^PW     → Beginning of this week (Monday 00:00:00)
$PW     → End of this week (Sunday 23:59:59)
^PD     → Beginning of today (00:00:00)
$PD     → End of today (23:59:59)
```

### 4. Combining Shifts and Modifiers

Chain multiple operations:

```
2024-09-16-P3M^PD
→ Sept 16, 2024
→ Minus 3 months = June 16, 2024
→ Beginning of day = June 16, 2024 at 00:00:00

2024-09-16-P1D^PM
→ Sept 16, 2024
→ Minus 1 day = Sept 15, 2024
→ Beginning of month = Sept 1, 2024 at 00:00:00

-P1M^PD
→ 1 month ago from now
→ Beginning of that day

2024-09-16-P1M-P1M
→ Sept 16, 2024
→ Minus 2 months = July 16, 2024
```

### 5. Fallback to Standard ISO8601

If no relative syntax is detected, falls back to standard ISO8601 parsing:

```
2024-09-16T23:03:39+00:00    → Standard datetime
2024-09-16                    → Standard date
2024-W38                      → ISO week format
2024-259                      → ISO ordinal date
```

---

## Use Cases

### 1. Analytics Queries

```graphql
query RecentEngagements {
  engagements(where: {
    startTime: { _gte: "-P30D" }  # Last 30 days
  }) {
    nodes {
      id
      startTime
    }
  }
}
```

### 2. Quarterly Reports

```graphql
query QuarterlyRevenue {
  engagements(where: {
    startTime: { _gte: "^PQ" }  # This quarter
    endTime: { _lte: "$PQ" }
  }) {
    aggregate {
      sum {
        totalPay
      }
    }
  }
}
```

### 3. Comparing Periods

```graphql
query LastMonthVsThisMonth {
  lastMonth: engagements(where: {
    startTime: { _gte: "-P1M^PM" }  # Beginning of last month
    endTime: { _lte: "-P1M$PM" }    # End of last month
  }) {
    aggregate { sum { totalPay } }
  }

  thisMonth: engagements(where: {
    startTime: { _gte: "^PM" }      # Beginning of this month
    endTime: { _lte: "$PM" }        # End of this month
  }) {
    aggregate { sum { totalPay } }
  }
}
```

### 4. Future Scheduling

```graphql
mutation ScheduleGig {
  createGig(input: {
    startTime: "+P7D^PD"  # Next week Monday at 00:00:00
    endTime: "+P7DT8H"    # Next week at 08:00:00
  }) {
    gig {
      id
      startTime
    }
  }
}
```

---

## Implementation Architecture

### Current GigSmart Implementation

```
┌─────────────────────────────────────────────┐
│ GraphQL DateTime Scalar                     │
│ (parse input from client)                   │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ DynamicParser                               │
│ - Tries multiple ISO8601 formats            │
│ - Falls back to RelativeParser              │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ RelativeParser                              │
│ - Regex extracts: time, operator, duration  │
│ - Regex extracts: modifier, period          │
│ - Parses base time (recursively if needed)  │
│ - Applies shift using Timex.shift/2         │
│ - Applies modifier using Timex functions    │
└─────────────────────────────────────────────┘
```

### Key Components

**1. Regex Pattern:**
```regex
(
  # Shift operator
  (?P<operator>\+|-)
  (?:P(?P<years>\d+Y)?(?P<months>\d+M)?(?P<weeks>\d+W)?(?P<days>\d+D)?)?
  (?:T(?P<hours>\d+H)?(?P<minutes>\d+M)?(?P<seconds>\d+S)?)?
  $
  |
  # Modifier
  (?P<modifier>\^|\$)
  (?:P(?P<mod_period>(Y|Q|M|W|D)))?
  $
)
```

**2. Parsing Algorithm:**
1. Extract regex captures (operator, duration parts, modifier, period)
2. Extract base time (everything before the shift/modifier)
3. Parse base time recursively (could have its own shift/modifier)
4. If operator present:
   - Parse duration components (years, months, etc.)
   - Invert if operator is `-`
   - Apply shift using Timex
5. If modifier present:
   - Apply beginning/end function for period

**3. Dependencies:**
- **Timex** - Date/time shifting and manipulation
- **Railway** - Elegant error handling with `~>` operator

---

## Benefits for GreenFairy

### 1. Significantly Better DX

**Before (absolute dates):**
```graphql
# Client must calculate dates
query {
  engagements(where: {
    startTime: { _gte: "2026-01-01T00:00:00Z" }
    endTime: { _lte: "2026-01-31T23:59:59Z" }
  })
}
```

**After (relative syntax):**
```graphql
# Intuitive and maintainable
query {
  engagements(where: {
    startTime: { _gte: "^PM" }
    endTime: { _lte: "$PM" }
  })
}
```

### 2. Reduces Client-Side Logic

Clients don't need to:
- Calculate date arithmetic
- Handle timezone conversion
- Implement beginning/end of period logic
- Deal with month/year boundary cases

### 3. Query Reusability

Same query works across time periods:

```graphql
# This query is valid today, tomorrow, next year
query LastMonthEngagements {
  engagements(where: {
    startTime: { _gte: "-P1M^PM" }
    endTime: { _lte: "-P1M$PM" }
  })
}
```

### 4. Self-Documenting

The syntax is intuitive:
- `-P30D` clearly means "30 days ago"
- `^PY` clearly means "beginning of year"
- More readable than epoch timestamps or calculated dates

---

## Proposed GreenFairy Implementation

### Phase 1: Core Parser Module

Create `GreenFairy.Temporal.RelativeParser`:

```elixir
defmodule GreenFairy.Temporal.RelativeParser do
  @moduledoc """
  Parses relative time expressions for DateTime, Date, and NaiveDateTime.

  Supports:
  - ISO8601 duration shifts: +P1D, -P3M, +P1Y2M3DT4H30M
  - Beginning/end modifiers: ^PY, $PM, ^PD
  - Combinations: 2024-09-16-P3M^PD
  - Fallback to standard ISO8601
  """

  def parse_datetime(string)
  def parse_date(string)
  def parse_naive_datetime(string)
end
```

### Phase 2: Update GraphQL Scalars

Update built-in temporal scalars to use RelativeParser:

**lib/green_fairy/scalars/date_time.ex:**
```elixir
scalar :datetime do
  description """
  DateTime in UTC with ISO8601 format.

  Supports relative expressions:
  - +P1D = tomorrow
  - -P30D = 30 days ago
  - ^PM = beginning of this month
  - 2024-09-16-P3M^PD = 3 months before Sept 16 at start of day
  """

  parse fn input ->
    case input do
      %Absinthe.Blueprint.Input.String{value: value} ->
        GreenFairy.Temporal.RelativeParser.parse_datetime(value)
      _ ->
        :error
    end
  end

  serialize &DateTime.to_iso8601/1
end
```

### Phase 3: CQL Integration

The relative parsing happens at GraphQL input layer, so CQL operators receive actual DateTime/Date values. No changes needed to CQL operators themselves.

**Query Flow:**
```
GraphQL Input: "-P30D"
      ↓
RelativeParser: Converts to DateTime
      ↓
CQL Operator: Receives DateTime struct
      ↓
Ecto Query: WHERE date >= $1
      ↓
Database: Standard SQL date comparison
```

### Phase 4: Documentation

Add comprehensive examples:
- Common patterns (last 30 days, this quarter, etc.)
- Chaining multiple operations
- Combining with other CQL operators
- Best practices

---

## Implementation Considerations

### 1. Timex Dependency

**Option A:** Add Timex as GreenFairy dependency
- **Pro:** Battle-tested, feature-rich
- **Pro:** Handles all edge cases (leap years, DST, etc.)
- **Con:** Adds dependency

**Option B:** Use Elixir's Calendar module
- **Pro:** No extra dependency
- **Con:** More manual work for shifts
- **Con:** Need to implement quarter logic

**Recommendation:** Use Timex. The relative time feature provides significant value, and Timex is well-maintained.

### 2. Error Messages

Provide clear feedback for invalid syntax:

```elixir
{:error, "Invalid duration format: expected +P1D, got +1D"}
{:error, "Invalid modifier: expected ^PY, ^PQ, ^PM, ^PW, or ^PD"}
{:error, "Cannot parse base date: '2024-99-99' is not a valid date"}
```

### 3. Testing Strategy

Test coverage must include:
- All shift operators (+/-)
- All duration components (years, months, weeks, days, hours, minutes, seconds)
- All modifier periods (Y, Q, M, W, D)
- Chaining multiple operations
- Edge cases (leap years, month boundaries, DST transitions)
- Invalid input handling

### 4. Performance

Parsing is done once per request at GraphQL input layer. Performance impact is minimal:
- Regex matching: ~microseconds
- Timex calculations: ~microseconds
- No runtime overhead in database queries

---

## Migration Path for GigSmart

### Current State
GigSmart already uses this in their GraphQL scalars:
- `GigSmartGql.Scalars.DateTime`
- `GigSmartGql.Scalars.Date`
- `GigSmartGql.Scalars.NaiveDateTime`

### After GreenFairy Implementation

1. **Remove custom scalar definitions** - Use GreenFairy's built-in scalars
2. **Remove DynamicParser and RelativeParser** - Use GreenFairy's implementation
3. **Zero client changes** - Same query syntax works identically
4. **Bonus:** All GreenFairy users get this feature automatically

---

## Comparison with Other Frameworks

### Hasura
- No relative date support
- Clients must calculate dates
- Extension possible via custom functions

### PostGraphile
- No built-in relative date support
- Can add via computed columns

### GigSmart/GreenFairy
- **Native support** for relative dates
- Clean, intuitive syntax
- Part of core scalar types

This makes GreenFairy's temporal handling **best-in-class** among GraphQL frameworks.

---

## Decision

**Should we add this to GreenFairy?**

### ✅ **YES - High Priority**

**Reasoning:**
1. **High Value** - Dramatically improves DX for 90% of date queries
2. **Production Proven** - GigSmart uses this extensively
3. **Low Risk** - Self-contained parsing layer, no breaking changes
4. **Differentiator** - No other GraphQL framework has this
5. **Reusable** - Benefits all GreenFairy users

**Implementation Order:**
1. JSON/INET CQL scalars (database features)
2. **Relative Time Parser** (high-value DX feature)
3. Adapter architecture refactor

---

## Example Queries Enabled

```graphql
# Analytics dashboard
query Dashboard {
  # This week's revenue
  thisWeek: engagements(where: { startTime: { _gte: "^PW" } }) {
    aggregate { sum { totalPay } }
  }

  # Last week's revenue
  lastWeek: engagements(where: {
    startTime: { _gte: "-P1W^PW" }
    endTime: { _lte: "-P1W$PW" }
  }) {
    aggregate { sum { totalPay } }
  }

  # Year to date
  ytd: engagements(where: { startTime: { _gte: "^PY" } }) {
    aggregate { sum { totalPay } }
  }

  # Last 30 days
  last30Days: engagements(where: { startTime: { _gte: "-P30D" } }) {
    nodes { id startTime totalPay }
  }
}
```

This query is always correct, regardless of when it runs. No client-side date calculation needed!
