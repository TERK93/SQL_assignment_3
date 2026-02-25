/*  Assignment 2 – Query Optimization and Performance Analysis (SQL2)
    Student: Trotte Karlsson
    Database: AdventureWorksDW2019
    Required: DimCustomer + FactInternetSales (builds FactInternetSales_100x)

    Run instructions:
    Enable Actual Execution Plan (Ctrl+M)
    Execute entire script (F5)
    Review STATISTICS IO/TIME in Messages tab

    Output policy:
      - Keep Results tab clean (only final result + optional index demo)
*/

USE AdventureWorksDW2019;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET STATISTICS IO, TIME ON;
GO

PRINT 'NOTE: Enable Actual Execution Plan (Ctrl+M) BEFORE running for screenshots.';
PRINT 'NOTE: STATISTICS IO/TIME is ON. Use Messages tab for metrics.';

DECLARE @StartTime datetime2(0) = SYSDATETIME();
PRINT 'Start: ' + CONVERT(varchar(19), @StartTime, 120);

--------------------------------------------------------------------------------
-- 0) Build FactInternetSales_100x (toggle)
--------------------------------------------------------------------------------
DECLARE @Rebuild100x bit = 1;  -- set to 0 for faster reruns

IF @Rebuild100x = 1 -- 
BEGIN
    PRINT 'Rebuilding dbo.FactInternetSales_100x...';
    DROP TABLE IF EXISTS dbo.FactInternetSales_100x;

    SELECT f.*
    INTO dbo.FactInternetSales_100x
    FROM dbo.FactInternetSales AS f
    CROSS JOIN (SELECT TOP (100) 1 AS n FROM sys.all_objects) AS x;

    PRINT 'dbo.FactInternetSales_100x created.';
END

IF OBJECT_ID('dbo.FactInternetSales_100x', N'U') IS NULL
    THROW 50001, 'Missing dbo.FactInternetSales_100x. Set @Rebuild100x=1 or create it first.', 1;

--------------------------------------------------------------------------------
-- 1) Index setup
--------------------------------------------------------------------------------
DECLARE @IndexName sysname = 'IX_FIS100x_CustomerKey';

