======================================================================================================================================================================================================--
-- SPC CHARTS SQL QUERY v2.5
--====================================================================================================================================================================================================--
--
-- This SQL query is used to create statistical process control (SPC) charts
-- The chart types available are XmR (along with Pareto), T, and G
-- The output table can be used with the accompanying Power BI template to view the charts
-- The latest version of this, the accompanying tools, and the how-to guide can be found at: https://future.nhs.uk/MDC/view?objectId=28387280
--
-- The query is split into multiple steps:
--     • Step 1: This step is for initial setup
--     • Step 2: This step is for custom settings
--     • Step 3: This step is where the metric and raw data are inserted, and optionally baseline and target data too
--     • Step 4: This step is where the SPC calculations are performed, including special cause rules and icons
--     • Step 5: This step is where warnings are calculated and returned, if turned on
--     • Step 6: This step is where the SPC data is returned
--     • Step 7: This step is for clear-up
--
-- Steps 1, 4-5, and 7 are to be left as they are
-- Steps 2-3 are to be changed, and there is information at the beginning of these steps detailing what to change and which warnings are checked in Step 5
-- Step 6 only needs to be changed by storing the output in a table if the accompanying Power BI template is used and connected that way
--
-- At the end of each step, a message is printed so that progress can be monitored
-- At the end of the query, Column Index details all the columns used throughout the query
--
-- 'Partition' refers to where a chart is broken up by recalculation of limits or a baseline
-- Where no recalculation of limits is performed or baseline set, a chart has a single partition
--
-- This version has been tested on SQL Server 2012 and is not compatible with older versions (use SELECT @@VERSION to check your version)
-- Alternative versions that support older versions can be shared and found at: https://future.nhs.uk/MDC/view?objectId=30535408
--
-- For queries and feedback, please email england.improvementanalyticsteam@nhs.net and quote the name and version number

------------------------------------ CORE DATA PACK ADJUSTEMENTS TO MDC CODE ---------------------------------
-- CDP Replaced FIELDS:
-- [Date]        with [Reporting_Period] 
-- [MetricName]  with [CDP_Measure_Name]
-- [MetricID]    with [CDP_Measure_ID]
-- [MetricOrder] with [CDP_Measure_ID]
-- [Group]       with [Org_Code]
-- [GroupParent] with [ICB_Code]
-- [Value]       with [Measure_Value]

-- DELETED SECTIONS:
-- STEP 4A: HIERARCHY     AS NOT REQUIRED
-- Table would be SPCCalculations as below if in uses
--#SPCCalculationsHierarchy								  with [MHDInternal].[temp_CDP_SPC_CalculationsHierarchy]

--REPLACED TEMP TABLES:
--#MetricData											  with [MHDInternal].[temp_CDP_SPC_MetricData]
--#RawData												  with [MHDInternal].[temp_CDP_SPC_RawData]
--#BaselineData											  with [MHDInternal].[temp_CDP_SPC_BaselineData]
--#TargetData											  with [MHDInternal].[temp_CDP_SPC_TargetData]
--##SPCCalculationsDistinctGroups						  with [MHDInternal].[temp_CDP_SPC_CalculationsDistinctGroups]
--#SPCCalculationsPartition								  with [MHDInternal].[temp_CDP_SPC_CalculationsPartition]
--#SPCCalculationsBaselineFlag						      with [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
--#SPCCalculationsBaseline								  with [MHDInternal].[temp_CDP_SPC_CalculationsBaseline]
--#SPCCalculationsAllTargets							  with [MHDInternal].[temp_CDP_SPC_CalculationsAllTargets]
--#SPCCalculationsSingleTarget							  with [MHDInternal].[temp_CDP_SPC_CalculationsSingleTarget]
--#SPCCalculationsMean									  with [MHDInternal].[temp_CDP_SPC_CalculationsMean]
--#SPCCalculationsMovingRange                             with [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange]
--#SPCCalculationsMovingRangeMean                         with [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
--#SPCCalculationsMovingRangeProcessLimit                 with [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeProcessLimit]
--#SPCCalculationsProcessLimits                           with [MHDInternal].[temp_CDP_SPC_CalculationsProcessLimits]
--#SPCCalculationsBaselineLimits                          with [MHDInternal].[temp_CDP_SPC_CalculationsBaselineLimits]
--#SPCCalculationsSpecialCauseSinglePoint                 with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseSinglePoint]
--#SPCCalculationsSpecialCauseShiftPrep                   with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShiftPrep]
--#SPCCalculationsSpecialCauseShiftPartitionCount         with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCausePartitionCount]
--#SPCCalculationsSpecialCauseShiftStartFlag              with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlag]
--#SPCCalculationsSpecialCauseShiftStartFlagCount         with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlagCount]
--#SPCCalculationsSpecialCauseShift                       with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShift]
--#SPCCalculationsSpecialCauseTrendPrep                   with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPrep]
--#SPCCalculationsSpecialCauseTrendPartitionCount         with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPartitionCount]
--#SPCCalculationsSpecialCauseTrendStartFlag              with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlag]
--#SPCCalculationsSpecialCauseTrendStartFlagCount         with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlagCount]
--#SPCCalculationsSpecialCauseTrend                       with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrend]
--#SPCCalculationsSpecialCauseTwoThreeSigmaPrep           with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaPrep]
--#SPCCalculationsSpecialCauseTwoThreeSigmaStartFlag      with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlag]
--#SPCCalculationsSpecialCauseTwoThreeSigmaStartFlagCount with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlagCount]
--#SPCCalculationsSpecialCauseTwoThreeSigma               with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigma]
--#SPCCalculationsSpecialCauseCombined                    with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
--#SPCCalculationsIcons                                   with [MHDInternal].[temp_CDP_SPC_CalculationsIcons]
--#SPCCalculationsRowCount                                with [MHDInternal].[temp_CDP_SPC_CalculationsRowCount]
--#Warnings                                               with [MHDInternal].[temp_CDP_SPC_Warnings]
--====================================================================================================================================================================================================--
-- STEP 1: SETUP
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step prepares the messages that display during execution 
-- and removes the temporary tables that will be used if they already exist
--
--====================================================================================================================================================================================================--

---- Prevent every row inserted returning a message 
--SET NOCOUNT ON

---- Prepare variable for messages printed at the end of each step
--DECLARE @PrintMessage NVARCHAR(MAX)

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 1  complete, setup'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 2A: SETTINGS: SPECIAL CAUSE
--====================================================================================================================================================================================================--
--
-- This step is where settings that determine how the process limits and special cause rules are calculated in Step 4 can be changed
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • @SettingSpecialCauseShiftPoints is not between 6 and 8 (inclusive)
--     • @SettingSpecialCauseTrendPoints is not between 6 and 8 (inclusive)
--
--====================================================================================================================================================================================================--

-- Removes moving range outliers from the calculation of the mean and process limits in XmR charts
-- ('1' = on | '0' = off)

--- RUN STEP 1/37
DECLARE @ExcludeMovingRangeOutliers BIT = 0

-- The number of non-ghosted points in a row within metric/group/partition combination all above or all below the mean to trigger the special cause rule of a shift
DECLARE @SettingSpecialCauseShiftPoints INT = 7

-- The number of non-ghosted points in a row within metric/group/partition combination either all increasing or all decreasing, including endpoints, to trigger the special cause rule of a trend
DECLARE @SettingSpecialCauseTrendPoints INT = 7

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 2a complete, settings: special cause'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 2B: SETTINGS: OTHER
--====================================================================================================================================================================================================--
--
-- This step is where various other settings can be changed, most of which are checked in Step 5
--
-- Warnings will be displayed, if turned on (first setting below) and:
--     • A chart has an insufficient number of points (set with @SettingMinimumPoints) and @SettingMinimumPointsWarning is turned on
--     • A partition in a chart has an insufficient number of points (set with @SettingMinimumPointsPartition)
--     • A partition in a chart has too many points (set with @SettingMaximumPointsPartition)
--     • A chart has too many points to be displayed on a chart (set with @SettingMaximumPoints)
--     • A point triggers improvement and concern special cause rules and @SettingPointConflictWarning is turned on
--     • A variation icon uses a point that triggers improvement and concern special cause rules and @SettingVariationIconConflictWarning is turned on
--
--====================================================================================================================================================================================================--

-- Check for warnings and output the results
-- ('1' = on | '0' = off)
DECLARE @SettingGlobalWarnings BIT = 1

-- The minimum number of non-ghosted points needed for each chart (metric/group combination) to display as an SPC chart
-- Will otherwise display as a run chart, with SPC elements removed
-- Ignores recalculating of limits
-- (set to 2 for no minimum)
DECLARE @SettingMinimumPoints INT = 15

    -- Return warning
    -- ('1' = on | '0' = off)
DECLARE @SettingMinimumPointsWarning BIT = 0

-- The minimum number of non-ghosted points needed for each step of a chart (metric/group/partition), including baselines
-- Ignored non-SPC charts
-- (set to 1 for no minimum)
DECLARE @SettingMinimumPointsPartition INT = 12

-- The maximum number of non-ghosted points allowed for each step of a chart (metric/group/partition), including baselines
-- (set to NULL for no maximum)
DECLARE @SettingMaximumPointsPartition INT = NULL

-- The maximum number of points the accompanying chart can accommodate
-- (set to NULL for no maximum)
DECLARE @SettingMaximumPoints INT = NULL

-- Return warning for non-ghosted points that trigger improvement and concern special cause rules
-- ('1' = on | '0' = off)
DECLARE @SettingPointConflictWarning BIT = 0
[NHSE_Sandbox_Policy].[temp]
-- Return warning for variation icons that use a point that triggers improvement and concern special cause rules
-- ('1' = on | '0' = off)
DECLARE @SettingVariationIconConflictWarning BIT = 1

-- The number of spaces to indent each level of the group hierarchy
-- (Set to 0 for no indent)
DECLARE @SettingGroupHierarchyIndentSpaces INT = 4

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 2b complete, settings: other'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3A: METRIC DATA
--====================================================================================================================================================================================================--
--
-- This step is where the metric data is entered
--
-- The data must match the columns created in [MHDInternal].[temp_CDP_SPC_MetricData]
-- The data types can be changed, as detailed below, to reduce size
-- Additional columns can be added, which would then require their addition to Step 4b and Step 6.
--
-- [CDP_Measure_ID] and [CDP_Measure_Name] can be any value, even the same
-- [CDP_Measure_ID] is used to control the order the metrics appear in the dropdown; this is added automatically but could be manually controlled
-- [MetricImprovement] can be either 'Up', 'Down', or 'Neither'
-- [MetricConflictRule] can be either 'Improvement' or 'Concern' and determines which to show when special cause rules for both are triggered; this must be provided when [MetricImprovement] is 'Up' or 'Down'
-- [LowMeanWarningValue] can be specified to return a warning when the mean for any metric/group/filter/partition combination is less than the value; otherwise set as NULL
--
-- The data is populated from a table 
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [CDP_Measure_ID] does not exist in [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b)
--     • [CDP_Measure_ID] is duplicated
--     • [MetricImprovement] is not a valid option
--     • [MetricConflictRule] is not a valid option
--     • The mean is less than [LowMeanWarningValue] in any partition
--
--====================================================================================================================================================================================================--

--- RUN STEP 2/37
SELECT 
       m.CDP_Measure_ID,
       m.CDP_Measure_Name,
	   CASE WHEN m.Desired_Direction='Higher is better' THEN 'Up'
			WHEN m.Desired_Direction='Lower is better' THEN 'Down'
			ELSE NULL
	   END as MetricImprovement,
	   'Improvement' as MetricConflictRule,
	   'General' as MetricFormat,
	   NULL as LowMeanWarningValue

INTO [MHDInternal].[temp_CDP_SPC_MetricData] 
FROM [MHDInternal].[REFERENCE_CDP_METADATA] m

WHERE m.CDP_Measure_ID IN ('CDP_B01', 'CDP_B02', 'CDP_B03', 'CDP_B04','CDP_B05','CDP_D01','CDP_F01','CDP_F02','CDP_F03','CDP_M01')
  AND m.Measure_Type NOT IN ('Numerator', 'Denominator')

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3a complete, metric data'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3B: RAW DATA
--====================================================================================================================================================================================================--
--
-- This step is where the raw data is entered
--
-- The data must match the columns created in [MHDInternal].[temp_CDP_SPC_RawData]
-- The data types can be changed, as detailed below, to reduce size
-- Additional columns can be added, which would then require their addition to Step 4b and Step 6.
--
-- [Reporting_Period] must be unique for that metric/group/filter combination
-- [Is_Latest] --new
-- [CDP_Measure_ID] must match a row in [MHDInternal].[temp_CDP_SPC_MetricData]
-- [CDP_Measure_Name]
-- [Org_Type]
-- [Org_Code] code of organisation.
-- [Org_Name]
-- [ICB_Code] determines the hierarchy used in the dropdown and icon summary table; if specified, it must also exist as a group for any metric; otherwise set as NULL for the top level(s) or no hierarchy
-- [ICB_Name]
-- [Region_Code]
-- [Region_Name]
-- [Measure_Type]
-- [Measure_Value] must be a single value (i.e. post-calculation of any numerator and denominator); to enter times, enter the proportion of the day since midnight (e.g. 0.75 for 6pm)
-- [Measure_Value_STR]
-- [Last_Modified]
-- [RecalculateLimitsFlag] can be either '1' (on) or '0' (off)
-- [GhostFlag] can be either '1' (on) or '0' (off)
-- [Annotation] can be any text; otherwise set as NULL
--
-- The data can be inserted into [MHDInternal].[temp_CDP_SPC_RawData] one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples below)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [CDP_Measure_ID] does not exist in [MHDInternal].[temp_CDP_SPC_MetricData] (Step 3a)
--     • [ICB_Code] is not provided as a group
--     • Multiple [ICB_Code] are provided for same group
--     • [CDP_Measure_ID] and [Org_Code] concatenation includes '||' delimiter
--     • [Reporting_Period] is duplicated for metric/group/filter combination
--     • [Measure_Value] is not provided
--     • [RecalculateLimitsFlag] is not a valid option
--     • Recalculation of limits is within baseline (Step 3c)
--     • [GhostFlag] is not a valid option
--
--====================================================================================================================================================================================================--

--- RUN STEP 3/37
SELECT Reporting_Period,
       Is_Latest,
       CDP_Measure_ID,
       CDP_Measure_Name,
       Org_Type,
       Org_Code,
       Org_Name,
       ICB_Code,
       ICB_Name,
       Region_Code,
       Region_Name,
       Measure_Type,
       Measure_Value,
       Measure_Value_STR,
       Last_Modified,
	   CASE WHEN CDP_Measure_ID='CDP_D01'                                              THEN CASE WHEN Reporting_Period = '2020-03-31' 
																								 THEN 1
																								 WHEN Reporting_Period = '2021-04-30'
																								 THEN 1
																								 WHEN Reporting_Period = '2023-03-31'
																								 THEN 1
																								 ELSE 0 END
            WHEN CDP_Measure_ID IN ('CDP_B01','CDP_B02','CDP_B03','CDP_B04','CDP_B05') THEN CASE WHEN Reporting_Period = '2020-03-31' 
																								 THEN 1
																								 WHEN Reporting_Period = '2021-04-30'
																								 THEN 1
																								 ELSE 0 END
	   ELSE 0
	   END as RecalculateLimitsFlag,
	   0 as GhostFlag,
	   NULL as Annotation

  INTO [MHDInternal].[temp_CDP_SPC_RawData]

  FROM [MHDInternal].[DASHBOARD_CDP]
 WHERE CDP_Measure_ID IN ('CDP_B01', 'CDP_B02', 'CDP_B03', 'CDP_B04','CDP_B05','CDP_D01','CDP_F01','CDP_F02','CDP_F03','CDP_M01')
   AND Measure_Type NOT IN ('Numerator', 'Denominator')

--SELECT *
--FROM [MHDInternal].[temp_CDP_SPC_RawData]
---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3b complete, raw data'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3C: BASELINE DATA
--====================================================================================================================================================================================================--
--
-- This step is where the baseline data is entered
-- If there are no baselines, do not insert any data into [MHDInternal].[temp_CDP_SPC_BaselineData] but do not remove the table creation
--
-- The data must match the columns created in [MHDInternal].[temp_CDP_SPC_BaselineData]
-- The data types can be changed, as detailed below, to reduce size
--
-- [BaselineOrder] is used to control which baseline to keep if multiple are provided; this is added automatically but could be manually controlled; if multiple baselines are provided for any metric/group combination, the first is used
-- [CDP_Measure_ID] must match a row in [MHDInternal].[temp_CDP_SPC_MetricData] and [MHDInternal].[temp_CDP_SPC_RawData]
-- [Org_Code] must match a row in [MHDInternal].[temp_CDP_SPC_RawData]; if set as NULL, it will be applied to all groups
-- [Reporting_Period] and/or [PointsExcludeGhosting] must be provided; if both are provided and conflict, [Reporting_Period] is used
--     • This is the last point in the baseline, similar to recalculating the next point
--
-- The data can be inserted into [MHDInternal].[temp_CDP_SPC_BaselineData] one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples in Step 3b)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [BaselineOrder] is duplicated
--     • [CDP_Measure_ID] does not exist in [MHDInternal].[temp_CDP_SPC_MetricData] (Step 3a) or [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b)
--     • [Org_Code] does not exist in [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b) for that metric
--     • [Reporting_Period] does not exist in [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b) for that metric for either that group (if specified) or at least one group (if not specified)
--     • Multiple baselines are provided for metric/group combination
--     • Baseline includes special cause variation
--
--====================================================================================================================================================================================================--

-- Create temporary table

--- RUN STEP 4/37
CREATE TABLE [MHDInternal].[temp_CDP_SPC_BaselineData] (
                             [BaselineOrder]         INT           IDENTITY(1, 1) NOT NULL -- IDENTITY(1, 1) can be removed
                            ,[CDP_Measure_ID]              NVARCHAR(MAX)                NOT NULL -- Can be reduced in size
                            ,[Org_Code]                 NVARCHAR(MAX)                    NULL -- Can be reduced in size
                            ,[Reporting_Period]                  DATE                             NULL
                            ,[PointsExcludeGhosting] INT                              NULL
                           )

-- Insert sample data for various baselines
--INSERT INTO [MHDInternal].[temp_CDP_SPC_BaselineData]
--SELECT 
--       CDP_Measure_ID,
--       Org_Code,
--       NULL as Reporting_Period,
--	   NULL as [PointsExcludeGhosting]

--  FROM [MHDInternal].[DASHBOARD_CDP]
-- WHERE CDP_Measure_ID = 'CDP_D01'
--   AND Measure_Type NOT IN ('Numerator', 'Denominator')

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3c complete, baseline data'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3D: TARGET DATA
--====================================================================================================================================================================================================--
--
-- This step is where the target data is entered for XmR charts
-- If there are no targets, do not insert any data into [MHDInternal].[temp_CDP_SPC_TargetData] but do not remove the table creation
--
-- The data must match the columns created in [MHDInternal].[temp_CDP_SPC_TargetData]
-- The data types can be changed, as detailed below, to reduce size
--
-- [TargetOrder] is used to control which target to keep if multiple are provided; this is added automatically but could be manually controlled; if multiple targets are provided for any metric/group/date combination, the first is used
-- [CDP_Measure_ID] must match a row in [MHDInternal].[temp_CDP_SPC_MetricData] and [MHDInternal].[temp_CDP_SPC_RawData]
-- [Org_Code] must match a row in [MHDInternal].[temp_CDP_SPC_RawData]; if set as NULL, it will be applied to all groups
-- [Target] must be provided
-- [StartDate] and/or [EndDate] can be left as NULL
--
-- The data can be inserted into [MHDInternal].[temp_CDP_SPC_TargetData] one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples in Step 3b)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [TargetOrder] is duplicated
--     • [CDP_Measure_ID] does not exist in [MHDInternal].[temp_CDP_SPC_MetricData] (Step 3a) or [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b)
--     • [Org_Code] does not exist in [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b) for that metric
--     • [StartDate] is after [EndDate]
--     • Multiple targets are provided for metric/group/date combination
--     • Target provided for metric when [MetricImprovement] is not 'Up' or 'Down'
--
--====================================================================================================================================================================================================--

