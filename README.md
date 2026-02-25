# Index Fragmentation Management with Cursors

## Overview

This project implements a cursor-based index maintenance script for Microsoft SQL Server.

The script scans all user tables in the currently connected database, evaluates index fragmentation levels, and applies the appropriate maintenance operation (REORGANIZE or REBUILD) based on predefined thresholds.

Compatible with SQL Server 2017 / 2019 / 2022.

---

## Context

Developed as part of the SQL course in the Data Engineering program at Nackademin (Higher Vocational Education, Sweden).

The assignment focused on:

- Using cursors in a practical scenario
- Analyzing index fragmentation
- Applying dynamic index maintenance
- Producing an execution summary

---

## Technical Approach

### Cursor Logic

A cursor retrieves all user tables from `sys.tables` (excluding system tables).

Each table is processed sequentially, and its associated indexes are analyzed.

---

### Fragmentation Analysis

Fragmentation levels are retrieved using:

`sys.dm_db_index_physical_stats`

The script evaluates:

- Average fragmentation percentage
- Page count
- Index type (clustered / nonclustered)

---

### Maintenance Strategy

Fragmentation thresholds determine the action:

- Low fragmentation → No action
- Moderate fragmentation → `ALTER INDEX ... REORGANIZE`
- High fragmentation → `ALTER INDEX ... REBUILD`

Dynamic SQL is used to execute maintenance operations safely.

---

### Execution Summary

When the script completes, it outputs:

- Start time
- End time
- Total execution duration
- Number of tables checked
- Number of indexes checked
- Number of reorganized indexes
- Number of rebuilt indexes

This provides visibility similar to production maintenance jobs.

---

## Design Considerations

- Only user tables are included
- System objects are excluded
- Error handling is implemented
- Script is executable with a single F5 run
- Designed for repeatable execution

---

## Example Output

```
Started: 2026-01-01 10:00:00
Ended:   2026-01-01 10:02:15
Checked 120 tables and 345 indexes
12 reorganized
7 rebuilt
```