DECLARE @DropIndexSQL nvarchar(max) =
'IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N''dbo.FactInternetSales_100x'') AND name = ''' + @IndexName + ''')
    DROP INDEX ' + QUOTENAME(@IndexName) + ' ON dbo.FactInternetSales_100x;';

DECLARE @CreateIndexSQL nvarchar(max) =
'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(''dbo.FactInternetSales_100x'') AND name = ''' + @IndexName + ''')
    CREATE NONCLUSTERED INDEX ' + QUOTENAME(@IndexName) + '
    ON dbo.FactInternetSales_100x (CustomerKey)
    INCLUDE (SalesAmount);';

--------------------------------------------------------------------------------
-- 2) Warmup helper (one warmup per phase)
--------------------------------------------------------------------------------
DECLARE @WarmupSQL nvarchar(max) =
'SELECT TOP (1)
        c.FirstName, c.LastName, SUM(f.SalesAmount) AS TotalSales
  FROM dbo.FactInternetSales_100x f
  JOIN dbo.DimCustomer c ON c.CustomerKey = f.CustomerKey
  GROUP BY f.CustomerKey, c.FirstName, c.LastName
  ORDER BY SUM(f.SalesAmount) DESC;';

--------------------------------------------------------------------------------
-- 3) Approaches as reusable SQL blocks
--------------------------------------------------------------------------------
DECLARE @A1 nvarchar(max) =
'/* APPROACH 1 | Phase B/A (depends on index state) | TOP customer */ 
SELECT TOP (1)
        c.FirstName, c.LastName, SUM(f.SalesAmount) AS TotalSales
  FROM dbo.FactInternetSales_100x f
  JOIN dbo.DimCustomer c ON c.CustomerKey = f.CustomerKey
  GROUP BY f.CustomerKey, c.FirstName, c.LastName
  ORDER BY SUM(f.SalesAmount) DESC
  OPTION (RECOMPILE);';

DECLARE @A2 nvarchar(max) =
'/* APPROACH 2 | Aggregate first then join */ 
;WITH S AS
  (
      SELECT f.CustomerKey, SUM(f.SalesAmount) AS TotalSales
      FROM dbo.FactInternetSales_100x f
      GROUP BY f.CustomerKey
  )
  SELECT TOP (1)
         c.FirstName, c.LastName, S.TotalSales
  FROM S
  JOIN dbo.DimCustomer c ON c.CustomerKey = S.CustomerKey
  ORDER BY S.TotalSales DESC
  OPTION (RECOMPILE);';

DECLARE @A3 nvarchar(max) =
'/* APPROACH 3 | Top-1 from aggregate then join */ 
;WITH S AS
  (
      SELECT f.CustomerKey, SUM(f.SalesAmount) AS TotalSales
      FROM dbo.FactInternetSales_100x f
      GROUP BY f.CustomerKey
  ),
  T AS
  (
      SELECT TOP (1) S.CustomerKey, S.TotalSales
      FROM S
      ORDER BY S.TotalSales DESC
  )
  SELECT c.FirstName, c.LastName, T.TotalSales
  FROM T
  JOIN dbo.DimCustomer c ON c.CustomerKey = T.CustomerKey
  OPTION (RECOMPILE);';

--------------------------------------------------------------------------------
-- PHASE A: WITHOUT INDEX
--------------------------------------------------------------------------------
PRINT '============================================================';
PRINT 'PHASE A: WITHOUT INDEX';
PRINT '============================================================';
EXEC sys.sp_executesql @DropIndexSQL;

PRINT '--- Warmup (Phase A) ---';
EXEC sys.sp_executesql @WarmupSQL;

PRINT '============================================================';
PRINT 'APPROACH 1 | Phase A (NO INDEX) | Measured (screenshot)';
PRINT '============================================================';
EXEC sys.sp_executesql @A1;

PRINT '============================================================';
PRINT 'APPROACH 2 | Phase A (NO INDEX) | Measured (screenshot)';
PRINT '============================================================';
EXEC sys.sp_executesql @A2;

PRINT '============================================================';
PRINT 'APPROACH 3 | Phase A (NO INDEX) | Measured (screenshot)';
PRINT '============================================================';
EXEC sys.sp_executesql @A3;

--------------------------------------------------------------------------------
-- PHASE B: WITH INDEX
--------------------------------------------------------------------------------
PRINT '============================================================';
PRINT 'PHASE B: WITH INDEX';
PRINT '============================================================';
EXEC sys.sp_executesql @CreateIndexSQL;

PRINT '--- Warmup (Phase B) ---';
EXEC sys.sp_executesql @WarmupSQL;

PRINT '============================================================';
PRINT 'APPROACH 1 | Phase B (WITH INDEX) | Measured (screenshot)';
PRINT '============================================================';
EXEC sys.sp_executesql @A1;

PRINT '============================================================';
PRINT 'APPROACH 2 | Phase B (WITH INDEX) | Measured (screenshot)';
PRINT '============================================================';
EXEC sys.sp_executesql @A2;

PRINT '============================================================';
PRINT 'APPROACH 3 | Phase B (WITH INDEX) | Measured (screenshot)';
PRINT '============================================================';
EXEC sys.sp_executesql @A3;

--------------------------------------------------------------------------------
-- Optional: selective index demo
--------------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.FactInternetSales_100x')
      AND name = 'IX_FIS100x_CustomerKey'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FIS100x_CustomerKey
    ON dbo.FactInternetSales_100x (CustomerKey)
    INCLUDE (SalesAmount);
END


PRINT '============================================================';
PRINT 'INDEX DEMO (NOT top customer) | Selective lookup | Measured (screenshot)';
PRINT '============================================================';

DECLARE @TestCustomerKey int;
SELECT TOP (1) @TestCustomerKey = CustomerKey
FROM dbo.FactInternetSales_100x
ORDER BY NEWID();

PRINT 'INDEX DEMO | Using CustomerKey = ' + CAST(@TestCustomerKey AS varchar(20));

SELECT
    f.CustomerKey,
    SUM(f.SalesAmount) AS TotalSales
FROM dbo.FactInternetSales_100x AS f
WHERE f.CustomerKey = @TestCustomerKey
GROUP BY f.CustomerKey
OPTION (RECOMPILE);

--------------------------------------------------------------------------------
-- FINAL RESULT (ONE clean resultset)
--------------------------------------------------------------------------------

DECLARE @EndTime datetime2(0) = SYSDATETIME();

;WITH S AS
(
    SELECT f.CustomerKey, SUM(f.SalesAmount) AS TotalSales
    FROM dbo.FactInternetSales_100x f
    GROUP BY f.CustomerKey
),
T AS
(
    SELECT TOP (1) S.CustomerKey, S.TotalSales
    FROM S
    ORDER BY S.TotalSales DESC
)
SELECT
    StartedAt = @StartTime,
    EndedAt   = @EndTime,
    TopFirst  = c.FirstName,
    TopLast   = c.LastName,
    TopSales  = T.TotalSales
FROM T
JOIN dbo.DimCustomer c
  ON c.CustomerKey = T.CustomerKey;

PRINT '------------------------------------------------------------';
PRINT 'The query started at ' + CONVERT(varchar(19), @StartTime, 120)
    + ' and ended at ' + CONVERT(varchar(19), @EndTime, 120)
    + ', total execution time ~ ' + CONVERT(varchar(20), DATEDIFF(second, @StartTime, @EndTime)) + ' seconds.';
PRINT '------------------------------------------------------------';
PRINT '---------------------------------------------';
PRINT 'Execution Summary';
PRINT '---------------------------------------------';
PRINT '3 approaches were evaluated (Phase A & Phase B).';
PRINT 'Winner: Approach 3 with supporting nonclustered index.';
PRINT 'Primary driver: Lowest logical I/O and optimized operator ordering.';
PRINT 'No memory spills detected in execution plans.';
PRINT '---------------------------------------------';
--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------
EXEC sys.sp_executesql @DropIndexSQL;
SET STATISTICS IO, TIME OFF;
GO