--- RUN STEP 5/37
CREATE TABLE [MHDInternal].[temp_CDP_SPC_TargetData] (
                           [TargetOrder] INT             IDENTITY(1, 1) NOT NULL -- IDENTITY(1, 1) can be removed
						  ,[Reporting_Period]  DATETIME NULL
                          ,[CDP_Measure_ID]    NVARCHAR(MAX)                  NOT NULL -- Can be reduced in size
                          ,[Org_Code]       NVARCHAR(MAX)                      NULL -- Can be reduced in size
                          ,[Target]      DECIMAL(38, 19)                  NULL -- Can be reduced in size (might affect accuracy of calculations)
						  ,[Target_STR] nvarchar(4000)                     NULL
                         )
INSERT INTO [MHDInternal].[temp_CDP_SPC_TargetData]
SELECT 
	   Reporting_Period,
	   CDP_Measure_ID,
	   Org_Code,
       COALESCE([Standard],[LTP_Trajectory]) AS [Target],
	   COALESCE([Standard_STR],[LTP_Trajectory_STR]) AS [Target_STR]

  FROM [MHDInternal].[DASHBOARD_CDP]
 WHERE CDP_Measure_ID IN ('CDP_B01', 'CDP_B02', 'CDP_B03', 'CDP_B04','CDP_B05','CDP_D01','CDP_F01','CDP_F02','CDP_F03','CDP_M01')
   AND Measure_Type NOT IN ('Numerator', 'Denominator') 

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3d complete, target data'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4A: HIERARCHY
--====================================================================================================================================================================================================--
--
-- Deleted not required
--
--====================================================================================================================================================================================================--
-- STEP 4B: PARTITIONS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step combines data and adds partitions
--
--====================================================================================================================================================================================================--

-- Join metric and raw data along with the hierarchy
-- Add row ID (used for self-joins below) and chart ID
-- Add point rank (used for baselines and icons)
-- Replace NULL in [Annotation] with empty text
-- Add dropdown version of group with indentation
-- Add partitions for each metric/org combination based on when limits are recalculated, including partition without ghosted points (used for mean and moving range calculations)

--- RUN STEP 6/37
DECLARE @SettingGroupHierarchyIndentSpaces INT = 4
SELECT   
	     [RowID]                              = CONCAT(r.[CDP_Measure_ID], '||', r.[Org_Code], '||', ROW_NUMBER()  OVER(PARTITION BY m.[CDP_Measure_ID], r.Org_Code ORDER BY r.[Reporting_Period])) 
      ,  [ChartID]                            = CONCAT(r.[CDP_Measure_ID], '||', r.[Org_Code])                     
      ,  [PointExcludeGhostingRankAscending]  = CASE WHEN r.[GhostFlag] = 1 THEN NULL                                                                                                                                                          
                                                     ELSE ROW_NUMBER()  OVER(PARTITION BY m.[CDP_Measure_ID], r.Org_Code, r.[GhostFlag] ORDER BY r.[Reporting_Period] ASC) END
      ,  [PointExcludeGhostingRankDescending] = CASE WHEN r.[GhostFlag] = 1 THEN NULL                                                                                                                                                                        
                                                     ELSE ROW_NUMBER()  OVER(PARTITION BY m.[CDP_Measure_ID], r.Org_Code, r.[GhostFlag] ORDER BY r.[Reporting_Period] DESC) END
      ,m.[CDP_Measure_ID]                                                                                  
      ,m.[MetricImprovement]
      ,m.[MetricConflictRule]
      ,m.[LowMeanWarningValue]
      ,r.[Org_Code]
	  ,r.[Reporting_Period]
	  ,r.Is_Latest
	  ,r.CDP_Measure_Name
	  ,r.Org_Type
	  ,r.Org_Name
	  ,r.ICB_Code
	  ,r.ICB_Name
	  ,r.Region_Code
	  ,r.Region_Name
	  ,r.Measure_Type
      ,r.[Measure_Value]  
	  ,r.Measure_Value_STR
	  ,r.Last_Modified
      ,r.[RecalculateLimitsFlag]                 
      ,r.[GhostFlag]                             
      ,  [Annotation]                         = ISNULL(r.[Annotation], '')
      ,  [PartitionID]                        = SUM(r.[RecalculateLimitsFlag]) OVER(PARTITION BY r.[CDP_Measure_ID], r.[Org_Code] ORDER BY r.[Reporting_Period]) + 1
      ,  [PartitionIDExcludeGhosting]         = CASE WHEN r.[GhostFlag] = 1 THEN NULL
                                                                            ELSE SUM(r.[RecalculateLimitsFlag]) OVER(PARTITION BY r.[CDP_Measure_ID], r.[Org_Code] ORDER BY r.[Reporting_Period]) + 1 END
																			
INTO [MHDInternal].[temp_CDP_SPC_CalculationsPartition]
FROM [MHDInternal].[temp_CDP_SPC_MetricData]                         AS m
    INNER JOIN [MHDInternal].[temp_CDP_SPC_RawData]                  AS r ON r.[CDP_Measure_ID] = m.[CDP_Measure_ID]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4b complete, partitions'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4C: BASELINES
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds baselines and then updates partitions
--
--====================================================================================================================================================================================================--

-- Add baseline end flags
-- If multiple baselines are provided for metric/group combination, add rank for updating below
-- If both [Reporting_Period] and [PointsExcludeGhosting] are provided and these conflict, use [Reporting_Period]

--- RUN STEP 7/37
SELECT p.*
      ,  [BaselineEndFlag] = CASE WHEN b.[CDP_Measure_ID] IS NOT NULL THEN 1
                                                                ELSE 0 END
      ,  [BaselineEndRank] = CASE WHEN b.[CDP_Measure_ID] IS NOT NULL THEN ROW_NUMBER() OVER(PARTITION BY p.[ChartID], b.[CDP_Measure_ID] ORDER BY b.[BaselineOrder], CASE WHEN b.[Reporting_Period] = p.[Reporting_Period] THEN 0

  ELSE 1 END) END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsPartition] AS p
LEFT JOIN [MHDInternal].[temp_CDP_SPC_BaselineData]        AS b ON b.[CDP_Measure_ID]                 = p.[CDP_Measure_ID]
                                   AND ISNULL(b.[Org_Code], p.[Org_Code]) = p.[Org_Code]
                                   AND (b.[Reporting_Period]                    = p.[Reporting_Period]
                                     OR b.[PointsExcludeGhosting]   = p.[PointExcludeGhostingRankAscending])

-- When extra baselines are provided for metric/group combination, remove based on rank
UPDATE [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
SET [BaselineEndFlag] = 0
WHERE [BaselineEndFlag] = 1
  AND [BaselineEndRank] > 1

--- RUN STEP 8/37
-- Add baseline flag for all points up to and including baseline end flag for metric/group combination
SELECT bf1.*
      ,    [BaselineFlag] = CASE WHEN bf1.[Reporting_Period] <= bf2.[Reporting_Period] THEN 1
                                                               ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsBaseline]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag] AS bf1
LEFT JOIN (
            SELECT [ChartID]
                  ,[Org_Code]
                  ,[Reporting_Period]
            FROM [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
            WHERE [BaselineEndFlag] = 1
          ) AS bf2 ON bf2.[ChartID] = bf1.[ChartID]

-- Update partition IDs for baseline points
UPDATE [MHDInternal].[temp_CDP_SPC_CalculationsBaseline]
SET [PartitionID]                = 0
   ,[PartitionIDExcludeGhosting] = CASE WHEN [GhostFlag] = 1 THEN NULL
                                                             ELSE 0 END
WHERE [BaselineFlag] = 1

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4c complete, baselines'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4D: TARGETS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds targets for XmR charts
--
--====================================================================================================================================================================================================--

-- Add targets
-- If multiple targets are provided for metric/org/date combination, add rank for updating below
-- If metric improvement is 'neither', ignore

--- RUN STEP 9/37
SELECT b.*
      ,t.[Target]
	  ,t.[Target_STR]
      --,  [TargetRank] = ROW_NUMBER() OVER(PARTITION BY b.[ChartID], b.[Reporting_Period] ORDER BY t.[TargetOrder])
	  ,[TargetRank] = ROW_NUMBER() OVER(PARTITION BY b.[ChartID], b.[Reporting_Period] ORDER BY t.[TargetOrder], t.Reporting_Period)

 INTO [MHDInternal].[temp_CDP_SPC_CalculationsAllTargets]

 FROM [MHDInternal].[temp_CDP_SPC_CalculationsBaseline] AS b

LEFT JOIN [MHDInternal].[temp_CDP_SPC_TargetData] AS t 
       ON t.[CDP_Measure_ID] = b.[CDP_Measure_ID]
      AND ISNULL(t.[Org_Code], b.[Org_Code]) = b.[Org_Code]
      AND b.[Reporting_Period] = t.[Reporting_Period]
    --AND ISNULL(t.[StartDate], b.[Reporting_Period]) <= b.[Reporting_Period]
    --AND ISNULL(t.[EndDate], b.[Reporting_Period]) >= b.[Reporting_Period]
      AND b.[MetricImprovement] IN ('Up', 'Down')

--- RUN STEP 10/37
-- When extra targets are provided for metric/group/date combination, remove all but the first
SELECT *
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSingleTarget]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsAllTargets]
WHERE [TargetRank] = 1

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4d complete, targets'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4E: PROCESS LIMITS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates the mean, moving range, and process limits
--
--====================================================================================================================================================================================================--

--- RUN STEP 11/37
SELECT *
      ,[Mean] = CASE WHEN [GhostFlag] = 1   THEN NULL
                     ELSE AVG([Measure_Value]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting]) END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsMean]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSingleTarget]

-- Add moving range for XmR charts, based on absolute difference from previous point, for each metric/group/partition/filter combination, excluding ghosted points and first non-ghosted point in partition
-- Add moving range without partition for use in mR chart

--- RUN STEP 12/37
SELECT *
      ,[MovingRangeWithPartition]            = CASE WHEN [GhostFlag] = 1     THEN NULL
                                                    ELSE ABS([Measure_Value]                    - LAG([Measure_Value], 1)                    OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])) END
      ,[MovingRange]                         = CASE WHEN [GhostFlag] = 1     THEN NULL                                                                
                                                    ELSE ABS([Measure_Value]                    - LAG([Measure_Value], 1)                    OVER(PARTITION BY [ChartID], [GhostFlag]                  ORDER BY [Reporting_Period])) END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMean]

-- Add moving range mean for each metric/group/filter/partition combination, excluding those with no moving range (i.e ghosted points and first non-ghosted point in partition)
-- Create duplicate, for updating below, to be used specifically for process limit calculations

--- RUN STEP 13/37
SELECT  mr.*
      ,mrm.[MovingRangeMean]
      ,    [MovingRangeMeanForProcessLimits] = mrm.[MovingRangeMean]
INTO [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange] AS mr
LEFT JOIN (
            SELECT *
                  ,[MovingRangeMean] = AVG([MovingRangeWithPartition]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting])
            FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange]
            WHERE [MovingRangeWithPartition] IS NOT NULL
           ) mrm ON mrm.[RowID] = mr.[RowID]

--- RUN STEP 14/37
-- Checks for setting (set in Step 2a)
DECLARE @ExcludeMovingRangeOutliers BIT = 0
IF @ExcludeMovingRangeOutliers = 1

    BEGIN
 
         -- Update moving range mean by recalculating with moving range outliers removed
        UPDATE mrm
        SET [MovingRangeMeanForProcessLimits] = [MovingRangeMeanWithoutOutliers]
        FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
        LEFT JOIN (
                    SELECT DISTINCT
                           [MovingRangeMeanWithoutOutliers] = AVG([MovingRangeWithPartition]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting])
                          ,[ChartID]
                          ,[PartitionID]
                    FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
                    WHERE [MovingRangeWithPartition] <= [MovingRangeMean] * 3.267
                  ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                           AND mrm2.[PartitionID] = mrm.[PartitionID]

        -- Update mean by recalculating with moving range outliers removed
        UPDATE mrm
        SET [Mean] = [MeanWithoutOutliers]
        FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
        LEFT JOIN (
                    SELECT DISTINCT
                           [MeanWithoutOutliers] = CASE WHEN [GhostFlag] = 1 THEN NULL
                                                                             ELSE AVG([Measure_Value]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting]) END
                          ,[ChartID]
                          ,[PartitionID]
                    FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
                    WHERE [MovingRangeWithPartition] <= [MovingRangeMean] * 3.267
                       OR [MovingRangeWithPartition] IS NULL
                  ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                           AND mrm2.[PartitionID] = mrm.[PartitionID]

    END

-- Update mean for those skipped above (i.e. ghosted points) by copying from mean within metric/group/filter/partition combination
UPDATE mrm
SET mrm.[Mean] = mrm2.[PartitionMean]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
LEFT JOIN (
            SELECT DISTINCT
                   [ChartID]
                  ,[PartitionID]
                  ,[PartitionMean] = AVG([Mean]) OVER(PARTITION BY [ChartID], [PartitionID])
            FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
            WHERE [Mean] IS NOT NULL
          ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                   AND mrm2.[PartitionID] = mrm.[PartitionID]

-- Update moving range mean for those skipped above (i.e. ghosted points and first non-ghosted point in partition) by copying from moving range mean within metric/group/filter/partition combination
UPDATE mrm
SET mrm.[MovingRangeMean]                 = mrm2.[PartitionMovingRangeMean]
   ,mrm.[MovingRangeMeanForProcessLimits] = mrm2.[PartitionMovingRangeMeanForProcessLimits]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
LEFT JOIN (
            SELECT DISTINCT
                   [ChartID]
                  ,[PartitionID]
                  ,[PartitionMovingRangeMean]                 = AVG([MovingRangeMean])                 OVER(PARTITION BY [ChartID], [PartitionID])
                  ,[PartitionMovingRangeMeanForProcessLimits] = AVG([MovingRangeMeanForProcessLimits]) OVER(PARTITION BY [ChartID], [PartitionID])
            FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
            WHERE [MovingRangeMean] IS NOT NULL
          ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                   AND mrm2.[PartitionID] = mrm.[PartitionID]

-- Update mean, moving range mean for first partition after baseline within metric/group/filter/partition combination when a baseline is set
UPDATE mrm
SET mrm.[Mean]                                    = mrm2.[Mean]
   ,mrm.[MovingRangeMean]                         = mrm2.[MovingRangeMean]
   ,mrm.[MovingRangeMeanForProcessLimits]         = mrm2.[MovingRangeMeanForProcessLimits]

FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
INNER JOIN (
             SELECT DISTINCT
                    [ChartID]
                   ,[PartitionID]
                   ,[Mean]
                   ,[MovingRangeMean]
                   ,[MovingRangeMeanForProcessLimits]
             FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
             WHERE [PartitionID] = 0
           ) AS mrm2 ON mrm2.[ChartID] = mrm.[ChartID]
WHERE mrm.[PartitionID] = 1

-- Add moving range process limit and high point value

--- RUN STEP 15/37
SELECT *
      ,[MovingRangeProcessLimit]   =                           [MovingRangeMean] * 3.267
      ,[MovingRangeHighPointValue] = CASE WHEN [MovingRange] > [MovingRangeMean] * 3.267 THEN [MovingRange] END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeProcessLimit]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]

-- Add upper and lower process limits along with one and two sigma lines

--- RUN STEP 16/37
SELECT *
      ,[UpperProcessLimit] = [Mean] + [MovingRangeMeanForProcessLimits] * 2.66
      ,[UpperTwoSigma]     = [Mean] + [MovingRangeMeanForProcessLimits] * 2.66 * (2 / 3.0)   
      ,[UpperOneSigma]     = [Mean] + [MovingRangeMeanForProcessLimits] * 2.66 * (1 / 3.0)
      ,[LowerOneSigma]     = [Mean] - [MovingRangeMeanForProcessLimits] * 2.66 * (1 / 3.0) 
      ,[LowerTwoSigma]     = [Mean] - [MovingRangeMeanForProcessLimits] * 2.66 * (2 / 3.0)
      ,[LowerProcessLimit] = [Mean] - [MovingRangeMeanForProcessLimits] * 2.66

INTO [MHDInternal].[temp_CDP_SPC_CalculationsProcessLimits]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeProcessLimit]

-- Add upper and lower process limits for baselines

--- RUN STEP 17/37
SELECT *
      ,[UpperBaseline] = CASE WHEN [BaselineFlag] = 1 THEN [UpperProcessLimit] END
      ,[LowerBaseline] = CASE WHEN [BaselineFlag] = 1 THEN [LowerProcessLimit] END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsBaselineLimits]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsProcessLimits]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4e complete, process limits'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4F: SPECIAL CAUSE - SINGLE POINT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a single point beyond the process limits
--
--====================================================================================================================================================================================================--

-- Add special cause flag for single non-ghosted points beyond upper or lower process limits

--- RUN STEP 18/37
SELECT *
      ,[SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag] = CASE WHEN [GhostFlag] = 1               THEN 0
                                                                      WHEN [Measure_Value] > [UpperProcessLimit] THEN 1
                                                                                                         ELSE 0 END
      ,[SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag] = CASE WHEN [GhostFlag] = 1               THEN 0
                                                                      WHEN [Measure_Value] < [LowerProcessLimit] THEN 1
                                                                                                         ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseSinglePoint]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsBaselineLimits]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4f complete, special cause: single point'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4G: SPECIAL CAUSE - SHIFT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a shift of points all above or below the mean
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for a shift of non-ghosted points all above or all below the mean by flagging whether the non-ghosted point is above or below the mean

--- RUN STEP 19/37
SELECT *
      ,[SpecialCauseAboveMeanFlag] = CASE WHEN [GhostFlag] = 1  THEN 0
                                          WHEN [Measure_Value] > [Mean] THEN 1
                                                                ELSE 0 END
      ,[SpecialCauseBelowMeanFlag] = CASE WHEN [GhostFlag] = 1  THEN 0
                                          WHEN [Measure_Value] < [Mean] THEN 1
                                                                ELSE 0 END 
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShiftPrep]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseSinglePoint]

-- Add cumulative sum of the above and below mean flags for non-ghosted points within metric/group/filter/partition combination

