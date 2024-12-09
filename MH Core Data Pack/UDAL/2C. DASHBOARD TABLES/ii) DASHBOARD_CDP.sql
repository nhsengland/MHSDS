IF OBJECT_ID ('[MHDInternal].[DASHBOARD_CDP]') IS NOT NULL
DROP TABLE [MHDInternal].[DASHBOARD_CDP]

SELECT * 
  INTO [MHDInternal].[DASHBOARD_CDP]
  FROM [MHDInternal].[DASHBOARD_CDP_QA]

IF OBJECT_ID ('[MHDInternal].[DASHBOARD_CDP_QA]') IS NOT NULL
DROP TABLE [MHDInternal].[DASHBOARD_CDP_QA]

-- Run Data for 'Backing Data' files

-- 19/20

SELECT * FROM [MHDInternal].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2019-04-01' AND '2020-03-31'

-- 20/21

SELECT * FROM  [MHDInternal].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2020-04-01' AND '2021-03-31'

-- 21/22

SELECT * FROM  [MHDInternal].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2021-04-01' AND '2022-03-31'

-- 22/23

SELECT * FROM [MHDInternal].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2022-04-01' AND '2023-03-31'

-- 23/24

SELECT * FROM [MHDInternal].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2023-04-01' AND '2024-03-31'

/*###############################################################################################################################################
CREATE BACKUP WITH RUN MONTH AND DATA MONTH
This code creates a snapshot backup file of [MHDInternal].[DASHBOARD_CDP] which can be used to restore data to the staging
tables.
The backup table name is DASHBOARD_CDP_YYYYMM_YYYYMM, the first datestamp is the month in which the backup is created and the second 
datestamp is the data month represneted by the date of latest MHSDS measure data. If a backup table exists with the same datestamps it is 
deleted and replaced ensuring the most recent iteration is available.
################################################################################################################################################*/

DECLARE @CURMONTH INT 
PRINT @CURMONTH
DECLARE @BACKUPTABLE AS VARCHAR(100)
DECLARE @sqlDrop NVARCHAR(MAX)
DECLARE @sqlCreate NVARCHAR(MAX)
DECLARE @MAX_MHSDS NVARCHAR(MAX)

--Current month datestamp
SET @CURMONTH = (SELECT FORMAT(GETDATE(),'yyyyMM'))

--Latest CDP_M01 to define data month datestamp
Set @MAX_MHSDS = (select 
CONCAT('_',Year([reporting_period]),Format(MONTH([reporting_period]),'00'))
from 
(select MAX([reporting_period]) reporting_period from [MHDInternal].[DASHBOARD_CDP]
where CDP_MEASURE_ID='CDP_M01') a)

--Define backup table name
--NB to simplify things square brackets are not included as inappropriate bracketing is applied automatically which
--has to be removed when creating the executable SQL 
set @BACKUPTABLE='NHSE_Sandbox_Policy.DBO.DASHBOARD_CDP_' + FORMAT(GETDATE(),'yyyyMM')+ QUOTENAME(@MAX_MHSDS)
-- Construct the dynamic SQL statement to drop existing table if required
SET @sqlDrop = 'Drop Table if exists ' + QUOTENAME(@BACKUPTABLE)
SET @sqlDrop = REPLACE(REPLACE(@sqlDrop,'[',''),']','')--Drop all erroneously applied brackets 

-- Construct the dynamic SQL statement to create backup table
SET @sqlCreate = 'Select * INTO ' + QUOTENAME(@BACKUPTABLE) + ' from NHSE_Sandbox_Policy.dbo.DASHBOARD_CDP'
SET @sqlCreate = REPLACE(REPLACE(@sqlCreate,'[',''),']','')--Drop all erroneously applied brackets 

-- Execute the dynamic SQL
EXEC sp_executesql @sqlDrop
PRINT @sqlDrop  --Displays script executed
EXEC sp_executesql @sqlCreate
PRINT @sqlCreate --Displays script executed