--- RUN STEP 20/37
SELECT *
      ,[SpecialCauseAboveMeanPartitionCount] = SUM([SpecialCauseAboveMeanFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
      ,[SpecialCauseBelowMeanPartitionCount] = SUM([SpecialCauseBelowMeanFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCausePartitionCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShiftPrep]

-- Determine, depending on setting (set in Step 2a), each non-ghosted point that starts a shift of X non-ghosted points all above or all below the mean within metric/group/filter/partition combination

--- RUN STEP 21/37
DECLARE @SettingSpecialCauseShiftPoints INT = 7
SELECT *
      ,[SpecialCauseShiftAboveMeanStartFlag] = CASE WHEN [SpecialCauseAboveMeanFlag] = 1
                                                     AND LEAD([SpecialCauseAboveMeanPartitionCount], @SettingSpecialCauseShiftPoints - 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) - [SpecialCauseAboveMeanPartitionCount] = @SettingSpecialCauseShiftPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                                   ELSE 0 END
      ,[SpecialCauseShiftBelowMeanStartFlag] = CASE WHEN [SpecialCauseBelowMeanFlag] = 1
                                                     AND LEAD([SpecialCauseBelowMeanPartitionCount], @SettingSpecialCauseShiftPoints - 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) - [SpecialCauseBelowMeanPartitionCount] = @SettingSpecialCauseShiftPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                                   ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlag]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCausePartitionCount]

-- Add cumulative sum of the above and below mean start-of-shift flags for non-ghosted points within metric/group/filter/partition combination

--- RUN STEP 22/37
SELECT *
      ,[SpecialCauseShiftAboveMeanStartFlagCount] = SUM([SpecialCauseShiftAboveMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
      ,[SpecialCauseShiftBelowMeanStartFlagCount] = SUM([SpecialCauseShiftBelowMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlagCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlag]

-- Determine, depending on setting (set in Step 2a), each point within a shift of X non-ghosted points all above or all below the mean
-- This is done by comparing the above/below mean start-of-shift flag count with that X non-ghosted points prior within metric/group/filter/partition combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseShiftAboveMeanStartFlagCount] will only be higher if there is at least one point within the last X non-ghosted points within metric/group/filter/partition combination that starts an above/below mean shift

--- RUN STEP 23/37
DECLARE @SettingSpecialCauseShiftPoints INT = 7
SELECT *
      ,[SpecialCauseRuleShiftAboveMeanFlag] = CASE WHEN [SpecialCauseShiftAboveMeanStartFlagCount] > ISNULL(LAG([SpecialCauseShiftAboveMeanStartFlagCount], @SettingSpecialCauseShiftPoints) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                                            ELSE 0 END
      ,[SpecialCauseRuleShiftBelowMeanFlag] = CASE WHEN [SpecialCauseShiftBelowMeanStartFlagCount] > ISNULL(LAG([SpecialCauseShiftBelowMeanStartFlagCount], @SettingSpecialCauseShiftPoints) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                                            ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShift]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlagCount]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4g complete, special cause: shift'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4H: SPECIAL CAUSE - TREND
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a trend increasing or decreasing points, including endpoints, and works across partitions
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for a trend of increasing or decreasing non-ghosted points by flagging whether the non-ghosted point is greater than or less than the previous non-ghosted point within metric/group/filter combination

--- RUN STEP 24/37
SELECT *
      ,[SpecialCauseIncreasingFlag] = CASE WHEN [GhostFlag] = 1                                                                               THEN 0
                                           WHEN [Measure_Value] > LAG([Measure_Value], 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]) THEN 1
                                                                                                                                              ELSE 0 END
      ,[SpecialCauseDecreasingFlag] = CASE WHEN [GhostFlag] = 1                                                                               THEN 0
                                           WHEN [Measure_Value] < LAG([Measure_Value], 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]) THEN 1
                                                                                                                                              ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPrep]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShift]

-- Add cumulative sum of the increasing and decreasing flags for non-ghosted points within metric/group/filter combination

--- RUN STEP 25/37
SELECT *
      ,[SpecialCauseIncreasingPartitionCount] = SUM([SpecialCauseIncreasingFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period])
      ,[SpecialCauseDecreasingPartitionCount] = SUM([SpecialCauseDecreasingFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPartitionCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPrep]

-- Determine, depending on setting (set in Step 2a), each non-ghosted point that starts a trend of X increasing or decreasing non-ghosted points within metric/group/filter combination

--- RUN STEP 26/37
DECLARE @SettingSpecialCauseTrendPoints INT = 7
SELECT *
      ,[SpecialCauseTrendIncreasingStartFlag] = CASE WHEN LEAD([SpecialCauseIncreasingPartitionCount], @SettingSpecialCauseTrendPoints - 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]) - [SpecialCauseIncreasingPartitionCount] = @SettingSpecialCauseTrendPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                     ELSE 0 END
      ,[SpecialCauseTrendDecreasingStartFlag] = CASE WHEN LEAD([SpecialCauseDecreasingPartitionCount], @SettingSpecialCauseTrendPoints - 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]) - [SpecialCauseDecreasingPartitionCount] = @SettingSpecialCauseTrendPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                     ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlag]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPartitionCount]

-- Add cumulative sum of the increasing and decreasing start-of-trend flags for non-ghosted points within metric/group/filter combination

--- RUN STEP 27/37
SELECT *
      ,[SpecialCauseTrendIncreasingStartFlagCount] = SUM([SpecialCauseTrendIncreasingStartFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period])
      ,[SpecialCauseTrendDecreasingStartFlagCount] = SUM([SpecialCauseTrendDecreasingStartFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlagCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlag]

-- Determine, depending on setting (set in Step 2a), each non-ghosted point within a trend of X non-ghosted points all increasing or all decreasing, including endpoints
-- This is done by comparing the increasing/decreasing start-of-trend flag count with that X non-ghosted points prior within metric/group/filter combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseTrendAboveMeanStartFlagCount] will only be higher if there is at least one point within the last X non-ghosted points within metric/group/filter combination that starts an increasing/decreasing trend

--- RUN STEP 28/37
DECLARE @SettingSpecialCauseTrendPoints INT = 7
SELECT *
      ,[SpecialCauseRuleTrendIncreasingFlag] = CASE WHEN [SpecialCauseTrendIncreasingStartFlagCount] > ISNULL(LAG([SpecialCauseTrendIncreasingStartFlagCount], @SettingSpecialCauseTrendPoints) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                              ELSE 0 END
      ,[SpecialCauseRuleTrendDecreasingFlag] = CASE WHEN [SpecialCauseTrendDecreasingStartFlagCount] > ISNULL(LAG([SpecialCauseTrendDecreasingStartFlagCount], @SettingSpecialCauseTrendPoints) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                              ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrend]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlagCount]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4h complete, special cause: trend'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4I: SPECIAL CAUSE - TWO-TO-THREE SIGMA
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for there being two or three points within a run of three that lie beyond the two-sigma line but not beyond the three-sigma line (i.e. process limit) on a consistent side of the mean
-- If the third point is not also within this range, it needs to be on the same side of the mean
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for two/three of three non-ghosted points within a run of three all beyond two sigma but not beyond three sigma, all on the same side of the mean

--- RUN STEP 29/37
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanFlag] = CASE WHEN [GhostFlag] = 1                THEN 0
                                                       WHEN [Measure_Value] > [UpperTwoSigma]
                                                        AND [Measure_Value] <= [UpperProcessLimit] THEN 1
                                                                                           ELSE 0 END
      ,[SpecialCauseTwoThreeSigmaBelowMeanFlag] = CASE WHEN [GhostFlag] = 1                THEN 0
                                                       WHEN [Measure_Value] < [LowerTwoSigma]
                                                        AND [Measure_Value] >= [LowerProcessLimit] THEN 1
                                                                                           ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaPrep]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrend]

-- Determine each non-ghosted point that is flagged and starts a group of two or three non-ghosted two-to-three sigma points, all on the same side of the mean, within a run of three, within metric/group/filter/partition combination
-- The third point must also be on the same side of the mean

--- RUN STEP 30/37
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanStartFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaAboveMeanFlag] = 1
                                                             AND ( LEAD([SpecialCauseTwoThreeSigmaAboveMeanFlag], 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                              AND ( LAG([SpecialCauseAboveMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                               OR (LEAD([SpecialCauseAboveMeanFlag], 2)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1))
                                                             OR    LEAD([SpecialCauseTwoThreeSigmaAboveMeanFlag], 2) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                              AND  LEAD([SpecialCauseAboveMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1)  THEN 1
                                                                                                                                                                                                      ELSE 0 END
      ,[SpecialCauseTwoThreeSigmaBelowMeanStartFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaBelowMeanFlag] = 1
                                                             AND ( LEAD([SpecialCauseTwoThreeSigmaBelowMeanFlag], 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                              AND ( LAG([SpecialCauseBelowMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                               OR (LEAD([SpecialCauseBelowMeanFlag], 2)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1))
                                                             OR    LEAD([SpecialCauseTwoThreeSigmaBelowMeanFlag], 2) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                              AND  LEAD([SpecialCauseBelowMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1)  THEN 1
                                                                                                                                                                                                      ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlag]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaPrep]

-- Add cumulative sum of the above and below mean start-of-two-to-three-sigma flags for non-ghosted points within metric/group/filter/partition combination

--- RUN STEP 31/37
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] = SUM([SpecialCauseTwoThreeSigmaAboveMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
      ,[SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount] = SUM([SpecialCauseTwoThreeSigmaBelowMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlagCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlag]

-- Determine each non-ghosted two-to-three sigma point within a group of two or three non-ghosted two-to-three sigma points, on the same side of the mean
-- This is done by comparing the above/below mean start-of-two-to-three sigma flag count with that 3 non-ghosted points prior within metric/group/filter/partition combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] will only be higher if there is at least one point within the last 2 non-ghosted points within metric/group/filter/partition combination that starts a new group
-- The point itself must also be flagged

--- RUN STEP 32/37
SELECT *
      ,[SpecialCauseRuleTwoThreeSigmaAboveMeanFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaAboveMeanFlag] = 1
                                                            AND [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] > ISNULL(LAG([SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount], 3) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                                      ELSE 0 END
      ,[SpecialCauseRuleTwoThreeSigmaBelowMeanFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaBelowMeanFlag] = 1
                                                            AND [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount] > ISNULL(LAG([SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount], 3) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                                      ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigma]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlagCount]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4i complete, special cause: two-to-three sigma'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4J: SPECIAL CAUSE COMBINED
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step combines the points that have triggered special cause rules
--
--====================================================================================================================================================================================================--

-- Combine special cause rules into improvement/concern/neither values
-- Add conflict flag for updating below
-- Add neither high/low flags

--- RUN STEP 33/37
SELECT *
      ,[SpecialCauseImprovementValue] = CASE WHEN [MetricImprovement] = 'Up'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN [Measure_Value]
                                             WHEN [MetricImprovement] = 'Down'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Measure_Value] END
      ,[SpecialCauseConcernValue]     = CASE WHEN [MetricImprovement] = 'Up'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Measure_Value]
                                             WHEN [MetricImprovement] = 'Down'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN [Measure_Value] END
      ,[SpecialCauseConflictFlag]      = NULL
      ,[SpecialCauseNeitherValue]      = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag] = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Measure_Value] END
      ,[SpecialCauseNeitherHighFlag]  = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN 1
                                                                                                                   ELSE 0 END
      ,[SpecialCauseNeitherLowFlag]   = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN 1
                                                                                                                   ELSE 0 END
	  ,[Shapes]                      = CASE WHEN ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=1 OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=1) 
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0 
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Outlier'
											WHEN (SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 1 OR SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
											THEN 'Two-thirds'
											WHEN (SpecialCauseRuleShiftAboveMeanFlag = 1 OR SpecialCauseRuleShiftBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Shift'
											WHEN (SpecialCauseRuleTrendIncreasingFlag = 1 OR SpecialCauseRuleTrendDecreasingFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Trend'

											WHEN ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=1 OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=1)
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
												AND (SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 1 OR SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 1)
											THEN 'Outlier & Two-Thirds'
											WHEN ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=1 OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=1)
												AND (SpecialCauseRuleShiftAboveMeanFlag = 1 OR SpecialCauseRuleShiftBelowMeanFlag = 1)
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Outlier & Shift'
											WHEN ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=1 OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=1)
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND (SpecialCauseRuleTrendIncreasingFlag = 1 OR SpecialCauseRuleTrendIncreasingFlag = 1)
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Outlier & Trend'

											WHEN (SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 1 OR SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND (SpecialCauseRuleShiftAboveMeanFlag = 1 OR SpecialCauseRuleShiftBelowMeanFlag = 1)
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
											THEN 'Two-thirds & Shift'
											WHEN (SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 1 OR SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND (SpecialCauseRuleTrendIncreasingFlag = 1 OR SpecialCauseRuleTrendIncreasingFlag = 1)
											THEN 'Two-thirds & Trend'

											WHEN (SpecialCauseRuleShiftAboveMeanFlag = 1 OR SpecialCauseRuleShiftBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND (SpecialCauseRuleTrendIncreasingFlag = 1 OR SpecialCauseRuleTrendIncreasingFlag = 1)
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Shift & Trend'

											ELSE 'No Nelson Rule(s)' END 

INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigma]

-- For points that have triggered both an improvement rule and a concern rule, for example an ascending trend below the mean, remove one depending on [MetricConflict] and update conflicting flag:
-- Show only as improvement by removing concern value...
UPDATE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
SET [SpecialCauseConcernValue] = NULL
   ,[SpecialCauseConflictFlag] = 1
WHERE [MetricConflictRule] = 'Improvement'
  AND [SpecialCauseImprovementValue] IS NOT NULL
  AND [SpecialCauseConcernValue]     IS NOT NULL

-- ...or show only as concern by removing improvement value
UPDATE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
SET [SpecialCauseImprovementValue] = NULL
   ,[SpecialCauseConflictFlag]     = 1
WHERE [MetricConflictRule] = 'Concern'
  AND [SpecialCauseImprovementValue] IS NOT NULL
  AND [SpecialCauseConcernValue]     IS NOT NULL

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4j complete, special cause combined'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4K: ICONS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds the variation and assurance icons for the last non-ghosted point
-- Variation icon is added for the last non-ghosted point if an up/down metric improvement is provided
-- Assurance icon is added for the last non-ghosted point if an up/down metric improvement and target are both provided
--
--====================================================================================================================================================================================================--

-- Add variance and assurance icon flags for XmR charts

--- RUN STEP 34/37
SELECT *
      ,[VariationTrend] = CASE WHEN [MetricImprovement] = 'Up'                                                             THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (High)'
																																	 WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (Low)'
																																	 ELSE 'Common Cause' END
                                                                                       WHEN [MetricImprovement] = 'Down'   THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (Low)'
																																	 WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (High)'
																																	 ELSE 'Common Cause' END
                                                                                       WHEN [MetricImprovement] = 'Neither'THEN CASE WHEN [SpecialCauseNeitherHighFlag] = 1          THEN 'Neither (High)'
                                                                                                                                     WHEN [SpecialCauseNeitherLowFlag]  = 1          THEN 'Neither (Low)'
                                                                                                                                     ELSE 'Common Cause' END END
      ,[VariationIcon] = CASE WHEN [PointExcludeGhostingRankDescending] = 1  THEN CASE WHEN [MetricImprovement] = 'Up'     THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (High)'
																																	 WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (Low)'
																																	 ELSE 'Common Cause' END
                                                                                       WHEN [MetricImprovement] = 'Down'   THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (Low)'
																																	 WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (High)'
																																	 ELSE 'Common Cause' END
                                                                                       WHEN [MetricImprovement] = 'Neither'THEN CASE WHEN [SpecialCauseNeitherHighFlag] = 1          THEN 'Neither (High)'
                                                                                                                                     WHEN [SpecialCauseNeitherLowFlag]  = 1          THEN 'Neither (Low)'
                                                                                                                                     ELSE 'Common Cause' END END END
      ,[AssuranceIcon] = CASE WHEN [PointExcludeGhostingRankDescending] = 1  THEN CASE WHEN [MetricImprovement] = 'Up'     THEN CASE WHEN [Target] <= [LowerProcessLimit]            THEN 'Pass'
                                                                                                                                     WHEN [Target] >  [LowerProcessLimit]  
																																	  AND [Target] <  [UpperProcessLimit]            THEN 'Hit or Miss'
                                                                                                                                     WHEN [Target] >= [UpperProcessLimit]            THEN 'Fail' END
                                                                                       WHEN [MetricImprovement] = 'Down'   THEN CASE WHEN [Target] >= [UpperProcessLimit]            THEN 'Pass'
                                                                                                                                     WHEN [Target] >  [LowerProcessLimit]                
                                                                                                                                      AND [Target] <  [UpperProcessLimit]            THEN 'Hit or Miss'
                                                                                                                                     WHEN [Target] <= [LowerProcessLimit]            THEN 'Fail' END END END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsIcons]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4k complete, icons'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4L: ROW COUNT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds row counts for use in Steps 5-6
--
--====================================================================================================================================================================================================--

-- Add row counts to enable possible exclusion of metric/group/filter combinations with an insufficient number of points (set in Step 2b)

--- RUN STEP 35/37
SELECT *
      ,[RowCountExcludeGhosting] = SUM(CASE WHEN [GhostFlag] = 1 THEN 0
                                                                 ELSE 1 END) OVER(PARTITION BY [CDP_Measure_ID], [ChartID])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsRowCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsIcons]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4l complete, row count'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 6: OUTPUT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is unless used with the accompanying Power BI template
-- Either store the output in a table (see commented out code below) or turn this SQL query into a stored procedure and skip the warning step above so that only one table is returned
--
-- This step returns the table that is used in the accompanying Power BI template
-- Removing any of these columns may result in the tool not working correctly
-- Additional columns can be added for information purposes
--
--====================================================================================================================================================================================================--

-- Columns removed and reordered
-- SPC features removed from chart for metric/group/filter combinations with an insufficient number of points, depending on setting (set in Step 2b)

--- RUN STEP 36/37
-- MANUALY REMOVE [DASHBOARD_CDP_SPC] becuase DROP TABLE doesnt do the job!
IF OBJECT_ID ('[MHDInternal].[DASHBOARD_CDP_SPC] ') IS NOT NULL
DROP TABLE [MHDInternal].[DASHBOARD_CDP_SPC] 

DECLARE @SettingMinimumPoints INT = 15

SELECT 
       m.[CDP_Measure_ID]
      ,m.[Reporting_Period]
      ,m.[Measure_Value]
	  ,r.Is_Latest
	  ,r.CDP_Measure_Name
      ,r.Org_Type
      ,r.Org_Code
      ,r.Org_Name
      ,r.ICB_Code
      ,r.ICB_Name
      ,r.Region_Code
      ,r.Region_Name
      ,r.Measure_Type
      ,r.Measure_Value_STR
      ,r.Last_Modified
      ,m.[Target]
	  ,m.[Target_STR]
      ,m.[Mean]
      ,[UpperProcessLimit]            = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN m.[UpperProcessLimit]            END
      ,[LowerProcessLimit]            = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN m.[LowerProcessLimit]            END
	  ,[VariationTrend]
      ,[VariationIcon]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [VariationIcon]                END
      ,[AssuranceIcon]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [AssuranceIcon]                END
	  ,m.[Shapes]
      ,m.[Annotation]

INTO [MHDInternal].[DASHBOARD_CDP_SPC] 
FROM [MHDInternal].[temp_CDP_SPC_CalculationsRowCount] m

LEFT JOIN [MHDInternal].[temp_CDP_SPC_RawData] r
       ON m.CDP_Measure_ID = r.CDP_Measure_ID
	  AND m.Org_Code = r.Org_Code
	  AND m.Reporting_Period = r.Reporting_Period

ORDER BY [CDP_Measure_ID]
        ,[Reporting_Period]
--drop table [MHDInternal].[DASHBOARD_CDP_SPC_v2]
---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 6  complete, output'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT
--drop table [MHDInternal].[DASHBOARD_CDP_SPC]

--select *
--into [MHDInternal].[DASHBOARD_CDP_SPC]
--from [MHDInternal].[DASHBOARD_CDP_SPC]
--====================================================================================================================================================================================================--
-- STEP 7: QA Check - Compares latest CDP dates and latest SPC  and whther SPC limits icons have been included
--====================================================================================================================================================================================================--
Select Distinct SPC.CDP_Measure_Name,SPC.CDP_Measure_ID,SPC.Reporting_Interval,SPC.Latest_SPC_Date,
CDP.Reporting_Period 'Latest_CDP_Date',
Case when Latest_SPC_Date=CDP.Reporting_Period Then 'Y' Else 'N' End as Dates_Match,
[SPC].[SPC_Limits Applied],[SPC].[SPC Icons Applied]
from
(select 
CDP_Measure_Name,
CDP_Measure_ID,
Case when CDP_Measure_ID like 'CDP_F%' then 'Quarterly' Else 'Monthly' End Reporting_Interval,
Reporting_Period 'Latest_SPC_Date',
case when Sum(UpperProcessLimit)> 0 then 'Y' else 'N' end 'SPC_Limits Applied',
case when Max(AssuranceIcon) is not null then 'Y' else 'N' end 'SPC Icons Applied'
from  [MHDInternal].[DASHBOARD_CDP_SPC]  
where Measure_Value is not null
and Is_Latest=1
Group by 
CDP_Measure_Name,
CDP_Measure_ID,
Case when CDP_Measure_ID like 'CDP_F%' then 'Quarterly' Else 'Monthly' End,
Reporting_Period
) SPC LEFT JOIN 
(Select CDP_Measure_ID,Reporting_Period From [MHDInternal].[DASHBOARD_CDP] where Is_latest=1) CDP
on SPC.CDP_Measure_ID=CDP.CDP_Measure_ID
--====================================================================================================================================================================================================--
-- STEP 8: CLEAR-UP
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step drops the temporary tables that were used
--
--====================================================================================================================================================================================================--

-- Remove temporary tables

--- RUN STEP 37/37
DROP TABLE [MHDInternal].[temp_CDP_SPC_MetricData]
DROP TABLE [MHDInternal].[temp_CDP_SPC_RawData]
DROP TABLE [MHDInternal].[temp_CDP_SPC_BaselineData]
DROP TABLE [MHDInternal].[temp_CDP_SPC_TargetData]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsPartition]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsBaseline]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsAllTargets]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSingleTarget]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsMean]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeProcessLimit]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsProcessLimits]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsBaselineLimits]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseSinglePoint]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShiftPrep]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCausePartitionCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlag]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlagCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShift]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPrep]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPartitionCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlag]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlagCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrend]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaPrep]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlag]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlagCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigma]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsIcons]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsRowCount]
--DROP TABLE [MHDInternal].[temp_CDP_SPC_Warnings]

-- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 7  complete, clear-up'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- COLUMN INDEX
--====================================================================================================================================================================================================--
--
-- COLUMN NAME                                                DATA TYPE      RETURNED      CREATION STEP(S)     VALUE
-- [CDP_Measure_ID]                                           Text           6: Output     3a / 3b / 3c / 3d    User-defined (optional for 3c / 3d)
-- [CDP_Measure_Name]                                         Text           6: Output     3a                   User-defined
-- [MetricConflictRule]                                       Text           No            3a                   User-defined or NULL
-- [MetricImprovement]                                        Text           No            3a                   User-defined
-- [LowMeanWarningValue]                                      Number         No            3a                   User-defined or NULL

-- [Reporting_Period]                                         Date           6: Output     3b / 3c              User-defined (or NULL and optional for 3c)
-- [Org_Code]                                                 Text           No            3b / 3c / 3d         User-defined (or NULL and optional for 3c / 3d)
-- [ICB_Code]                                                 Text           No            3b                   User-defined or NULL
-- [Measure_Value]                                            Number         6: Output     3b                   User-defined or NULL
-- [Annotation]                                               Text           6: Output     3b / 4b              User-defined or NULL (optional) turned blank
-- [ChartID]                                                  Text           6: Output     3b                   Concatenation of [CDP_Measure_ID], [GroupHierarchy] and [Org_Code]
-- [GhostValue]                                               Number         6: Output     3b                   Calculated from [GhostFlag] and [Measure_Value]
-- [GhostFlag]                                                Number         No            3b                   User-defined: 1 or 0
-- [RecalculateLimitsFlag]                                    Number         No            3b                   User-defined: 1 or 0

-- [BaselineOrder]                                            Number         No            3c                   User-defined (optional); distinct number; can be added automatically
-- [PointsExcludeGhosting]                                    Number         No            3c                   User-defined or NULL (optional)

-- [EndDate]                                                  Date           No            3d                   User-defined or NULL (optional)
-- [StartDate]                                                Date           No            3d                   User-defined or NULL (optional)
-- [Target]                                                   Number         6: Output     3d                   User-defined (optional)
-- [TargetOrder]                                              Number         No            3d                   User-defined (optional); distinct number; can be added automatically

-- [RowID]                                                    Text           6: Output     4b                   Concatenation of [CDP_Measure_ID], [Org_Code], and ascending order of [Reporting_Period]

-- [PointExcludeGhostingRankAscending]                        Number         No            4b                   ROW_NUMBER; NULL if [GhostFlag] = 1
-- [PointExcludeGhostingRankDescending]                       Number         No            4b                   ROW_NUMBER; NULL if [GhostFlag] = 1
-- [GroupName]                                                Text           6: Output     4b                   Concatenation of [GroupHierarchy], @SettingGroupHierarchyIndentSpaces (2b), and [Org_Code]
-- [PartitionID]                                              Number         No            4b / 4c              Calculated from [RecalculateLimitsFlag]
-- [PartitionIDExcludeGhosting]                               Number         No            4b / 4c              Calculated from [RecalculateLimitsFlag]; NULL if [GhostFlag] = 1

-- [BaselineEndFlag]                                          Number         No            4c                   Calculated from 3c: 1 or 0
-- [BaselineFlag]                                             Number         No            4c                   Calculated from [BaselineEndFlag]: 1 or 0
-- [BaselineEndRank]                                          Number         No            4c                   Calculated from 3c: NULL if [BaselineEndFlag] = 0

-- [TargetRank]                                               Number         No            4d                   Calculated from 3d

-- [PartitionMean]                                            Number         No            4e                   Calculated from [Mean]
-- [PartitionMovingRangeMean]                                 Number         No            4e                   Calculated from [MovingRangeMean]
-- [PartitionMovingRangeMeanForProcessLimits]                 Number         No            4e                   Calculated from [MovingRangeMean]
-- [LowerBaseline]                                            Number         6: Output     4e / 6               Calculated from [LowerProcessLimit]; NULL if [BaselineFlag] = 0 or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerOneSigma]                                            Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerProcessLimit]                                        Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerTwoSigma]                                            Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [Mean]                                                     Number         6: Output     4e                   Calculated from [MeanWithoutOutliers], and [Measure_Value]; NULL if [GhostFlag] = 1
-- [MeanWithoutOutliers]                                      Number         6: Output     4e                   Calculated from [Measure_Value]; NULL if [GhostFlag] = 1
-- [MovingRange]                                              Number         6: Output     4e                   Calculated from [Measure_Value]; NULL if [ChartType] not 'XmR' or [GhostFlag] = 1
-- [MovingRangeHighPointValue]                                Number         6: Output     4e / 6               Calculated from [MovingRangeMean], [MovingRange]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [MovingRangeMean]                                          Number         6: Output     4e                   Calculated from [MovingRangeWithPartition] and [PartitionMovingRangeMean]
-- [MovingRangeMeanForProcessLimits]                          Number         No            4e                   Calculated from [MovingRangeMean], [PartitionMovingRangeMeanForProcessLimits], and [MovingRangeMeanWithoutOutliers]
-- [MovingRangeMeanWithoutOutliers]                           Number         No            4e                   Calculated from [MovingRangeWithPartition]
-- [MovingRangeProcessLimit]                                  Number         6: Output     4e / 6               Calculated from [MovingRangeMean]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [MovingRangeWithPartition]                                 Number         No            4e                   Calculated from [Measure_Value]; ; NULL if [ChartType] not 'XmR' or [GhostFlag] = 1
-- [UpperBaseline]                                            Number         6: Output     4e / 6               Calculated from [UpperProcessLimit]; NULL if [BaselineFlag] = 0 or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperOneSigma]                                            Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperProcessLimit]                                        Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperTwoSigma]                                            Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints


-- [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    Number         No            4f                   Calculated from [LowerProcessLimit] and [Measure_Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    Number         No            4f                   Calculated from [UpperProcessLimit] and [Measure_Value]: 1 or 0; 0 if [GhostFlag] = 1

-- [SpecialCauseAboveMeanFlag]                                Number         No            4g                   Calculated from [Mean] and [Measure_Value]; 0 if [GhostFlag] = 1
-- [SpecialCauseAboveMeanPartitionCount]                      Number         No            4g                   Calculated from [SpecialCauseAboveMeanFlag]
-- [SpecialCauseBelowMeanFlag]                                Number         No            4g                   Calculated from [Mean] and [Measure_Value]; 0 if [GhostFlag] = 1
-- [SpecialCauseBelowMeanPartitionCount]                      Number         No            4g                   Calculated from [SpecialCauseBelowMeanFlag]
-- [SpecialCauseRuleShiftAboveMeanFlag]                       Number         No            4g                   Calculated from [SpecialCauseShiftAboveMeanStartFlagCount] and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseRuleShiftBelowMeanFlag]                       Number         No            4g                   Calculated from [SpecialCauseShiftBelowMeanStartFlagCount] and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseShiftAboveMeanStartFlag]                      Number         No            4g                   Calculated from [SpecialCauseAboveMeanFlag], [SpecialCauseAboveMeanPartitionCount], and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseShiftAboveMeanStartFlagCount]                 Number         No            4g                   Calculated from [SpecialCauseShiftAboveMeanStartFlag]
-- [SpecialCauseShiftBelowMeanStartFlag]                      Number         No            4g                   Calculated from [SpecialCauseBelowMeanFlag], [SpecialCauseBelowMeanPartitionCount], and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseShiftBelowMeanStartFlagCount]                 Number         No            4g                   Calculated from [SpecialCauseShiftBelowMeanStartFlag]

-- [SpecialCauseDecreasingFlag]                               Number         No            4h                   Calculated from [Measure_Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseDecreasingPartitionCount]                     Number         No            4h                   Calculated from [SpecialCauseDecreasingFlag]
-- [SpecialCauseIncreasingFlag]                               Number         No            4h                   Calculated from [Measure_Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseIncreasingPartitionCount]                     Number         No            4h                   Calculated from [SpecialCauseIncreasingFlag]
-- [SpecialCauseRuleTrendDecreasingFlag]                      Number         No            4h                   Calculated from [SpecialCauseTrendDecreasingStartFlagCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseRuleTrendIncreasingFlag]                      Number         No            4h                   Calculated from [SpecialCauseTrendIncreasingStartFlagCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseTrendDecreasingStartFlag]                     Number         No            4h                   Calculated from [SpecialCauseDecreasingPartitionCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseTrendDecreasingStartFlagCount]                Number         No            4h                   Calculated from [SpecialCauseTrendDecreasingStartFlag] 
-- [SpecialCauseTrendIncreasingStartFlag]                     Number         No            4h                   Calculated from [SpecialCauseIncreasingPartitionCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseTrendIncreasingStartFlagCount]                Number         No            4h                   Calculated from [SpecialCauseTrendIncreasingStartFlag] 

-- [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]               Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaAboveMeanFlag] and [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount]: 1 or 0
-- [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]               Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaBelowMeanFlag] and [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount]: 1 or 0
-- [SpecialCauseTwoThreeSigmaAboveMeanFlag]                   Number         No            4i                   Calculated from [UpperProcessLimit], [UpperTwoSigma] and [Measure_Value]: 1 or 0: 0 if [GhostFlag] = 1
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlag]              Number         No            4i                   Calculated from [SpecialCauseAboveMeanFlag] and [SpecialCauseTwoThreeSigmaAboveMeanFlag]: 1 or 0
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount]         Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaAboveMeanStartFlag]
-- [SpecialCauseTwoThreeSigmaBelowMeanFlag]                   Number         No            4i                   Calculated from [LowerProcessLimit], [LowerTwoSigma] and [Measure_Value]: 1 or 0: 0 if [GhostFlag] = 1
-- [SpecialCauseTwoThreeSigmaBelowMeanStartFlag]              Number         No            4i                   Calculated from [SpecialCauseBelowMeanFlag] and [SpecialCauseTwoThreeSigmaBelowMeanFlag]: 1 or 0
-- [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount]         Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaBelowMeanStartFlag]

-- [SpecialCauseConcernValue]                                 Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Measure_Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [SpecialCauseImprovementValue]                             Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Measure_Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [SpecialCauseConflictFlag]                                 Number         No            4j                   Calculated from [MetricConflictRule], [SpecialCauseConcernValue], and [SpecialCauseImprovementValue]: 1 or 0
-- [SpecialCauseNeitherHighFlag]                              Number         No            4j                   Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleTrendIncreasingFlag], and [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]: 1 or 0
-- [SpecialCauseNeitherLowFlag]                               Number         No            4j                   Calculated from [MetricImprovement], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], and [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]: 1 or 0
-- [SpecialCauseNeitherValue]                                 Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Measure_Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints

-- [AssuranceIcon]                                            Text           6: Output     4k / 6               Calculated from [LowerProcessLimit], [MetricImprovement], [Target] and [UpperProcessLimit]: NULL if [ChartType] not 'XmR' or [MetricImprovement] not 'Down' or 'Up' or [PointExcludeGhostingRankDescending] not 1 or [Target] = NULL or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [VariationIcon]                                            Text           6: Output     4k / 6               Calculated from [MetricImprovement], [SpecialCauseConcernValue], [SpecialCauseImprovementValue], [SpecialCauseNeitherHighFlag] and [SpecialCauseNeitherLowFlag]; NULL if [MetricImprovement] not 'Up', 'Down', or 'Neither' or [PointExcludeGhostingRankDescending] not 1 or [RowCountExcludeGhosting] < @SettingMinimumPoints

-- [RowCountExcludeGhosting]                                  Number         No            4l                   Calculated from [GhostFlag] 

-- [Detail]                                                   Text           5: Warning    5                    Various
-- [Warning]                                                  Text           5: Warning    5                    Various

--=========================================================================    NOT IN USE    =========================================================================================================
-- [MetricFormat]                                             Text           6: Output     3a                   User-defined
-- [DateFormat]                                               Text           6: Output     3a                   User-defined
-- [VerticalAxisMaxFix]                                       Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMaxFlex]                                      Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMinFix]                                       Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMinFlex]                                      Number         6: Output     3a                   User-defined or NULL
-- [ChartType]                                                Text           6: Output     3a                   User-defined
-- [ChartTitle]                                               Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank
-- [VerticalAxisTitle]                                        Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank
-- [HorizontalAxisTitle]                                      Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank

-- [Filter1]                                                  Text           6: Output     3b / 4b              User-defined or NULL (optional)
-- [Filter2]                                                  Text           6: Output     3b / 4b              User-defined or NULL (optional)

-- [GroupHierarchyOrder]                                      Number         No            4a                   User-defined or NULL (optional)
-- [GroupHierarchy]                                           Number         6: Output     4a                   Calculated from [Org_Code] and [ICB_Code] hierarchy (3b)
-- [GroupLevel]                                               Text           No            4a                   Calculated from [Org_Code] and [ICB_Code] hierarchy (3b)
-- [GroupOrder]                                               Number         6: Output     4a                   ROW_NUMBER from [GroupLevel]

-- [PointRank]                                                Text           6: Output     4b                   ROW_NUMBER if [ChartType] not 'XmR'; calculated from [Reporting_Period] if [ChartType] = 'XmR'

-- [DayDifference]                                            Number         No            4e                   Calculated from [Reporting_Period]; NULL if [ChartType] not 'T'
-- [DayDifferenceTransformed]                                 Number         No            4e                   Calculated from [DayDifference]
-- [DayDifferenceTransformedMean]                             Number         No            4e                   Calculated from [DayDifferenceTransformed]
-- [DayDifferenceTransformedMovingRange]                      Number         No            4e                   Calculated from [DayDifferenceTransformed]; NULL if [GhostFlag] = 1
-- [DayDifferenceTransformedMovingRangeMean]                  Number         No            4e                   Calculated from [DayDifferenceTransformedMovingRange]
-- [PartitionDayDifferenceTransformedMean]                    Number         No            4e                   Calculated from [DayDifferenceTransformedMean]
-- [PartitionDayDifferenceTransformedMovingRangeMean]         Number         No            4e                   Calculated from [DayDifferenceTransformedMovingRangeMean]

-- [IconID]                                                   Text           6: Output     4k                   Concatenation of [CDP_Measure_ID], [GroupHierarchy] and [Org_Code]; NULL if [PointExcludeGhostingRankDescending] not 1

--====================================================================================================================================================================================================--=============================================================================================================================================================================--
-- SPC CHARTS SQL QUERY v2.5
--====================================================================================================================================================================================================--
--
-- This SQL query is used to create statistical process control (SPC) charts
-- The chart types available are XmR (along with Pareto), T, and G
-- The output table can be used with the accompanying Power BI template to view the charts
-- The latest version of this, the accompanying tools, and the how-to guide can be found at: https://future.nhs.uk/MDC/view?objectId=28387280
--
-- The query is split into multiple steps:
--     • Step 1: This step is for initial setup
--     • Step 2: This step is for custom settings
--     • Step 3: This step is where the metric and raw data are inserted, and optionally baseline and target data too
--     • Step 4: This step is where the SPC calculations are performed, including special cause rules and icons
--     • Step 5: This step is where warnings are calculated and returned, if turned on
--     • Step 6: This step is where the SPC data is returned
--     • Step 7: This step is for clear-up
--
-- Steps 1, 4-5, and 7 are to be left as they are
-- Steps 2-3 are to be changed, and there is information at the beginning of these steps detailing what to change and which warnings are checked in Step 5
-- Step 6 only needs to be changed by storing the output in a table if the accompanying Power BI template is used and connected that way
--
-- At the end of each step, a message is printed so that progress can be monitored
-- At the end of the query, Column Index details all the columns used throughout the query
--
-- 'Partition' refers to where a chart is broken up by recalculation of limits or a baseline
-- Where no recalculation of limits is performed or baseline set, a chart has a single partition
--
-- This version has been tested on SQL Server 2012 and is not compatible with older versions (use SELECT @@VERSION to check your version)
-- Alternative versions that support older versions can be shared and found at: https://future.nhs.uk/MDC/view?objectId=30535408
--
-- For queries and feedback, please email england.improvementanalyticsteam@nhs.net and quote the name and version number

------------------------------------ CORE DATA PACK ADJUSTEMENTS TO MDC CODE ---------------------------------
-- CDP Replaced FIELDS:
-- [Date]        with [Reporting_Period] 
-- [MetricName]  with [CDP_Measure_Name]
-- [MetricID]    with [CDP_Measure_ID]
-- [MetricOrder] with [CDP_Measure_ID]
-- [Group]       with [Org_Code]
-- [GroupParent] with [ICB_Code]
-- [Value]       with [Measure_Value]

-- DELETED SECTIONS:
-- STEP 4A: HIERARCHY     AS NOT REQUIRED
-- Table would be SPCCalculations as below if in uses
--#SPCCalculationsHierarchy								  with [MHDInternal].[temp_CDP_SPC_CalculationsHierarchy]

--REPLACED TEMP TABLES:
--#MetricData											  with [MHDInternal].[temp_CDP_SPC_MetricData]
--#RawData												  with [MHDInternal].[temp_CDP_SPC_RawData]
--#BaselineData											  with [MHDInternal].[temp_CDP_SPC_BaselineData]
--#TargetData											  with [MHDInternal].[temp_CDP_SPC_TargetData]
--##SPCCalculationsDistinctGroups						  with [MHDInternal].[temp_CDP_SPC_CalculationsDistinctGroups]
--#SPCCalculationsPartition								  with [MHDInternal].[temp_CDP_SPC_CalculationsPartition]
--#SPCCalculationsBaselineFlag						      with [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
--#SPCCalculationsBaseline								  with [MHDInternal].[temp_CDP_SPC_CalculationsBaseline]
--#SPCCalculationsAllTargets							  with [MHDInternal].[temp_CDP_SPC_CalculationsAllTargets]
--#SPCCalculationsSingleTarget							  with [MHDInternal].[temp_CDP_SPC_CalculationsSingleTarget]
--#SPCCalculationsMean									  with [MHDInternal].[temp_CDP_SPC_CalculationsMean]
--#SPCCalculationsMovingRange                             with [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange]
--#SPCCalculationsMovingRangeMean                         with [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
--#SPCCalculationsMovingRangeProcessLimit                 with [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeProcessLimit]
--#SPCCalculationsProcessLimits                           with [MHDInternal].[temp_CDP_SPC_CalculationsProcessLimits]
--#SPCCalculationsBaselineLimits                          with [MHDInternal].[temp_CDP_SPC_CalculationsBaselineLimits]
--#SPCCalculationsSpecialCauseSinglePoint                 with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseSinglePoint]
--#SPCCalculationsSpecialCauseShiftPrep                   with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShiftPrep]
--#SPCCalculationsSpecialCauseShiftPartitionCount         with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCausePartitionCount]
--#SPCCalculationsSpecialCauseShiftStartFlag              with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlag]
--#SPCCalculationsSpecialCauseShiftStartFlagCount         with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlagCount]
--#SPCCalculationsSpecialCauseShift                       with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShift]
--#SPCCalculationsSpecialCauseTrendPrep                   with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPrep]
--#SPCCalculationsSpecialCauseTrendPartitionCount         with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPartitionCount]
--#SPCCalculationsSpecialCauseTrendStartFlag              with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlag]
--#SPCCalculationsSpecialCauseTrendStartFlagCount         with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlagCount]
--#SPCCalculationsSpecialCauseTrend                       with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrend]
--#SPCCalculationsSpecialCauseTwoThreeSigmaPrep           with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaPrep]
--#SPCCalculationsSpecialCauseTwoThreeSigmaStartFlag      with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlag]
--#SPCCalculationsSpecialCauseTwoThreeSigmaStartFlagCount with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlagCount]
--#SPCCalculationsSpecialCauseTwoThreeSigma               with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigma]
--#SPCCalculationsSpecialCauseCombined                    with [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
--#SPCCalculationsIcons                                   with [MHDInternal].[temp_CDP_SPC_CalculationsIcons]
--#SPCCalculationsRowCount                                with [MHDInternal].[temp_CDP_SPC_CalculationsRowCount]
--#Warnings                                               with [MHDInternal].[temp_CDP_SPC_Warnings]
--====================================================================================================================================================================================================--
-- STEP 1: SETUP
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step prepares the messages that display during execution 
-- and removes the temporary tables that will be used if they already exist
--
--====================================================================================================================================================================================================--

---- Prevent every row inserted returning a message 
--SET NOCOUNT ON

---- Prepare variable for messages printed at the end of each step
--DECLARE @PrintMessage NVARCHAR(MAX)

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 1  complete, setup'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 2A: SETTINGS: SPECIAL CAUSE
--====================================================================================================================================================================================================--
--
-- This step is where settings that determine how the process limits and special cause rules are calculated in Step 4 can be changed
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • @SettingSpecialCauseShiftPoints is not between 6 and 8 (inclusive)
--     • @SettingSpecialCauseTrendPoints is not between 6 and 8 (inclusive)
--
--====================================================================================================================================================================================================--

-- Removes moving range outliers from the calculation of the mean and process limits in XmR charts
-- ('1' = on | '0' = off)

--- RUN STEP 1/37
DECLARE @ExcludeMovingRangeOutliers BIT = 0

-- The number of non-ghosted points in a row within metric/group/partition combination all above or all below the mean to trigger the special cause rule of a shift
DECLARE @SettingSpecialCauseShiftPoints INT = 7

-- The number of non-ghosted points in a row within metric/group/partition combination either all increasing or all decreasing, including endpoints, to trigger the special cause rule of a trend
DECLARE @SettingSpecialCauseTrendPoints INT = 7

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 2a complete, settings: special cause'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 2B: SETTINGS: OTHER
--====================================================================================================================================================================================================--
--
-- This step is where various other settings can be changed, most of which are checked in Step 5
--
-- Warnings will be displayed, if turned on (first setting below) and:
--     • A chart has an insufficient number of points (set with @SettingMinimumPoints) and @SettingMinimumPointsWarning is turned on
--     • A partition in a chart has an insufficient number of points (set with @SettingMinimumPointsPartition)
--     • A partition in a chart has too many points (set with @SettingMaximumPointsPartition)
--     • A chart has too many points to be displayed on a chart (set with @SettingMaximumPoints)
--     • A point triggers improvement and concern special cause rules and @SettingPointConflictWarning is turned on
--     • A variation icon uses a point that triggers improvement and concern special cause rules and @SettingVariationIconConflictWarning is turned on
--
--====================================================================================================================================================================================================--

-- Check for warnings and output the results
-- ('1' = on | '0' = off)
DECLARE @SettingGlobalWarnings BIT = 1

-- The minimum number of non-ghosted points needed for each chart (metric/group combination) to display as an SPC chart
-- Will otherwise display as a run chart, with SPC elements removed
-- Ignores recalculating of limits
-- (set to 2 for no minimum)
DECLARE @SettingMinimumPoints INT = 15

    -- Return warning
    -- ('1' = on | '0' = off)
DECLARE @SettingMinimumPointsWarning BIT = 0

-- The minimum number of non-ghosted points needed for each step of a chart (metric/group/partition), including baselines
-- Ignored non-SPC charts
-- (set to 1 for no minimum)
DECLARE @SettingMinimumPointsPartition INT = 12

-- The maximum number of non-ghosted points allowed for each step of a chart (metric/group/partition), including baselines
-- (set to NULL for no maximum)
DECLARE @SettingMaximumPointsPartition INT = NULL

-- The maximum number of points the accompanying chart can accommodate
-- (set to NULL for no maximum)
DECLARE @SettingMaximumPoints INT = NULL

-- Return warning for non-ghosted points that trigger improvement and concern special cause rules
-- ('1' = on | '0' = off)
DECLARE @SettingPointConflictWarning BIT = 0

-- Return warning for variation icons that use a point that triggers improvement and concern special cause rules
-- ('1' = on | '0' = off)
DECLARE @SettingVariationIconConflictWarning BIT = 1

-- The number of spaces to indent each level of the group hierarchy
-- (Set to 0 for no indent)
DECLARE @SettingGroupHierarchyIndentSpaces INT = 4

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 2b complete, settings: other'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3A: METRIC DATA
--====================================================================================================================================================================================================--
--
-- This step is where the metric data is entered
--
-- The data must match the columns created in [MHDInternal].[temp_CDP_SPC_MetricData]
-- The data types can be changed, as detailed below, to reduce size
-- Additional columns can be added, which would then require their addition to Step 4b and Step 6.
--
-- [CDP_Measure_ID] and [CDP_Measure_Name] can be any value, even the same
-- [CDP_Measure_ID] is used to control the order the metrics appear in the dropdown; this is added automatically but could be manually controlled
-- [MetricImprovement] can be either 'Up', 'Down', or 'Neither'
-- [MetricConflictRule] can be either 'Improvement' or 'Concern' and determines which to show when special cause rules for both are triggered; this must be provided when [MetricImprovement] is 'Up' or 'Down'
-- [LowMeanWarningValue] can be specified to return a warning when the mean for any metric/group/filter/partition combination is less than the value; otherwise set as NULL
--
-- The data is populated from a table 
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [CDP_Measure_ID] does not exist in [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b)
--     • [CDP_Measure_ID] is duplicated
--     • [MetricImprovement] is not a valid option
--     • [MetricConflictRule] is not a valid option
--     • The mean is less than [LowMeanWarningValue] in any partition
--
--====================================================================================================================================================================================================--

--- RUN STEP 2/37
SELECT 
       m.CDP_Measure_ID,
       m.CDP_Measure_Name,
	   CASE WHEN m.Desired_Direction='Higher is better' THEN 'Up'
			WHEN m.Desired_Direction='Lower is better' THEN 'Down'
			ELSE NULL
	   END as MetricImprovement,
	   'Improvement' as MetricConflictRule,
	   'General' as MetricFormat,
	   NULL as LowMeanWarningValue

INTO [MHDInternal].[temp_CDP_SPC_MetricData] 
FROM [MHDInternal].[REFERENCE_CDP_METADATA] m

WHERE m.CDP_Measure_ID IN ('CDP_B01', 'CDP_B02', 'CDP_B03', 'CDP_B04','CDP_B05','CDP_D01','CDP_F01','CDP_F02','CDP_F03','CDP_M01')
  AND m.Measure_Type NOT IN ('Numerator', 'Denominator')

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3a complete, metric data'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3B: RAW DATA
--====================================================================================================================================================================================================--
--
-- This step is where the raw data is entered
--
-- The data must match the columns created in [MHDInternal].[temp_CDP_SPC_RawData]
-- The data types can be changed, as detailed below, to reduce size
-- Additional columns can be added, which would then require their addition to Step 4b and Step 6.
--
-- [Reporting_Period] must be unique for that metric/group/filter combination
-- [Is_Latest] --new
-- [CDP_Measure_ID] must match a row in [MHDInternal].[temp_CDP_SPC_MetricData]
-- [CDP_Measure_Name]
-- [Org_Type]
-- [Org_Code] code of organisation.
-- [Org_Name]
-- [ICB_Code] determines the hierarchy used in the dropdown and icon summary table; if specified, it must also exist as a group for any metric; otherwise set as NULL for the top level(s) or no hierarchy
-- [ICB_Name]
-- [Region_Code]
-- [Region_Name]
-- [Measure_Type]
-- [Measure_Value] must be a single value (i.e. post-calculation of any numerator and denominator); to enter times, enter the proportion of the day since midnight (e.g. 0.75 for 6pm)
-- [Measure_Value_STR]
-- [Last_Modified]
-- [RecalculateLimitsFlag] can be either '1' (on) or '0' (off)
-- [GhostFlag] can be either '1' (on) or '0' (off)
-- [Annotation] can be any text; otherwise set as NULL
--
-- The data can be inserted into [MHDInternal].[temp_CDP_SPC_RawData] one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples below)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [CDP_Measure_ID] does not exist in [MHDInternal].[temp_CDP_SPC_MetricData] (Step 3a)
--     • [ICB_Code] is not provided as a group
--     • Multiple [ICB_Code] are provided for same group
--     • [CDP_Measure_ID] and [Org_Code] concatenation includes '||' delimiter
--     • [Reporting_Period] is duplicated for metric/group/filter combination
--     • [Measure_Value] is not provided
--     • [RecalculateLimitsFlag] is not a valid option
--     • Recalculation of limits is within baseline (Step 3c)
--     • [GhostFlag] is not a valid option
--
--====================================================================================================================================================================================================--

--- RUN STEP 3/37
SELECT Reporting_Period,
       Is_Latest,
       CDP_Measure_ID,
       CDP_Measure_Name,
       Org_Type,
       Org_Code,
       Org_Name,
       ICB_Code,
       ICB_Name,
       Region_Code,
       Region_Name,
       Measure_Type,
       Measure_Value,
       Measure_Value_STR,
       Last_Modified,
	   CASE WHEN CDP_Measure_ID='CDP_D01'                                              THEN CASE WHEN Reporting_Period = '2020-03-31' 
																								 THEN 1
																								 WHEN Reporting_Period = '2021-04-30'
																								 THEN 1
																								 WHEN Reporting_Period = '2023-03-31'
																								 THEN 1
																								 ELSE 0 END
            WHEN CDP_Measure_ID IN ('CDP_B01','CDP_B02','CDP_B03','CDP_B04','CDP_B05') THEN CASE WHEN Reporting_Period = '2020-03-31' 
																								 THEN 1
																								 WHEN Reporting_Period = '2021-04-30'
																								 THEN 1
																								 ELSE 0 END
	   ELSE 0
	   END as RecalculateLimitsFlag,
	   0 as GhostFlag,
	   NULL as Annotation

  INTO [MHDInternal].[temp_CDP_SPC_RawData]

  FROM [MHDInternal].[DASHBOARD_CDP]
 WHERE CDP_Measure_ID IN ('CDP_B01', 'CDP_B02', 'CDP_B03', 'CDP_B04','CDP_B05','CDP_D01','CDP_F01','CDP_F02','CDP_F03','CDP_M01')
   AND Measure_Type NOT IN ('Numerator', 'Denominator')

--SELECT *
--FROM [MHDInternal].[temp_CDP_SPC_RawData]
---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3b complete, raw data'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3C: BASELINE DATA
--====================================================================================================================================================================================================--
--
-- This step is where the baseline data is entered
-- If there are no baselines, do not insert any data into [MHDInternal].[temp_CDP_SPC_BaselineData] but do not remove the table creation
--
-- The data must match the columns created in [MHDInternal].[temp_CDP_SPC_BaselineData]
-- The data types can be changed, as detailed below, to reduce size
--
-- [BaselineOrder] is used to control which baseline to keep if multiple are provided; this is added automatically but could be manually controlled; if multiple baselines are provided for any metric/group combination, the first is used
-- [CDP_Measure_ID] must match a row in [MHDInternal].[temp_CDP_SPC_MetricData] and [MHDInternal].[temp_CDP_SPC_RawData]
-- [Org_Code] must match a row in [MHDInternal].[temp_CDP_SPC_RawData]; if set as NULL, it will be applied to all groups
-- [Reporting_Period] and/or [PointsExcludeGhosting] must be provided; if both are provided and conflict, [Reporting_Period] is used
--     • This is the last point in the baseline, similar to recalculating the next point
--
-- The data can be inserted into [MHDInternal].[temp_CDP_SPC_BaselineData] one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples in Step 3b)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [BaselineOrder] is duplicated
--     • [CDP_Measure_ID] does not exist in [MHDInternal].[temp_CDP_SPC_MetricData] (Step 3a) or [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b)
--     • [Org_Code] does not exist in [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b) for that metric
--     • [Reporting_Period] does not exist in [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b) for that metric for either that group (if specified) or at least one group (if not specified)
--     • Multiple baselines are provided for metric/group combination
--     • Baseline includes special cause variation
--
--====================================================================================================================================================================================================--

-- Create temporary table

--- RUN STEP 4/37
CREATE TABLE [MHDInternal].[temp_CDP_SPC_BaselineData] (
                             [BaselineOrder]         INT           IDENTITY(1, 1) NOT NULL -- IDENTITY(1, 1) can be removed
                            ,[CDP_Measure_ID]              NVARCHAR(MAX)                NOT NULL -- Can be reduced in size
                            ,[Org_Code]                 NVARCHAR(MAX)                    NULL -- Can be reduced in size
                            ,[Reporting_Period]                  DATE                             NULL
                            ,[PointsExcludeGhosting] INT                              NULL
                           )

-- Insert sample data for various baselines
--INSERT INTO [MHDInternal].[temp_CDP_SPC_BaselineData]
--SELECT 
--       CDP_Measure_ID,
--       Org_Code,
--       NULL as Reporting_Period,
--	   NULL as [PointsExcludeGhosting]

--  FROM [MHDInternal].[DASHBOARD_CDP]
-- WHERE CDP_Measure_ID = 'CDP_D01'
--   AND Measure_Type NOT IN ('Numerator', 'Denominator')

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3c complete, baseline data'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 3D: TARGET DATA
--====================================================================================================================================================================================================--
--
-- This step is where the target data is entered for XmR charts
-- If there are no targets, do not insert any data into [MHDInternal].[temp_CDP_SPC_TargetData] but do not remove the table creation
--
-- The data must match the columns created in [MHDInternal].[temp_CDP_SPC_TargetData]
-- The data types can be changed, as detailed below, to reduce size
--
-- [TargetOrder] is used to control which target to keep if multiple are provided; this is added automatically but could be manually controlled; if multiple targets are provided for any metric/group/date combination, the first is used
-- [CDP_Measure_ID] must match a row in [MHDInternal].[temp_CDP_SPC_MetricData] and [MHDInternal].[temp_CDP_SPC_RawData]
-- [Org_Code] must match a row in [MHDInternal].[temp_CDP_SPC_RawData]; if set as NULL, it will be applied to all groups
-- [Target] must be provided
-- [StartDate] and/or [EndDate] can be left as NULL
--
-- The data can be inserted into [MHDInternal].[temp_CDP_SPC_TargetData] one line at a time, as shown in the sample data below, or populated from a table or stored procedure (see examples in Step 3b)
-- The accompanying Excel file also contains a worksheet to generate INSERT lines
--
-- Warnings will be displayed, if turned on (set in Step 2b) and:
--     • [TargetOrder] is duplicated
--     • [CDP_Measure_ID] does not exist in [MHDInternal].[temp_CDP_SPC_MetricData] (Step 3a) or [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b)
--     • [Org_Code] does not exist in [MHDInternal].[temp_CDP_SPC_RawData] (Step 3b) for that metric
--     • [StartDate] is after [EndDate]
--     • Multiple targets are provided for metric/group/date combination
--     • Target provided for metric when [MetricImprovement] is not 'Up' or 'Down'
--
--====================================================================================================================================================================================================--

--- RUN STEP 5/37
CREATE TABLE [MHDInternal].[temp_CDP_SPC_TargetData] (
                           [TargetOrder] INT             IDENTITY(1, 1) NOT NULL -- IDENTITY(1, 1) can be removed
						  ,[Reporting_Period]  DATETIME NULL
                          ,[CDP_Measure_ID]    NVARCHAR(MAX)                  NOT NULL -- Can be reduced in size
                          ,[Org_Code]       NVARCHAR(MAX)                      NULL -- Can be reduced in size
                          ,[Target]      DECIMAL(38, 19)                  NULL -- Can be reduced in size (might affect accuracy of calculations)
						  ,[Target_STR] nvarchar(4000)                     NULL
                         )
INSERT INTO [MHDInternal].[temp_CDP_SPC_TargetData]
SELECT 
	   Reporting_Period,
	   CDP_Measure_ID,
	   Org_Code,
       COALESCE([Standard],[LTP_Trajectory]) AS [Target],
	   COALESCE([Standard_STR],[LTP_Trajectory_STR]) AS [Target_STR]

  FROM [MHDInternal].[DASHBOARD_CDP]
 WHERE CDP_Measure_ID IN ('CDP_B01', 'CDP_B02', 'CDP_B03', 'CDP_B04','CDP_B05','CDP_D01','CDP_F01','CDP_F02','CDP_F03','CDP_M01')
   AND Measure_Type NOT IN ('Numerator', 'Denominator') 

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 3d complete, target data'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4A: HIERARCHY
--====================================================================================================================================================================================================--
--
-- Deleted not required
--
--====================================================================================================================================================================================================--
-- STEP 4B: PARTITIONS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step combines data and adds partitions
--
--====================================================================================================================================================================================================--

-- Join metric and raw data along with the hierarchy
-- Add row ID (used for self-joins below) and chart ID
-- Add point rank (used for baselines and icons)
-- Replace NULL in [Annotation] with empty text
-- Add dropdown version of group with indentation
-- Add partitions for each metric/org combination based on when limits are recalculated, including partition without ghosted points (used for mean and moving range calculations)

--- RUN STEP 6/37
DECLARE @SettingGroupHierarchyIndentSpaces INT = 4
SELECT   
	     [RowID]                              = CONCAT(r.[CDP_Measure_ID], '||', r.[Org_Code], '||', ROW_NUMBER()  OVER(PARTITION BY m.[CDP_Measure_ID], r.Org_Code ORDER BY r.[Reporting_Period])) 
      ,  [ChartID]                            = CONCAT(r.[CDP_Measure_ID], '||', r.[Org_Code])                     
      ,  [PointExcludeGhostingRankAscending]  = CASE WHEN r.[GhostFlag] = 1 THEN NULL                                                                                                                                                          
                                                     ELSE ROW_NUMBER()  OVER(PARTITION BY m.[CDP_Measure_ID], r.Org_Code, r.[GhostFlag] ORDER BY r.[Reporting_Period] ASC) END
      ,  [PointExcludeGhostingRankDescending] = CASE WHEN r.[GhostFlag] = 1 THEN NULL                                                                                                                                                                        
                                                     ELSE ROW_NUMBER()  OVER(PARTITION BY m.[CDP_Measure_ID], r.Org_Code, r.[GhostFlag] ORDER BY r.[Reporting_Period] DESC) END
      ,m.[CDP_Measure_ID]                                                                                  
      ,m.[MetricImprovement]
      ,m.[MetricConflictRule]
      ,m.[LowMeanWarningValue]
      ,r.[Org_Code]
	  ,r.[Reporting_Period]
	  ,r.Is_Latest
	  ,r.CDP_Measure_Name
	  ,r.Org_Type
	  ,r.Org_Name
	  ,r.ICB_Code
	  ,r.ICB_Name
	  ,r.Region_Code
	  ,r.Region_Name
	  ,r.Measure_Type
      ,r.[Measure_Value]  
	  ,r.Measure_Value_STR
	  ,r.Last_Modified
      ,r.[RecalculateLimitsFlag]                 
      ,r.[GhostFlag]                             
      ,  [Annotation]                         = ISNULL(r.[Annotation], '')
      ,  [PartitionID]                        = SUM(r.[RecalculateLimitsFlag]) OVER(PARTITION BY r.[CDP_Measure_ID], r.[Org_Code] ORDER BY r.[Reporting_Period]) + 1
      ,  [PartitionIDExcludeGhosting]         = CASE WHEN r.[GhostFlag] = 1 THEN NULL
                                                                            ELSE SUM(r.[RecalculateLimitsFlag]) OVER(PARTITION BY r.[CDP_Measure_ID], r.[Org_Code] ORDER BY r.[Reporting_Period]) + 1 END
																			
INTO [MHDInternal].[temp_CDP_SPC_CalculationsPartition]
FROM [MHDInternal].[temp_CDP_SPC_MetricData]                         AS m
    INNER JOIN [MHDInternal].[temp_CDP_SPC_RawData]                  AS r ON r.[CDP_Measure_ID] = m.[CDP_Measure_ID]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4b complete, partitions'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4C: BASELINES
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds baselines and then updates partitions
--
--====================================================================================================================================================================================================--

-- Add baseline end flags
-- If multiple baselines are provided for metric/group combination, add rank for updating below
-- If both [Reporting_Period] and [PointsExcludeGhosting] are provided and these conflict, use [Reporting_Period]

--- RUN STEP 7/37
SELECT p.*
      ,  [BaselineEndFlag] = CASE WHEN b.[CDP_Measure_ID] IS NOT NULL THEN 1
                                                                ELSE 0 END
      ,  [BaselineEndRank] = CASE WHEN b.[CDP_Measure_ID] IS NOT NULL THEN ROW_NUMBER() OVER(PARTITION BY p.[ChartID], b.[CDP_Measure_ID] ORDER BY b.[BaselineOrder], CASE WHEN b.[Reporting_Period] = p.[Reporting_Period] THEN 0

  ELSE 1 END) END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsPartition] AS p
LEFT JOIN [MHDInternal].[temp_CDP_SPC_BaselineData]        AS b ON b.[CDP_Measure_ID]                 = p.[CDP_Measure_ID]
                                   AND ISNULL(b.[Org_Code], p.[Org_Code]) = p.[Org_Code]
                                   AND (b.[Reporting_Period]                    = p.[Reporting_Period]
                                     OR b.[PointsExcludeGhosting]   = p.[PointExcludeGhostingRankAscending])

-- When extra baselines are provided for metric/group combination, remove based on rank
UPDATE [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
SET [BaselineEndFlag] = 0
WHERE [BaselineEndFlag] = 1
  AND [BaselineEndRank] > 1

--- RUN STEP 8/37
-- Add baseline flag for all points up to and including baseline end flag for metric/group combination
SELECT bf1.*
      ,    [BaselineFlag] = CASE WHEN bf1.[Reporting_Period] <= bf2.[Reporting_Period] THEN 1
                                                               ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsBaseline]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag] AS bf1
LEFT JOIN (
            SELECT [ChartID]
                  ,[Org_Code]
                  ,[Reporting_Period]
            FROM [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
            WHERE [BaselineEndFlag] = 1
          ) AS bf2 ON bf2.[ChartID] = bf1.[ChartID]

-- Update partition IDs for baseline points
UPDATE [MHDInternal].[temp_CDP_SPC_CalculationsBaseline]
SET [PartitionID]                = 0
   ,[PartitionIDExcludeGhosting] = CASE WHEN [GhostFlag] = 1 THEN NULL
                                                             ELSE 0 END
WHERE [BaselineFlag] = 1

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4c complete, baselines'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4D: TARGETS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds targets for XmR charts
--
--====================================================================================================================================================================================================--

-- Add targets
-- If multiple targets are provided for metric/org/date combination, add rank for updating below
-- If metric improvement is 'neither', ignore

--- RUN STEP 9/37
SELECT b.*
      ,t.[Target]
	  ,t.[Target_STR]
      --,  [TargetRank] = ROW_NUMBER() OVER(PARTITION BY b.[ChartID], b.[Reporting_Period] ORDER BY t.[TargetOrder])
	  ,[TargetRank] = ROW_NUMBER() OVER(PARTITION BY b.[ChartID], b.[Reporting_Period] ORDER BY t.[TargetOrder], t.Reporting_Period)

 INTO [MHDInternal].[temp_CDP_SPC_CalculationsAllTargets]

 FROM [MHDInternal].[temp_CDP_SPC_CalculationsBaseline] AS b

LEFT JOIN [MHDInternal].[temp_CDP_SPC_TargetData] AS t 
       ON t.[CDP_Measure_ID] = b.[CDP_Measure_ID]
      AND ISNULL(t.[Org_Code], b.[Org_Code]) = b.[Org_Code]
      AND b.[Reporting_Period] = t.[Reporting_Period]
    --AND ISNULL(t.[StartDate], b.[Reporting_Period]) <= b.[Reporting_Period]
    --AND ISNULL(t.[EndDate], b.[Reporting_Period]) >= b.[Reporting_Period]
      AND b.[MetricImprovement] IN ('Up', 'Down')

--- RUN STEP 10/37
-- When extra targets are provided for metric/group/date combination, remove all but the first
SELECT *
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSingleTarget]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsAllTargets]
WHERE [TargetRank] = 1

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4d complete, targets'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4E: PROCESS LIMITS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates the mean, moving range, and process limits
--
--====================================================================================================================================================================================================--

--- RUN STEP 11/37
SELECT *
      ,[Mean] = CASE WHEN [GhostFlag] = 1   THEN NULL
                     ELSE AVG([Measure_Value]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting]) END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsMean]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSingleTarget]

-- Add moving range for XmR charts, based on absolute difference from previous point, for each metric/group/partition/filter combination, excluding ghosted points and first non-ghosted point in partition
-- Add moving range without partition for use in mR chart

--- RUN STEP 12/37
SELECT *
      ,[MovingRangeWithPartition]            = CASE WHEN [GhostFlag] = 1     THEN NULL
                                                    ELSE ABS([Measure_Value]                    - LAG([Measure_Value], 1)                    OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])) END
      ,[MovingRange]                         = CASE WHEN [GhostFlag] = 1     THEN NULL                                                                
                                                    ELSE ABS([Measure_Value]                    - LAG([Measure_Value], 1)                    OVER(PARTITION BY [ChartID], [GhostFlag]                  ORDER BY [Reporting_Period])) END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMean]

-- Add moving range mean for each metric/group/filter/partition combination, excluding those with no moving range (i.e ghosted points and first non-ghosted point in partition)
-- Create duplicate, for updating below, to be used specifically for process limit calculations

--- RUN STEP 13/37
SELECT  mr.*
      ,mrm.[MovingRangeMean]
      ,    [MovingRangeMeanForProcessLimits] = mrm.[MovingRangeMean]
INTO [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange] AS mr
LEFT JOIN (
            SELECT *
                  ,[MovingRangeMean] = AVG([MovingRangeWithPartition]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting])
            FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange]
            WHERE [MovingRangeWithPartition] IS NOT NULL
           ) mrm ON mrm.[RowID] = mr.[RowID]

--- RUN STEP 14/37
-- Checks for setting (set in Step 2a)
DECLARE @ExcludeMovingRangeOutliers BIT = 0
IF @ExcludeMovingRangeOutliers = 1

    BEGIN
 
         -- Update moving range mean by recalculating with moving range outliers removed
        UPDATE mrm
        SET [MovingRangeMeanForProcessLimits] = [MovingRangeMeanWithoutOutliers]
        FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
        LEFT JOIN (
                    SELECT DISTINCT
                           [MovingRangeMeanWithoutOutliers] = AVG([MovingRangeWithPartition]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting])
                          ,[ChartID]
                          ,[PartitionID]
                    FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
                    WHERE [MovingRangeWithPartition] <= [MovingRangeMean] * 3.267
                  ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                           AND mrm2.[PartitionID] = mrm.[PartitionID]

        -- Update mean by recalculating with moving range outliers removed
        UPDATE mrm
        SET [Mean] = [MeanWithoutOutliers]
        FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
        LEFT JOIN (
                    SELECT DISTINCT
                           [MeanWithoutOutliers] = CASE WHEN [GhostFlag] = 1 THEN NULL
                                                                             ELSE AVG([Measure_Value]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting]) END
                          ,[ChartID]
                          ,[PartitionID]
                    FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
                    WHERE [MovingRangeWithPartition] <= [MovingRangeMean] * 3.267
                       OR [MovingRangeWithPartition] IS NULL
                  ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                           AND mrm2.[PartitionID] = mrm.[PartitionID]

    END

-- Update mean for those skipped above (i.e. ghosted points) by copying from mean within metric/group/filter/partition combination
UPDATE mrm
SET mrm.[Mean] = mrm2.[PartitionMean]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
LEFT JOIN (
            SELECT DISTINCT
                   [ChartID]
                  ,[PartitionID]
                  ,[PartitionMean] = AVG([Mean]) OVER(PARTITION BY [ChartID], [PartitionID])
            FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
            WHERE [Mean] IS NOT NULL
          ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                   AND mrm2.[PartitionID] = mrm.[PartitionID]

-- Update moving range mean for those skipped above (i.e. ghosted points and first non-ghosted point in partition) by copying from moving range mean within metric/group/filter/partition combination
UPDATE mrm
SET mrm.[MovingRangeMean]                 = mrm2.[PartitionMovingRangeMean]
   ,mrm.[MovingRangeMeanForProcessLimits] = mrm2.[PartitionMovingRangeMeanForProcessLimits]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
LEFT JOIN (
            SELECT DISTINCT
                   [ChartID]
                  ,[PartitionID]
                  ,[PartitionMovingRangeMean]                 = AVG([MovingRangeMean])                 OVER(PARTITION BY [ChartID], [PartitionID])
                  ,[PartitionMovingRangeMeanForProcessLimits] = AVG([MovingRangeMeanForProcessLimits]) OVER(PARTITION BY [ChartID], [PartitionID])
            FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
            WHERE [MovingRangeMean] IS NOT NULL
          ) AS mrm2 ON mrm2.[ChartID]     = mrm.[ChartID]
                   AND mrm2.[PartitionID] = mrm.[PartitionID]

-- Update mean, moving range mean for first partition after baseline within metric/group/filter/partition combination when a baseline is set
UPDATE mrm
SET mrm.[Mean]                                    = mrm2.[Mean]
   ,mrm.[MovingRangeMean]                         = mrm2.[MovingRangeMean]
   ,mrm.[MovingRangeMeanForProcessLimits]         = mrm2.[MovingRangeMeanForProcessLimits]

FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean] AS mrm
INNER JOIN (
             SELECT DISTINCT
                    [ChartID]
                   ,[PartitionID]
                   ,[Mean]
                   ,[MovingRangeMean]
                   ,[MovingRangeMeanForProcessLimits]
             FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
             WHERE [PartitionID] = 0
           ) AS mrm2 ON mrm2.[ChartID] = mrm.[ChartID]
WHERE mrm.[PartitionID] = 1

-- Add moving range process limit and high point value

--- RUN STEP 15/37
SELECT *
      ,[MovingRangeProcessLimit]   =                           [MovingRangeMean] * 3.267
      ,[MovingRangeHighPointValue] = CASE WHEN [MovingRange] > [MovingRangeMean] * 3.267 THEN [MovingRange] END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeProcessLimit]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]

-- Add upper and lower process limits along with one and two sigma lines

--- RUN STEP 16/37
SELECT *
      ,[UpperProcessLimit] = [Mean] + [MovingRangeMeanForProcessLimits] * 2.66
      ,[UpperTwoSigma]     = [Mean] + [MovingRangeMeanForProcessLimits] * 2.66 * (2 / 3.0)   
      ,[UpperOneSigma]     = [Mean] + [MovingRangeMeanForProcessLimits] * 2.66 * (1 / 3.0)
      ,[LowerOneSigma]     = [Mean] - [MovingRangeMeanForProcessLimits] * 2.66 * (1 / 3.0) 
      ,[LowerTwoSigma]     = [Mean] - [MovingRangeMeanForProcessLimits] * 2.66 * (2 / 3.0)
      ,[LowerProcessLimit] = [Mean] - [MovingRangeMeanForProcessLimits] * 2.66

INTO [MHDInternal].[temp_CDP_SPC_CalculationsProcessLimits]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeProcessLimit]

-- Add upper and lower process limits for baselines

--- RUN STEP 17/37
SELECT *
      ,[UpperBaseline] = CASE WHEN [BaselineFlag] = 1 THEN [UpperProcessLimit] END
      ,[LowerBaseline] = CASE WHEN [BaselineFlag] = 1 THEN [LowerProcessLimit] END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsBaselineLimits]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsProcessLimits]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4e complete, process limits'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4F: SPECIAL CAUSE - SINGLE POINT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a single point beyond the process limits
--
--====================================================================================================================================================================================================--

-- Add special cause flag for single non-ghosted points beyond upper or lower process limits

--- RUN STEP 18/37
SELECT *
      ,[SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag] = CASE WHEN [GhostFlag] = 1               THEN 0
                                                                      WHEN [Measure_Value] > [UpperProcessLimit] THEN 1
                                                                                                         ELSE 0 END
      ,[SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag] = CASE WHEN [GhostFlag] = 1               THEN 0
                                                                      WHEN [Measure_Value] < [LowerProcessLimit] THEN 1
                                                                                                         ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseSinglePoint]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsBaselineLimits]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4f complete, special cause: single point'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4G: SPECIAL CAUSE - SHIFT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a shift of points all above or below the mean
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for a shift of non-ghosted points all above or all below the mean by flagging whether the non-ghosted point is above or below the mean

--- RUN STEP 19/37
SELECT *
      ,[SpecialCauseAboveMeanFlag] = CASE WHEN [GhostFlag] = 1  THEN 0
                                          WHEN [Measure_Value] > [Mean] THEN 1
                                                                ELSE 0 END
      ,[SpecialCauseBelowMeanFlag] = CASE WHEN [GhostFlag] = 1  THEN 0
                                          WHEN [Measure_Value] < [Mean] THEN 1
                                                                ELSE 0 END 
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShiftPrep]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseSinglePoint]

-- Add cumulative sum of the above and below mean flags for non-ghosted points within metric/group/filter/partition combination

--- RUN STEP 20/37
SELECT *
      ,[SpecialCauseAboveMeanPartitionCount] = SUM([SpecialCauseAboveMeanFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
      ,[SpecialCauseBelowMeanPartitionCount] = SUM([SpecialCauseBelowMeanFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCausePartitionCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShiftPrep]

-- Determine, depending on setting (set in Step 2a), each non-ghosted point that starts a shift of X non-ghosted points all above or all below the mean within metric/group/filter/partition combination

--- RUN STEP 21/37
DECLARE @SettingSpecialCauseShiftPoints INT = 7
SELECT *
      ,[SpecialCauseShiftAboveMeanStartFlag] = CASE WHEN [SpecialCauseAboveMeanFlag] = 1
                                                     AND LEAD([SpecialCauseAboveMeanPartitionCount], @SettingSpecialCauseShiftPoints - 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) - [SpecialCauseAboveMeanPartitionCount] = @SettingSpecialCauseShiftPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                                   ELSE 0 END
      ,[SpecialCauseShiftBelowMeanStartFlag] = CASE WHEN [SpecialCauseBelowMeanFlag] = 1
                                                     AND LEAD([SpecialCauseBelowMeanPartitionCount], @SettingSpecialCauseShiftPoints - 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) - [SpecialCauseBelowMeanPartitionCount] = @SettingSpecialCauseShiftPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                                   ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlag]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCausePartitionCount]

-- Add cumulative sum of the above and below mean start-of-shift flags for non-ghosted points within metric/group/filter/partition combination

--- RUN STEP 22/37
SELECT *
      ,[SpecialCauseShiftAboveMeanStartFlagCount] = SUM([SpecialCauseShiftAboveMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
      ,[SpecialCauseShiftBelowMeanStartFlagCount] = SUM([SpecialCauseShiftBelowMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlagCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlag]

-- Determine, depending on setting (set in Step 2a), each point within a shift of X non-ghosted points all above or all below the mean
-- This is done by comparing the above/below mean start-of-shift flag count with that X non-ghosted points prior within metric/group/filter/partition combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseShiftAboveMeanStartFlagCount] will only be higher if there is at least one point within the last X non-ghosted points within metric/group/filter/partition combination that starts an above/below mean shift

--- RUN STEP 23/37
DECLARE @SettingSpecialCauseShiftPoints INT = 7
SELECT *
      ,[SpecialCauseRuleShiftAboveMeanFlag] = CASE WHEN [SpecialCauseShiftAboveMeanStartFlagCount] > ISNULL(LAG([SpecialCauseShiftAboveMeanStartFlagCount], @SettingSpecialCauseShiftPoints) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                                            ELSE 0 END
      ,[SpecialCauseRuleShiftBelowMeanFlag] = CASE WHEN [SpecialCauseShiftBelowMeanStartFlagCount] > ISNULL(LAG([SpecialCauseShiftBelowMeanStartFlagCount], @SettingSpecialCauseShiftPoints) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                                            ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShift]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlagCount]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4g complete, special cause: shift'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4H: SPECIAL CAUSE - TREND
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for a trend increasing or decreasing points, including endpoints, and works across partitions
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for a trend of increasing or decreasing non-ghosted points by flagging whether the non-ghosted point is greater than or less than the previous non-ghosted point within metric/group/filter combination

--- RUN STEP 24/37
SELECT *
      ,[SpecialCauseIncreasingFlag] = CASE WHEN [GhostFlag] = 1                                                                               THEN 0
                                           WHEN [Measure_Value] > LAG([Measure_Value], 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]) THEN 1
                                                                                                                                              ELSE 0 END
      ,[SpecialCauseDecreasingFlag] = CASE WHEN [GhostFlag] = 1                                                                               THEN 0
                                           WHEN [Measure_Value] < LAG([Measure_Value], 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]) THEN 1
                                                                                                                                              ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPrep]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShift]

-- Add cumulative sum of the increasing and decreasing flags for non-ghosted points within metric/group/filter combination

--- RUN STEP 25/37
SELECT *
      ,[SpecialCauseIncreasingPartitionCount] = SUM([SpecialCauseIncreasingFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period])
      ,[SpecialCauseDecreasingPartitionCount] = SUM([SpecialCauseDecreasingFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPartitionCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPrep]

-- Determine, depending on setting (set in Step 2a), each non-ghosted point that starts a trend of X increasing or decreasing non-ghosted points within metric/group/filter combination

--- RUN STEP 26/37
DECLARE @SettingSpecialCauseTrendPoints INT = 7
SELECT *
      ,[SpecialCauseTrendIncreasingStartFlag] = CASE WHEN LEAD([SpecialCauseIncreasingPartitionCount], @SettingSpecialCauseTrendPoints - 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]) - [SpecialCauseIncreasingPartitionCount] = @SettingSpecialCauseTrendPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                     ELSE 0 END
      ,[SpecialCauseTrendDecreasingStartFlag] = CASE WHEN LEAD([SpecialCauseDecreasingPartitionCount], @SettingSpecialCauseTrendPoints - 1) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]) - [SpecialCauseDecreasingPartitionCount] = @SettingSpecialCauseTrendPoints - 1 THEN 1
                                                                                                                                                                                                                                                                                     ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlag]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPartitionCount]

-- Add cumulative sum of the increasing and decreasing start-of-trend flags for non-ghosted points within metric/group/filter combination

--- RUN STEP 27/37
SELECT *
      ,[SpecialCauseTrendIncreasingStartFlagCount] = SUM([SpecialCauseTrendIncreasingStartFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period])
      ,[SpecialCauseTrendDecreasingStartFlagCount] = SUM([SpecialCauseTrendDecreasingStartFlag]) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlagCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlag]

-- Determine, depending on setting (set in Step 2a), each non-ghosted point within a trend of X non-ghosted points all increasing or all decreasing, including endpoints
-- This is done by comparing the increasing/decreasing start-of-trend flag count with that X non-ghosted points prior within metric/group/filter combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseTrendAboveMeanStartFlagCount] will only be higher if there is at least one point within the last X non-ghosted points within metric/group/filter combination that starts an increasing/decreasing trend

--- RUN STEP 28/37
DECLARE @SettingSpecialCauseTrendPoints INT = 7
SELECT *
      ,[SpecialCauseRuleTrendIncreasingFlag] = CASE WHEN [SpecialCauseTrendIncreasingStartFlagCount] > ISNULL(LAG([SpecialCauseTrendIncreasingStartFlagCount], @SettingSpecialCauseTrendPoints) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                              ELSE 0 END
      ,[SpecialCauseRuleTrendDecreasingFlag] = CASE WHEN [SpecialCauseTrendDecreasingStartFlagCount] > ISNULL(LAG([SpecialCauseTrendDecreasingStartFlagCount], @SettingSpecialCauseTrendPoints) OVER(PARTITION BY [ChartID], [GhostFlag] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                              ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrend]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlagCount]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4h complete, special cause: trend'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4I: SPECIAL CAUSE - TWO-TO-THREE SIGMA
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step calculates points that trigger the special cause rule for there being two or three points within a run of three that lie beyond the two-sigma line but not beyond the three-sigma line (i.e. process limit) on a consistent side of the mean
-- If the third point is not also within this range, it needs to be on the same side of the mean
--
--====================================================================================================================================================================================================--

-- Prepare for special cause flag for two/three of three non-ghosted points within a run of three all beyond two sigma but not beyond three sigma, all on the same side of the mean

--- RUN STEP 29/37
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanFlag] = CASE WHEN [GhostFlag] = 1                THEN 0
                                                       WHEN [Measure_Value] > [UpperTwoSigma]
                                                        AND [Measure_Value] <= [UpperProcessLimit] THEN 1
                                                                                           ELSE 0 END
      ,[SpecialCauseTwoThreeSigmaBelowMeanFlag] = CASE WHEN [GhostFlag] = 1                THEN 0
                                                       WHEN [Measure_Value] < [LowerTwoSigma]
                                                        AND [Measure_Value] >= [LowerProcessLimit] THEN 1
                                                                                           ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaPrep]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrend]

-- Determine each non-ghosted point that is flagged and starts a group of two or three non-ghosted two-to-three sigma points, all on the same side of the mean, within a run of three, within metric/group/filter/partition combination
-- The third point must also be on the same side of the mean

--- RUN STEP 30/37
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanStartFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaAboveMeanFlag] = 1
                                                             AND ( LEAD([SpecialCauseTwoThreeSigmaAboveMeanFlag], 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                              AND ( LAG([SpecialCauseAboveMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                               OR (LEAD([SpecialCauseAboveMeanFlag], 2)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1))
                                                             OR    LEAD([SpecialCauseTwoThreeSigmaAboveMeanFlag], 2) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                              AND  LEAD([SpecialCauseAboveMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1)  THEN 1
                                                                                                                                                                                                      ELSE 0 END
      ,[SpecialCauseTwoThreeSigmaBelowMeanStartFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaBelowMeanFlag] = 1
                                                             AND ( LEAD([SpecialCauseTwoThreeSigmaBelowMeanFlag], 1) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                              AND ( LAG([SpecialCauseBelowMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                               OR (LEAD([SpecialCauseBelowMeanFlag], 2)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1))
                                                             OR    LEAD([SpecialCauseTwoThreeSigmaBelowMeanFlag], 2) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1
                                                              AND  LEAD([SpecialCauseBelowMeanFlag], 1)              OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]) = 1)  THEN 1
                                                                                                                                                                                                      ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlag]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaPrep]

-- Add cumulative sum of the above and below mean start-of-two-to-three-sigma flags for non-ghosted points within metric/group/filter/partition combination

--- RUN STEP 31/37
SELECT *
      ,[SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] = SUM([SpecialCauseTwoThreeSigmaAboveMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
      ,[SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount] = SUM([SpecialCauseTwoThreeSigmaBelowMeanStartFlag]) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlagCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlag]

-- Determine each non-ghosted two-to-three sigma point within a group of two or three non-ghosted two-to-three sigma points, on the same side of the mean
-- This is done by comparing the above/below mean start-of-two-to-three sigma flag count with that 3 non-ghosted points prior within metric/group/filter/partition combination, replacing NULL for zero when LAG goes back too far
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] will only be higher if there is at least one point within the last 2 non-ghosted points within metric/group/filter/partition combination that starts a new group
-- The point itself must also be flagged

--- RUN STEP 32/37
SELECT *
      ,[SpecialCauseRuleTwoThreeSigmaAboveMeanFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaAboveMeanFlag] = 1
                                                            AND [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount] > ISNULL(LAG([SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount], 3) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                                      ELSE 0 END
      ,[SpecialCauseRuleTwoThreeSigmaBelowMeanFlag] = CASE WHEN [SpecialCauseTwoThreeSigmaBelowMeanFlag] = 1
                                                            AND [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount] > ISNULL(LAG([SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount], 3) OVER(PARTITION BY [ChartID], [PartitionIDExcludeGhosting] ORDER BY [Reporting_Period]), 0) THEN 1
                                                                                                                                                                                                                                                                      ELSE 0 END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigma]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlagCount]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4i complete, special cause: two-to-three sigma'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4J: SPECIAL CAUSE COMBINED
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step combines the points that have triggered special cause rules
--
--====================================================================================================================================================================================================--

-- Combine special cause rules into improvement/concern/neither values
-- Add conflict flag for updating below
-- Add neither high/low flags

--- RUN STEP 33/37
SELECT *
      ,[SpecialCauseImprovementValue] = CASE WHEN [MetricImprovement] = 'Up'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN [Measure_Value]
                                             WHEN [MetricImprovement] = 'Down'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Measure_Value] END
      ,[SpecialCauseConcernValue]     = CASE WHEN [MetricImprovement] = 'Up'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Measure_Value]
                                             WHEN [MetricImprovement] = 'Down'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN [Measure_Value] END
      ,[SpecialCauseConflictFlag]      = NULL
      ,[SpecialCauseNeitherValue]      = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag] = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN [Measure_Value] END
      ,[SpecialCauseNeitherHighFlag]  = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftAboveMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendIncreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]            = 1) THEN 1
                                                                                                                   ELSE 0 END
      ,[SpecialCauseNeitherLowFlag]   = CASE WHEN [MetricImprovement] = 'Neither'
                                              AND ([SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    = 1
                                                   OR [SpecialCauseRuleShiftBelowMeanFlag]                    = 1
                                                   OR [SpecialCauseRuleTrendDecreasingFlag]                   = 1
                                                   OR [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]            = 1) THEN 1
                                                                                                                   ELSE 0 END
	  ,[Shapes]                      = CASE WHEN ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=1 OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=1) 
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0 
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Outlier'
											WHEN (SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 1 OR SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
											THEN 'Two-thirds'
											WHEN (SpecialCauseRuleShiftAboveMeanFlag = 1 OR SpecialCauseRuleShiftBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Shift'
											WHEN (SpecialCauseRuleTrendIncreasingFlag = 1 OR SpecialCauseRuleTrendDecreasingFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Trend'

											WHEN ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=1 OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=1)
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
												AND (SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 1 OR SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 1)
											THEN 'Outlier & Two-Thirds'
											WHEN ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=1 OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=1)
												AND (SpecialCauseRuleShiftAboveMeanFlag = 1 OR SpecialCauseRuleShiftBelowMeanFlag = 1)
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Outlier & Shift'
											WHEN ([SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=1 OR [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=1)
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND (SpecialCauseRuleTrendIncreasingFlag = 1 OR SpecialCauseRuleTrendIncreasingFlag = 1)
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Outlier & Trend'

											WHEN (SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 1 OR SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND (SpecialCauseRuleShiftAboveMeanFlag = 1 OR SpecialCauseRuleShiftBelowMeanFlag = 1)
												AND SpecialCauseRuleTrendIncreasingFlag = 0 AND SpecialCauseRuleTrendIncreasingFlag = 0
											THEN 'Two-thirds & Shift'
											WHEN (SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 1 OR SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND SpecialCauseRuleShiftAboveMeanFlag = 0 AND SpecialCauseRuleShiftBelowMeanFlag = 0
												AND (SpecialCauseRuleTrendIncreasingFlag = 1 OR SpecialCauseRuleTrendIncreasingFlag = 1)
											THEN 'Two-thirds & Trend'

											WHEN (SpecialCauseRuleShiftAboveMeanFlag = 1 OR SpecialCauseRuleShiftBelowMeanFlag = 1)
												AND [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]=0 AND [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]=0
												AND (SpecialCauseRuleTrendIncreasingFlag = 1 OR SpecialCauseRuleTrendIncreasingFlag = 1)
												AND SpecialCauseRuleTwoThreeSigmaAboveMeanFlag = 0 AND SpecialCauseRuleTwoThreeSigmaBelowMeanFlag = 0
											THEN 'Shift & Trend'

											ELSE 'No Nelson Rule(s)' END 

INTO [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigma]

-- For points that have triggered both an improvement rule and a concern rule, for example an ascending trend below the mean, remove one depending on [MetricConflict] and update conflicting flag:
-- Show only as improvement by removing concern value...
UPDATE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
SET [SpecialCauseConcernValue] = NULL
   ,[SpecialCauseConflictFlag] = 1
WHERE [MetricConflictRule] = 'Improvement'
  AND [SpecialCauseImprovementValue] IS NOT NULL
  AND [SpecialCauseConcernValue]     IS NOT NULL

-- ...or show only as concern by removing improvement value
UPDATE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
SET [SpecialCauseImprovementValue] = NULL
   ,[SpecialCauseConflictFlag]     = 1
WHERE [MetricConflictRule] = 'Concern'
  AND [SpecialCauseImprovementValue] IS NOT NULL
  AND [SpecialCauseConcernValue]     IS NOT NULL

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4j complete, special cause combined'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4K: ICONS
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds the variation and assurance icons for the last non-ghosted point
-- Variation icon is added for the last non-ghosted point if an up/down metric improvement is provided
-- Assurance icon is added for the last non-ghosted point if an up/down metric improvement and target are both provided
--
--====================================================================================================================================================================================================--

-- Add variance and assurance icon flags for XmR charts

--- RUN STEP 34/37
SELECT *
      ,[VariationTrend] = CASE WHEN [MetricImprovement] = 'Up'                                                             THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (High)'
																																	 WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (Low)'
																																	 ELSE 'Common Cause' END
                                                                                       WHEN [MetricImprovement] = 'Down'   THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (Low)'
																																	 WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (High)'
																																	 ELSE 'Common Cause' END
                                                                                       WHEN [MetricImprovement] = 'Neither'THEN CASE WHEN [SpecialCauseNeitherHighFlag] = 1          THEN 'Neither (High)'
                                                                                                                                     WHEN [SpecialCauseNeitherLowFlag]  = 1          THEN 'Neither (Low)'
                                                                                                                                     ELSE 'Common Cause' END END
      ,[VariationIcon] = CASE WHEN [PointExcludeGhostingRankDescending] = 1  THEN CASE WHEN [MetricImprovement] = 'Up'     THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (High)'
																																	 WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (Low)'
																																	 ELSE 'Common Cause' END
                                                                                       WHEN [MetricImprovement] = 'Down'   THEN CASE WHEN [SpecialCauseImprovementValue] IS NOT NULL THEN 'Improvement (Low)'
																																	 WHEN [SpecialCauseConcernValue]     IS NOT NULL THEN 'Concern (High)'
																																	 ELSE 'Common Cause' END
                                                                                       WHEN [MetricImprovement] = 'Neither'THEN CASE WHEN [SpecialCauseNeitherHighFlag] = 1          THEN 'Neither (High)'
                                                                                                                                     WHEN [SpecialCauseNeitherLowFlag]  = 1          THEN 'Neither (Low)'
                                                                                                                                     ELSE 'Common Cause' END END END
      ,[AssuranceIcon] = CASE WHEN [PointExcludeGhostingRankDescending] = 1  THEN CASE WHEN [MetricImprovement] = 'Up'     THEN CASE WHEN [Target] <= [LowerProcessLimit]            THEN 'Pass'
                                                                                                                                     WHEN [Target] >  [LowerProcessLimit]  
																																	  AND [Target] <  [UpperProcessLimit]            THEN 'Hit or Miss'
                                                                                                                                     WHEN [Target] >= [UpperProcessLimit]            THEN 'Fail' END
                                                                                       WHEN [MetricImprovement] = 'Down'   THEN CASE WHEN [Target] >= [UpperProcessLimit]            THEN 'Pass'
                                                                                                                                     WHEN [Target] >  [LowerProcessLimit]                
                                                                                                                                      AND [Target] <  [UpperProcessLimit]            THEN 'Hit or Miss'
                                                                                                                                     WHEN [Target] <= [LowerProcessLimit]            THEN 'Fail' END END END
INTO [MHDInternal].[temp_CDP_SPC_CalculationsIcons]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4k complete, icons'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 4L: ROW COUNT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step adds row counts for use in Steps 5-6
--
--====================================================================================================================================================================================================--

-- Add row counts to enable possible exclusion of metric/group/filter combinations with an insufficient number of points (set in Step 2b)

--- RUN STEP 35/37
SELECT *
      ,[RowCountExcludeGhosting] = SUM(CASE WHEN [GhostFlag] = 1 THEN 0
                                                                 ELSE 1 END) OVER(PARTITION BY [CDP_Measure_ID], [ChartID])
INTO [MHDInternal].[temp_CDP_SPC_CalculationsRowCount]
FROM [MHDInternal].[temp_CDP_SPC_CalculationsIcons]

---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 4l complete, row count'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- STEP 6: OUTPUT
--====================================================================================================================================================================================================--
--
-- Leave this step as it is unless used with the accompanying Power BI template
-- Either store the output in a table (see commented out code below) or turn this SQL query into a stored procedure and skip the warning step above so that only one table is returned
--
-- This step returns the table that is used in the accompanying Power BI template
-- Removing any of these columns may result in the tool not working correctly
-- Additional columns can be added for information purposes
--
--====================================================================================================================================================================================================--

-- Columns removed and reordered
-- SPC features removed from chart for metric/group/filter combinations with an insufficient number of points, depending on setting (set in Step 2b)

--- RUN STEP 36/37
-- MANUALY REMOVE [DASHBOARD_CDP_SPC] becuase DROP TABLE doesnt do the job!
IF OBJECT_ID ('[MHDInternal].[DASHBOARD_CDP_SPC] ') IS NOT NULL
DROP TABLE [MHDInternal].[DASHBOARD_CDP_SPC] 

DECLARE @SettingMinimumPoints INT = 15

SELECT 
       m.[CDP_Measure_ID]
      ,m.[Reporting_Period]
      ,m.[Measure_Value]
	  ,r.Is_Latest
	  ,r.CDP_Measure_Name
      ,r.Org_Type
      ,r.Org_Code
      ,r.Org_Name
      ,r.ICB_Code
      ,r.ICB_Name
      ,r.Region_Code
      ,r.Region_Name
      ,r.Measure_Type
      ,r.Measure_Value_STR
      ,r.Last_Modified
      ,m.[Target]
	  ,m.[Target_STR]
      ,m.[Mean]
      ,[UpperProcessLimit]            = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN m.[UpperProcessLimit]            END
      ,[LowerProcessLimit]            = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN m.[LowerProcessLimit]            END
	  ,[VariationTrend]
      ,[VariationIcon]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [VariationIcon]                END
      ,[AssuranceIcon]                = CASE WHEN [RowCountExcludeGhosting] >= @SettingMinimumPoints THEN [AssuranceIcon]                END
	  ,m.[Shapes]
      ,m.[Annotation]

INTO [MHDInternal].[DASHBOARD_CDP_SPC] 
FROM [MHDInternal].[temp_CDP_SPC_CalculationsRowCount] m

LEFT JOIN [MHDInternal].[temp_CDP_SPC_RawData] r
       ON m.CDP_Measure_ID = r.CDP_Measure_ID
	  AND m.Org_Code = r.Org_Code
	  AND m.Reporting_Period = r.Reporting_Period

ORDER BY [CDP_Measure_ID]
        ,[Reporting_Period]
--drop table [MHDInternal].[DASHBOARD_CDP_SPC_v2]
---- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 6  complete, output'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT
--drop table [MHDInternal].[DASHBOARD_CDP_SPC]

--select *
--into [MHDInternal].[DASHBOARD_CDP_SPC]
--from [MHDInternal].[DASHBOARD_CDP_SPC]
--====================================================================================================================================================================================================--
-- STEP 7: QA Check - Compares latest CDP dates and latest SPC  and whther SPC limits icons have been included
--====================================================================================================================================================================================================--
Select Distinct SPC.CDP_Measure_Name,SPC.CDP_Measure_ID,SPC.Reporting_Interval,SPC.Latest_SPC_Date,
CDP.Reporting_Period 'Latest_CDP_Date',
Case when Latest_SPC_Date=CDP.Reporting_Period Then 'Y' Else 'N' End as Dates_Match,
[SPC].[SPC_Limits Applied],[SPC].[SPC Icons Applied]
from
(select 
CDP_Measure_Name,
CDP_Measure_ID,
Case when CDP_Measure_ID like 'CDP_F%' then 'Quarterly' Else 'Monthly' End Reporting_Interval,
Reporting_Period 'Latest_SPC_Date',
case when Sum(UpperProcessLimit)> 0 then 'Y' else 'N' end 'SPC_Limits Applied',
case when Max(AssuranceIcon) is not null then 'Y' else 'N' end 'SPC Icons Applied'
from  [MHDInternal].[DASHBOARD_CDP_SPC]  
where Measure_Value is not null
and Is_Latest=1
Group by 
CDP_Measure_Name,
CDP_Measure_ID,
Case when CDP_Measure_ID like 'CDP_F%' then 'Quarterly' Else 'Monthly' End,
Reporting_Period
) SPC LEFT JOIN 
(Select CDP_Measure_ID,Reporting_Period From [MHDInternal].[DASHBOARD_CDP] where Is_latest=1) CDP
on SPC.CDP_Measure_ID=CDP.CDP_Measure_ID
--====================================================================================================================================================================================================--
-- STEP 8: CLEAR-UP
--====================================================================================================================================================================================================--
--
-- Leave this step as it is
--
-- This step drops the temporary tables that were used
--
--====================================================================================================================================================================================================--

-- Remove temporary tables

--- RUN STEP 37/37
DROP TABLE [MHDInternal].[temp_CDP_SPC_MetricData]
DROP TABLE [MHDInternal].[temp_CDP_SPC_RawData]
DROP TABLE [MHDInternal].[temp_CDP_SPC_BaselineData]
DROP TABLE [MHDInternal].[temp_CDP_SPC_TargetData]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsPartition]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsBaselineFlag]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsBaseline]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsAllTargets]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSingleTarget]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsMean]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsMovingRange]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeMean]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsMovingRangeProcessLimit]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsProcessLimits]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsBaselineLimits]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseSinglePoint]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShiftPrep]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCausePartitionCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlag]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseStartFlagCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseShift]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPrep]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendPartitionCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlag]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrendStartFlagCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTrend]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaPrep]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlag]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigmaFlagCount]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseTwoThreeSigma]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsSpecialCauseCombined]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsIcons]
DROP TABLE [MHDInternal].[temp_CDP_SPC_CalculationsRowCount]
--DROP TABLE [MHDInternal].[temp_CDP_SPC_Warnings]

-- Print message for end of step
--SET @PrintMessage = CONVERT(VARCHAR(12), GETDATE(), 14) + ': Step 7  complete, clear-up'
--RAISERROR(@PrintMessage, 0, 1) WITH NOWAIT

--====================================================================================================================================================================================================--
-- COLUMN INDEX
--====================================================================================================================================================================================================--
--
-- COLUMN NAME                                                DATA TYPE      RETURNED      CREATION STEP(S)     VALUE
-- [CDP_Measure_ID]                                           Text           6: Output     3a / 3b / 3c / 3d    User-defined (optional for 3c / 3d)
-- [CDP_Measure_Name]                                         Text           6: Output     3a                   User-defined
-- [MetricConflictRule]                                       Text           No            3a                   User-defined or NULL
-- [MetricImprovement]                                        Text           No            3a                   User-defined
-- [LowMeanWarningValue]                                      Number         No            3a                   User-defined or NULL

-- [Reporting_Period]                                         Date           6: Output     3b / 3c              User-defined (or NULL and optional for 3c)
-- [Org_Code]                                                 Text           No            3b / 3c / 3d         User-defined (or NULL and optional for 3c / 3d)
-- [ICB_Code]                                                 Text           No            3b                   User-defined or NULL
-- [Measure_Value]                                            Number         6: Output     3b                   User-defined or NULL
-- [Annotation]                                               Text           6: Output     3b / 4b              User-defined or NULL (optional) turned blank
-- [ChartID]                                                  Text           6: Output     3b                   Concatenation of [CDP_Measure_ID], [GroupHierarchy] and [Org_Code]
-- [GhostValue]                                               Number         6: Output     3b                   Calculated from [GhostFlag] and [Measure_Value]
-- [GhostFlag]                                                Number         No            3b                   User-defined: 1 or 0
-- [RecalculateLimitsFlag]                                    Number         No            3b                   User-defined: 1 or 0

-- [BaselineOrder]                                            Number         No            3c                   User-defined (optional); distinct number; can be added automatically
-- [PointsExcludeGhosting]                                    Number         No            3c                   User-defined or NULL (optional)

-- [EndDate]                                                  Date           No            3d                   User-defined or NULL (optional)
-- [StartDate]                                                Date           No            3d                   User-defined or NULL (optional)
-- [Target]                                                   Number         6: Output     3d                   User-defined (optional)
-- [TargetOrder]                                              Number         No            3d                   User-defined (optional); distinct number; can be added automatically

-- [RowID]                                                    Text           6: Output     4b                   Concatenation of [CDP_Measure_ID], [Org_Code], and ascending order of [Reporting_Period]

-- [PointExcludeGhostingRankAscending]                        Number         No            4b                   ROW_NUMBER; NULL if [GhostFlag] = 1
-- [PointExcludeGhostingRankDescending]                       Number         No            4b                   ROW_NUMBER; NULL if [GhostFlag] = 1
-- [GroupName]                                                Text           6: Output     4b                   Concatenation of [GroupHierarchy], @SettingGroupHierarchyIndentSpaces (2b), and [Org_Code]
-- [PartitionID]                                              Number         No            4b / 4c              Calculated from [RecalculateLimitsFlag]
-- [PartitionIDExcludeGhosting]                               Number         No            4b / 4c              Calculated from [RecalculateLimitsFlag]; NULL if [GhostFlag] = 1

-- [BaselineEndFlag]                                          Number         No            4c                   Calculated from 3c: 1 or 0
-- [BaselineFlag]                                             Number         No            4c                   Calculated from [BaselineEndFlag]: 1 or 0
-- [BaselineEndRank]                                          Number         No            4c                   Calculated from 3c: NULL if [BaselineEndFlag] = 0

-- [TargetRank]                                               Number         No            4d                   Calculated from 3d

-- [PartitionMean]                                            Number         No            4e                   Calculated from [Mean]
-- [PartitionMovingRangeMean]                                 Number         No            4e                   Calculated from [MovingRangeMean]
-- [PartitionMovingRangeMeanForProcessLimits]                 Number         No            4e                   Calculated from [MovingRangeMean]
-- [LowerBaseline]                                            Number         6: Output     4e / 6               Calculated from [LowerProcessLimit]; NULL if [BaselineFlag] = 0 or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerOneSigma]                                            Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerProcessLimit]                                        Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [LowerTwoSigma]                                            Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [Mean]                                                     Number         6: Output     4e                   Calculated from [MeanWithoutOutliers], and [Measure_Value]; NULL if [GhostFlag] = 1
-- [MeanWithoutOutliers]                                      Number         6: Output     4e                   Calculated from [Measure_Value]; NULL if [GhostFlag] = 1
-- [MovingRange]                                              Number         6: Output     4e                   Calculated from [Measure_Value]; NULL if [ChartType] not 'XmR' or [GhostFlag] = 1
-- [MovingRangeHighPointValue]                                Number         6: Output     4e / 6               Calculated from [MovingRangeMean], [MovingRange]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [MovingRangeMean]                                          Number         6: Output     4e                   Calculated from [MovingRangeWithPartition] and [PartitionMovingRangeMean]
-- [MovingRangeMeanForProcessLimits]                          Number         No            4e                   Calculated from [MovingRangeMean], [PartitionMovingRangeMeanForProcessLimits], and [MovingRangeMeanWithoutOutliers]
-- [MovingRangeMeanWithoutOutliers]                           Number         No            4e                   Calculated from [MovingRangeWithPartition]
-- [MovingRangeProcessLimit]                                  Number         6: Output     4e / 6               Calculated from [MovingRangeMean]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [MovingRangeWithPartition]                                 Number         No            4e                   Calculated from [Measure_Value]; ; NULL if [ChartType] not 'XmR' or [GhostFlag] = 1
-- [UpperBaseline]                                            Number         6: Output     4e / 6               Calculated from [UpperProcessLimit]; NULL if [BaselineFlag] = 0 or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperOneSigma]                                            Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperProcessLimit]                                        Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [UpperTwoSigma]                                            Number         6: Output     4e / 6               Calculated from [Mean], and [MovingRangeMeanForProcessLimits]; NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints


-- [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag]    Number         No            4f                   Calculated from [LowerProcessLimit] and [Measure_Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag]    Number         No            4f                   Calculated from [UpperProcessLimit] and [Measure_Value]: 1 or 0; 0 if [GhostFlag] = 1

-- [SpecialCauseAboveMeanFlag]                                Number         No            4g                   Calculated from [Mean] and [Measure_Value]; 0 if [GhostFlag] = 1
-- [SpecialCauseAboveMeanPartitionCount]                      Number         No            4g                   Calculated from [SpecialCauseAboveMeanFlag]
-- [SpecialCauseBelowMeanFlag]                                Number         No            4g                   Calculated from [Mean] and [Measure_Value]; 0 if [GhostFlag] = 1
-- [SpecialCauseBelowMeanPartitionCount]                      Number         No            4g                   Calculated from [SpecialCauseBelowMeanFlag]
-- [SpecialCauseRuleShiftAboveMeanFlag]                       Number         No            4g                   Calculated from [SpecialCauseShiftAboveMeanStartFlagCount] and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseRuleShiftBelowMeanFlag]                       Number         No            4g                   Calculated from [SpecialCauseShiftBelowMeanStartFlagCount] and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseShiftAboveMeanStartFlag]                      Number         No            4g                   Calculated from [SpecialCauseAboveMeanFlag], [SpecialCauseAboveMeanPartitionCount], and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseShiftAboveMeanStartFlagCount]                 Number         No            4g                   Calculated from [SpecialCauseShiftAboveMeanStartFlag]
-- [SpecialCauseShiftBelowMeanStartFlag]                      Number         No            4g                   Calculated from [SpecialCauseBelowMeanFlag], [SpecialCauseBelowMeanPartitionCount], and @SettingSpecialCauseShiftPoints: 1 or 0
-- [SpecialCauseShiftBelowMeanStartFlagCount]                 Number         No            4g                   Calculated from [SpecialCauseShiftBelowMeanStartFlag]

-- [SpecialCauseDecreasingFlag]                               Number         No            4h                   Calculated from [Measure_Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseDecreasingPartitionCount]                     Number         No            4h                   Calculated from [SpecialCauseDecreasingFlag]
-- [SpecialCauseIncreasingFlag]                               Number         No            4h                   Calculated from [Measure_Value]: 1 or 0; 0 if [GhostFlag] = 1
-- [SpecialCauseIncreasingPartitionCount]                     Number         No            4h                   Calculated from [SpecialCauseIncreasingFlag]
-- [SpecialCauseRuleTrendDecreasingFlag]                      Number         No            4h                   Calculated from [SpecialCauseTrendDecreasingStartFlagCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseRuleTrendIncreasingFlag]                      Number         No            4h                   Calculated from [SpecialCauseTrendIncreasingStartFlagCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseTrendDecreasingStartFlag]                     Number         No            4h                   Calculated from [SpecialCauseDecreasingPartitionCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseTrendDecreasingStartFlagCount]                Number         No            4h                   Calculated from [SpecialCauseTrendDecreasingStartFlag] 
-- [SpecialCauseTrendIncreasingStartFlag]                     Number         No            4h                   Calculated from [SpecialCauseIncreasingPartitionCount] and @SettingSpecialCauseTrendPoints: 1 or 0
-- [SpecialCauseTrendIncreasingStartFlagCount]                Number         No            4h                   Calculated from [SpecialCauseTrendIncreasingStartFlag] 

-- [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]               Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaAboveMeanFlag] and [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount]: 1 or 0
-- [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]               Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaBelowMeanFlag] and [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount]: 1 or 0
-- [SpecialCauseTwoThreeSigmaAboveMeanFlag]                   Number         No            4i                   Calculated from [UpperProcessLimit], [UpperTwoSigma] and [Measure_Value]: 1 or 0: 0 if [GhostFlag] = 1
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlag]              Number         No            4i                   Calculated from [SpecialCauseAboveMeanFlag] and [SpecialCauseTwoThreeSigmaAboveMeanFlag]: 1 or 0
-- [SpecialCauseTwoThreeSigmaAboveMeanStartFlagCount]         Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaAboveMeanStartFlag]
-- [SpecialCauseTwoThreeSigmaBelowMeanFlag]                   Number         No            4i                   Calculated from [LowerProcessLimit], [LowerTwoSigma] and [Measure_Value]: 1 or 0: 0 if [GhostFlag] = 1
-- [SpecialCauseTwoThreeSigmaBelowMeanStartFlag]              Number         No            4i                   Calculated from [SpecialCauseBelowMeanFlag] and [SpecialCauseTwoThreeSigmaBelowMeanFlag]: 1 or 0
-- [SpecialCauseTwoThreeSigmaBelowMeanStartFlagCount]         Number         No            4i                   Calculated from [SpecialCauseTwoThreeSigmaBelowMeanStartFlag]

-- [SpecialCauseConcernValue]                                 Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Measure_Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [SpecialCauseImprovementValue]                             Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Measure_Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [SpecialCauseConflictFlag]                                 Number         No            4j                   Calculated from [MetricConflictRule], [SpecialCauseConcernValue], and [SpecialCauseImprovementValue]: 1 or 0
-- [SpecialCauseNeitherHighFlag]                              Number         No            4j                   Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleTrendIncreasingFlag], and [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag]: 1 or 0
-- [SpecialCauseNeitherLowFlag]                               Number         No            4j                   Calculated from [MetricImprovement], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], and [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag]: 1 or 0
-- [SpecialCauseNeitherValue]                                 Number         6: Output     4j / 6               Calculated from [MetricImprovement], [SpecialCauseRuleShiftAboveMeanFlag], [SpecialCauseRuleShiftBelowMeanFlag], [SpecialCauseRuleSinglePointAboveUpperProcessLimitFlag], [SpecialCauseRuleSinglePointBelowLowerProcessLimitFlag], [SpecialCauseRuleTrendDecreasingFlag], [SpecialCauseRuleTrendIncreasingFlag], [SpecialCauseRuleTwoThreeSigmaAboveMeanFlag], [SpecialCauseRuleTwoThreeSigmaBelowMeanFlag], and [Measure_Value]: NULL if [RowCountExcludeGhosting] < @SettingMinimumPoints

-- [AssuranceIcon]                                            Text           6: Output     4k / 6               Calculated from [LowerProcessLimit], [MetricImprovement], [Target] and [UpperProcessLimit]: NULL if [ChartType] not 'XmR' or [MetricImprovement] not 'Down' or 'Up' or [PointExcludeGhostingRankDescending] not 1 or [Target] = NULL or [RowCountExcludeGhosting] < @SettingMinimumPoints
-- [VariationIcon]                                            Text           6: Output     4k / 6               Calculated from [MetricImprovement], [SpecialCauseConcernValue], [SpecialCauseImprovementValue], [SpecialCauseNeitherHighFlag] and [SpecialCauseNeitherLowFlag]; NULL if [MetricImprovement] not 'Up', 'Down', or 'Neither' or [PointExcludeGhostingRankDescending] not 1 or [RowCountExcludeGhosting] < @SettingMinimumPoints

-- [RowCountExcludeGhosting]                                  Number         No            4l                   Calculated from [GhostFlag] 

-- [Detail]                                                   Text           5: Warning    5                    Various
-- [Warning]                                                  Text           5: Warning    5                    Various

--=========================================================================    NOT IN USE    =========================================================================================================
-- [MetricFormat]                                             Text           6: Output     3a                   User-defined
-- [DateFormat]                                               Text           6: Output     3a                   User-defined
-- [VerticalAxisMaxFix]                                       Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMaxFlex]                                      Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMinFix]                                       Number         6: Output     3a                   User-defined or NULL
-- [VerticalAxisMinFlex]                                      Number         6: Output     3a                   User-defined or NULL
-- [ChartType]                                                Text           6: Output     3a                   User-defined
-- [ChartTitle]                                               Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank
-- [VerticalAxisTitle]                                        Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank
-- [HorizontalAxisTitle]                                      Text           6: Output     3a / 4b              User-defined or NULL (optional) turned blank

-- [Filter1]                                                  Text           6: Output     3b / 4b              User-defined or NULL (optional)
-- [Filter2]                                                  Text           6: Output     3b / 4b              User-defined or NULL (optional)

-- [GroupHierarchyOrder]                                      Number         No            4a                   User-defined or NULL (optional)
-- [GroupHierarchy]                                           Number         6: Output     4a                   Calculated from [Org_Code] and [ICB_Code] hierarchy (3b)
-- [GroupLevel]                                               Text           No            4a                   Calculated from [Org_Code] and [ICB_Code] hierarchy (3b)
-- [GroupOrder]                                               Number         6: Output     4a                   ROW_NUMBER from [GroupLevel]

-- [PointRank]                                                Text           6: Output     4b                   ROW_NUMBER if [ChartType] not 'XmR'; calculated from [Reporting_Period] if [ChartType] = 'XmR'

-- [DayDifference]                                            Number         No            4e                   Calculated from [Reporting_Period]; NULL if [ChartType] not 'T'
-- [DayDifferenceTransformed]                                 Number         No            4e                   Calculated from [DayDifference]
-- [DayDifferenceTransformedMean]                             Number         No            4e                   Calculated from [DayDifferenceTransformed]
-- [DayDifferenceTransformedMovingRange]                      Number         No            4e                   Calculated from [DayDifferenceTransformed]; NULL if [GhostFlag] = 1
-- [DayDifferenceTransformedMovingRangeMean]                  Number         No            4e                   Calculated from [DayDifferenceTransformedMovingRange]
-- [PartitionDayDifferenceTransformedMean]                    Number         No            4e                   Calculated from [DayDifferenceTransformedMean]
-- [PartitionDayDifferenceTransformedMovingRangeMean]         Number         No            4e                   Calculated from [DayDifferenceTransformedMovingRangeMean]

-- [IconID]                                                   Text           6: Output     4k                   Concatenation of [CDP_Measure_ID], [GroupHierarchy] and [Org_Code]; NULL if [PointExcludeGhostingRankDescending] not 1

--====================================================================================================================================================================================================--
