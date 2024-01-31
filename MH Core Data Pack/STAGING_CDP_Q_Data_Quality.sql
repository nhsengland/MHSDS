/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD *TEMPLATE*

MEASURE NAME(s): CDP_[INSERT ID]: [insert official Measure_Name]

MEASURE DESCRIPTION(s):
				 CDP_[INSERT ID]: [insert measure description]

BACKGROUND INFO: [Anything important to know, caveats. Such as when historic data gets refreshed]

INPUT:			 [insert input tables] 
				 Delete as required
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Provider_Hierarchies]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_Provider_Successor]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards]

TEMP TABLES:	 SEE DROPPED TABLES AT END OF THE SCRIPT.

OUTPUT:			 [insert output tables]

WRITTEN BY:		 [insert your name and date]

UPDATES:		 KIRSTY WALKER 07/12/2023 Change @RPEnd to remove "WHERE Der_CurrentSubmissionWindow = 'Performance'" FOR DEC-23 CHANGE TO SINGLE SUBMISSION WINDOW 
								          (THERE USE TO BE A PROVISIONAL DATA WINDOW BUT NOW WE JUST PULL OUT MAX REPORTING_PERIOD)

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Outline timeframe 

DECLARE @RPEnd as DATE
DECLARE @RPStart as DATE

SET @RPStart = '2019-04-01'

SET @RPEnd =  (SELECT MAX([ReportingPeriodEndDate]) FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table])

PRINT @RPStart
PRINT @RPEnd

-- Delete any rows which already exist in output table for this time period
DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality]
WHERE [Reporting_Period] BETWEEN @RPStart AND @RPEnd

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR, DENOMINATOR AND PERCENTAGE TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Pull provider level data
-- DQ consistency

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q01' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Consistency' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Numerator' AS Measure_Type,
		CAST([MeasureValue] AS FLOAT) AS Measure_Value

		INTO NHSE_Sandbox_Policy.temp.TEMP_CDP_Q_Data_Quality_NEW_Prov

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'Submission status - major charts'	
AND [Breakdown] = 'Submission consistency'	
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'Provider'

UNION

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q01' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Consistency' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Denominator' AS Measure_Type,
		CAST([TargetValue] AS FLOAT)  AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'Submission status - major charts'	
AND [Breakdown] = 'Submission consistency'	
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'Provider'

UNION

-- DQ Coverage

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q02' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Coverage' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Numerator' AS Measure_Type,
		CAST(MeasureValue AS FLOAT)  AS Measure_Value

FROM	
[NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]
	
WHERE 	
Dashboard = 'Submission status - time series'
AND ([Breakdown category] IN ('Performance', 'Non-Submitter'))
AND [Region code] <> 'Wales'	
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Der_OrgSubmissionStatus <> 'No longer in scope'
AND Org_Type = 'Provider'

UNION

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q02' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Coverage' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Denominator' AS Measure_Type,
		CAST(DenominatorValue AS FLOAT)  AS Measure_Value

FROM	
[NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]
	
WHERE 	
Dashboard = 'Submission status - time series'
AND ([Breakdown category] IN ('Performance', 'Non-Submitter'))
AND [Region code] <> 'Wales'	
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Der_OrgSubmissionStatus <> 'No longer in scope'
AND Org_Type = 'Provider'

UNION

-- DQ Outcomes

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q03' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Outcomes' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Numerator' AS Measure_Type,
		SUM(CAST(MeasureValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'Outcomes CQUIN'
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'Provider'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [Provider code],
	   [Provider name],
	   [STP code],
	   [STP name],
	   [Region code],
	   [Region name]

UNION

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q03' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Outcomes' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Denominator' AS Measure_Type,
		SUM(CAST(DenominatorValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'Outcomes CQUIN'
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'Provider'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [Provider code],
	   [Provider name],
	   [STP code],
	   [STP name],
	   [Region code],
	   [Region name]

UNION 

-- SNOMED CT

SELECT 	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q04' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality SNoMED CT' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Numerator' AS Measure_Type,
		SUM(CAST(MeasureValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
	[Region code] <> 'Wales'	
	AND Dashboard =  'SNoMED CT'		
	AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
	AND Org_Type = 'Provider'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [Provider code],
	   [Provider name],
	   [STP code],
	   [STP name],
	   [Region code],
	   [Region name]

	UNION

SELECT 	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q04' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality SNoMED CT' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Denominator' AS Measure_Type,
		SUM(CAST(DenominatorValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
	[Region code] <> 'Wales'	
	AND Dashboard =  'SNoMED CT'		
	AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
	AND Org_Type = 'Provider'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [Provider code],
	   [Provider name],
	   [STP code],
	   [STP name],
	   [Region code],
	   [Region name] 

	UNION

SELECT

	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q05' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality DQMI' AS 'CDP_Measure_Name',
	   'Provider' AS Org_Type,
	   [Provider code] AS Org_Code,
	   [Provider name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Score' AS Measure_Type,
		CAST(MeasureValue AS FLOAT)/100 AS Measure_Value

FROM[NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'DQMI'	
AND [Breakdown] = 'Data set score'		
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'Provider'

-- Aggregate to ICB, Region and England (DQMI is an average) for metrics which map from provider tp ICB 1:1 (Coverage, Consistency & DQMI)

-- ICB
SELECT  [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   'ICB' AS [Org_Type],
	   [ICB_Code] AS [Org_Code],
	   [ICB_Name] AS [Org_Name],
	   [ICB_Code],
	   [ICB_Name],
	   r.[Region_Code],
	   r.[Region_Name],
	   [Measure_Type],
	   SUM(Measure_Value) AS [Measure_Value]

	  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Agg]

	   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Prov]

	   LEFT JOIN (SELECT DISTINCT STP_Code, Region_Code, Region_Name 
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) r 
					    ON [ICB_Code] = r.STP_Code -- NEED TO USE LOOK UP HERE AS IN MPL THERE ARE SOMETIMES MULTILE REGIONS FOR A SINGLE ICB

	   WHERE CDP_Measure_ID NOT IN ('CDP_Q05','CDP_Q04','CDP_Q03')
	   AND Org_Type = 'Provider'

	   GROUP BY 
	   [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   [ICB_Code],
	   [ICB_Name],
	   r.[Region_Code],
	   r.[Region_Name],
	   [Measure_Type]

	   UNION

	 SELECT  [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   'ICB' AS [Org_Type],
	   [ICB_Code] AS [Org_Code],
	   [ICB_Name] AS [Org_Name],
	   [ICB_Code],
	   [ICB_Name],
	   r.[Region_Code],
	   r.[Region_Name],
	   [Measure_Type],
	   AVG(CAST(Measure_Value AS FLOAT)) AS [Measure_Value]

	   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Prov]

	   	   LEFT JOIN (SELECT DISTINCT STP_Code, Region_Code, Region_Name 
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) r 
					    ON [ICB_Code] = r.STP_Code -- NEED TO USE LOOK UP HERE AS IN MPL THERE ARE SOMETIMES MULTILE REGIONS FOR A SINGLE ICB

	   WHERE CDP_Measure_ID = 'CDP_Q05'
	   AND Org_Type = 'Provider'

	   GROUP BY 
	   [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   [ICB_Code],
	   [ICB_Name],
	   r.[Region_Code],
	   r.[Region_Name],
	   [Measure_Type]

	UNION

	-- Region
SELECT  [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   'Region' AS [Org_Type],
	   [Region_Code] AS [Org_Code],
	   [Region_Name] AS [Org_Name],
	   'NA' AS [ICB_Code],
	   'NA' AS [ICB_Name],
	   [Region_Code],
	   [Region_Name],
	   [Measure_Type],
	   SUM(Measure_Value) AS [Measure_Value]

	   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Prov]

	   WHERE CDP_Measure_ID NOT IN ('CDP_Q05','CDP_Q04','CDP_Q03')
	   AND Org_Type = 'Provider'

	   GROUP BY 
	   [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   [Region_Code],
	   [Region_Name],
	   [Measure_Type]

	   UNION

	 SELECT  [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   'Region' AS [Org_Type],
	   [Region_Code] AS [Org_Code],
	   [Region_Name] AS [Org_Name],
	   'NA' AS [ICB_Code],
	   'NA' AS [ICB_Name],
	   [Region_Code],
	   [Region_Name],
	   [Measure_Type],
	   AVG(CAST(Measure_Value AS FLOAT)) AS [Measure_Value]

	   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Prov]

	   WHERE CDP_Measure_ID = 'CDP_Q05'
	   AND Org_Type = 'Provider'

	   GROUP BY 
	   [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   [Region_Code],
	   [Region_Name],
	   [Measure_Type]

	   UNION

	-- England
SELECT  [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   'England' AS [Org_Type],
	   'ENG' AS [Org_Code],
	   'England' AS [Org_Name],
	   'NA' AS [ICB_Code],
	   'NA' AS [ICB_Name],
	   'NA' AS [Region_Code],
	   'NA' AS [Region_Name],
	   [Measure_Type],
	   SUM(Measure_Value) AS [Measure_Value]

	   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Prov]

	   WHERE CDP_Measure_ID NOT IN ('CDP_Q05') -- ONLY EXCLUDE DQMI HERE - ALL OTHER METRICS CAN BE AGGREGATED TO ENG 
	   AND Org_Type = 'Provider'

	   GROUP BY 
	   [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   [Measure_Type]

	   UNION

	 SELECT  [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   'England' AS [Org_Type],
	   'ENG' AS [Org_Code],
	   'England' AS [Org_Name],
	   'NA' AS [ICB_Code],
	   'NA' AS [ICB_Name],
	   'NA' AS [Region_Code],
	   'NA' AS [Region_Name],
	   [Measure_Type],
	   AVG(CAST(Measure_Value AS FLOAT)) AS [Measure_Value]

	   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Prov]

	   WHERE CDP_Measure_ID = 'CDP_Q05'
	   AND Org_Type = 'Provider'

	   GROUP BY 
	   [Reporting_Period],
	   [CDP_Measure_ID],
	   [CDP_Measure_Name],
	   [Measure_Type]

-- Pull and aggregate data for ICB & Region

--ICB

-- Snomed

SELECT 	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q04' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality SNoMED CT' AS 'CDP_Measure_Name',
	   'ICB' AS Org_Type,
	   [STP code] AS Org_Code,
	   [STP name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Numerator' AS Measure_Type,
		SUM(CAST(MeasureValue AS FLOAT) ) AS Measure_Value

		INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_GPPostcodeAgg]

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
	[Region code] <> 'Wales'	
	AND Dashboard =  'SNoMED CT'		
	AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
	AND Org_Type = 'ICB'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [STP code],
	   [STP name],
	   [Region code],
	   [Region name]

	UNION

SELECT 	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q04' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality SNoMED CT' AS 'CDP_Measure_Name',
	   'ICB' AS Org_Type,
	   [STP code] AS Org_Code,
	   [STP name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Denominator' AS Measure_Type,
		SUM(CAST(DenominatorValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
	[Region code] <> 'Wales'	
	AND Dashboard =  'SNoMED CT'		
	AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
	AND Org_Type = 'ICB'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [STP code],
	   [STP name],
	   [Region code],
	   [Region name] 

UNION

-- DQ Outcomes

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q03' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Outcomes' AS 'CDP_Measure_Name',
	   'ICB' AS Org_Type,
	   [STP code] AS Org_Code,
	   [STP name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Numerator' AS Measure_Type,
		SUM(CAST(MeasureValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'Outcomes CQUIN'
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'ICB'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [STP code],
	   [STP name],
	   [Region code],
	   [Region name]

UNION

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q03' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Outcomes' AS 'CDP_Measure_Name',
	   'ICB' AS Org_Type,
	   [STP code] AS Org_Code,
	   [STP name] AS Org_Name,
	   [STP code] AS ICB_Code,
	   [STP name] AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Denominator' AS Measure_Type,
		SUM(CAST(DenominatorValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'Outcomes CQUIN'
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'ICB'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [STP code],
	   [STP name],
	   [Region code],
	   [Region name]

UNION

--Region

-- Snomed

SELECT 	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q04' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality SNoMED CT' AS 'CDP_Measure_Name',
	   'Region' AS Org_Type,
	   [Region code] AS Org_Code,
	   [Region name] AS Org_Name,
	   'NA' AS ICB_Code,
	   'NA' AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Numerator' AS Measure_Type,
		SUM(CAST(MeasureValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
	[Region code] <> 'Wales'	
	AND Dashboard =  'SNoMED CT'		
	AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
	AND Org_Type = 'ICB'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [Region code],
	   [Region name]

	UNION

SELECT 	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q04' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality SNoMED CT' AS 'CDP_Measure_Name',
	   'Region' AS Org_Type,
	   [Region code] AS Org_Code,
	   [Region name] AS Org_Name,
	   'NA' AS ICB_Code,
	   'NA' AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Denominator' AS Measure_Type,
		SUM(CAST(DenominatorValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
	[Region code] <> 'Wales'	
	AND Dashboard =  'SNoMED CT'		
	AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
	AND Org_Type = 'ICB'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [Region code],
	   [Region name] 

UNION

-- DQ Outcomes

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q03' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Outcomes' AS 'CDP_Measure_Name',
	   'Region' AS Org_Type,
	   [Region code] AS Org_Code,
	   [Region name] AS Org_Name,
	   'NA' AS ICB_Code,
	   'NA' AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Numerator' AS Measure_Type,
		SUM(CAST(MeasureValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'Outcomes CQUIN'
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'ICB'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [Region code],
	   [Region name]

UNION

SELECT	
	   CAST([ReportingPeriodEndDate] AS DATE) AS 'Reporting_Period',
	   'CDP_Q03' AS 'CDP_Measure_ID',
	   'MHSDS - Data Quality Outcomes' AS 'CDP_Measure_Name',
	   'Region' AS Org_Type,
	   [Region code] AS Org_Code,
	   [Region name] AS Org_Name,
	   'NA' AS ICB_Code,
	   'NA' AS ICB_Name,
	   [Region code] AS Region_Code,
	   [Region name] AS Region_Name,
	   'Denominator' AS Measure_Type,
		SUM(CAST(DenominatorValue AS FLOAT) ) AS Measure_Value

FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

WHERE	
[Region code] <> 'Wales'	
AND Dashboard = 'Outcomes CQUIN'
AND [ReportingPeriodEndDate] BETWEEN @RPStart AND @RPEnd
AND Org_Type = 'ICB'

GROUP BY CAST([ReportingPeriodEndDate] AS DATE),
	   [Region code],
	   [Region name]


-- Collate Provider and Aggregate data

	   SELECT * 

	   INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master]
	   
	   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Prov]

	   UNION 

	   SELECT * FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Agg]

	   UNION

	   SELECT * FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_GPPostcodeAgg]
	   

-- Calculate any percentages needed in the data
--Example script for this

SELECT 
	   a.Reporting_Period,
	   a.CDP_Measure_ID,
	   a.CDP_Measure_Name,
	   a.Org_Type,
	   a.Org_Code,
	   a.Org_Name,
	   a.ICB_Code,
	   a.ICB_Name,
	   a.Region_Code,
	   a.Region_Name,
	   'Percentage' AS Measure_Type,
	   ((CASE WHEN a.CDP_Measure_ID NOT IN('CDP_Q01','CDP_Q02') AND a.Measure_Value < 5 THEN NULL 
			 ELSE CAST(a.Measure_Value as FLOAT) 
			 END) 
		/
	   (CASE WHEN b.CDP_Measure_ID NOT IN('CDP_Q01','CDP_Q02') AND b.Measure_Value < 5 THEN NULL 
			 ELSE NULLIF(CAST(b.Measure_Value as FLOAT),0)
			 END) 
	    )  as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_Percentages]
  FROM (SELECT * 
		  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master]
		 WHERE Measure_Type = 'Numerator') a
INNER JOIN 
	   (SELECT * 
	      FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master]
		 WHERE Measure_Type = 'Denominator') b  
		    ON a.Reporting_Period = b.Reporting_Period 
		   AND a.Org_Code = b.Org_Code 
		   AND a.CDP_Measure_ID = b.CDP_Measure_ID
		   AND a.Org_Type = b.Org_Type

-- Collate Percentage calcs with rest of data
SELECT * 

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_All]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_Percentages]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: QA - REMOVE UNSUPPORTED ORGS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_All]
 WHERE Region_Code LIKE 'REG%' 
	OR Org_Code IS NULL 
	OR (Org_Type = 'SubICB' 
   AND Org_Code NOT IN (SELECT DISTINCT Organisation_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP' AND Effective_To IS NULL))
    OR (Org_Type = 'ICB' AND Org_Code NOT IN (SELECT DISTINCT STP_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP' AND Effective_To IS NULL)) 
	OR (Org_Type = 'Region' AND Org_Code NOT IN (SELECT DISTINCT Region_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP' AND Effective_To IS NULL))

  /*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 3: ADD IN MISSING SubICBs & ICBs
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get list of SubICBs and ICBs
SELECT DISTINCT 
	   'SubICB' as Org_Type,
	   Organisation_Code as Org_Code,
	   Organisation_Name as Org_Name,
	   STP_Code as ICB_Code,
	   STP_Name as ICB_Name,
	   Region_Code,
	   Region_Name

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Org_List]
  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] 
 WHERE Effective_To IS NULL 
   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'

UNION

SELECT DISTINCT 
	   'ICB' as Org_Type,
	   STP_Code as Org_Code,
	   STP_Name as Org_Name,
	   STP_Code as ICB_Code,
	   STP_Name as ICB_Name,
	   Region_Code,
	   Region_Name

  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
 WHERE Effective_To IS NULL 
   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'

-- Get list of all orgs and indicator combinations
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Org_List_Dates]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Org_List]
CROSS JOIN (SELECT DISTINCT 
				   Reporting_Period, 
				   CDP_Measure_ID,
				   CDP_Measure_Name,
				   Measure_Type 
			  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_All])_

-- Find list of only missing rows
SELECT 
	   d.Reporting_Period,
	   d.CDP_Measure_ID,
	   d.CDP_Measure_Name,
	   d.Org_Type,
	   d.Org_Code,
	   d.Org_Name,
	   d.ICB_Code,
	   d.ICB_Name,
	   d.Region_Code,
	   d.Region_Name,
	   d.Measure_Type,
	   CAST(NULL as float) as Measure_Value

 INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_Missing_Orgs]

 FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Org_List_Dates] d

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_All] e 
   ON d.Reporting_Period = e.Reporting_Period
  AND d.CDP_Measure_ID = e.CDP_Measure_ID  
  AND d.Org_Type = e.Org_Type
  AND d.Org_Code = e.Org_Code 
  AND d.Measure_Type = e.Measure_Type 
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_All]
SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_Missing_Orgs]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT DISTINCT
	   f.Reporting_Period,
	   f.CDP_Measure_ID,
	   f.CDP_Measure_Name,
	   f.Org_Type,
	   f.Org_Code,
	   f.Org_Name,
	   f.ICB_Code,
	   f.ICB_Name,
	   f.Region_Code,
	   f.Region_Name,
	   f.Measure_Type,
	   CASE WHEN f.Measure_Type IN('Score') 
			THEN CAST(ROUND(Measure_Value,3) as FLOAT) -- DQMI ROUND TO 1dp
			WHEN f.Measure_Type IN('Percentage') AND f.Org_Type = 'England' 
			THEN CAST(ROUND(Measure_Value,3) as FLOAT) -- If rate and eng round to 1dp
		    WHEN f.Measure_Type IN('Percentage') AND f.Org_Type <> 'England' 
			THEN CAST(ROUND(Measure_Value,2) as FLOAT) -- If rate and not Eng then round to 0dp
			WHEN f.CDP_Measure_ID NOT IN('CDP_Q01','CDP_Q02') AND Measure_Value < 5 
			THEN NULL -- supressed values shown as NULL
			WHEN f.CDP_Measure_ID IN('CDP_Q01','CDP_Q02') 
			THEN Measure_Value
			WHEN f.Org_Type = 'England' 
			THEN Measure_Value -- Counts for Eng no rounding
			ELSE CAST(ROUND(Measure_Value/5.0,0)*5 as FLOAT) 
	   END as Measure_Value,
	   s.[Standard],
	   l.[LTP_Trajectory_Rounded] AS [LTP_Trajectory],
	   CASE WHEN f.Measure_Type NOT IN ('Rate','Percentage','Numerator','Denominator') 
			THEN ROUND(CAST(Measure_Value as FLOAT)/NULLIF(CAST(l.LTP_Trajectory as FLOAT),0),2) 
			ELSE NULL 
	   END as LTP_Trajectory_Percentage_Achieved,
	   p.[Plan_Rounded] AS [Plan],
	   CASE WHEN f.Measure_Type NOT IN ('Rate','Percentage','Numerator','Denominator') 
			THEN ROUND(CAST(Measure_Value as FLOAT)/NULLIF(CAST(p.[Plan] as FLOAT),0),2) 
			ELSE NULL 
	   END as Plan_Percentage_Achieved,
	   s.Standard_STR,
	   l.LTP_Trajectory_STR,
	   p.Plan_STR

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_RND]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_All] f

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories] l 
    ON f.Reporting_Period = l.Reporting_Period 
   AND f.Org_Code = l.Org_Code 
   AND f.CDP_Measure_ID = l.CDP_Measure_ID
   AND f.Measure_Type = l.Measure_Type

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] p 
    ON f.Reporting_Period = p.Reporting_Period 
   AND f.Org_Code = p.Org_Code 
   AND f.CDP_Measure_ID = p.CDP_Measure_ID 
   AND f.Measure_Type = p.Measure_Type

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards] s 
    ON f.Reporting_Period = s.Reporting_Period 
   AND f.CDP_Measure_ID = s.CDP_Measure_ID 
   AND f.Measure_Type = s.Measure_Type

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 6: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Set Is_Latest in current table as 0
UPDATE [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality]
   SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) as Reporting_Period, CDP_Measure_ID
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_Is_Latest] 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_RND]
  GROUP BY CDP_Measure_ID


INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality]
SELECT
	   f.Reporting_Period,
	   CASE WHEN i.Reporting_Period IS NOT NULL 
			THEN 1 
			ELSE 0 
	   END as Is_Latest,
	   f.CDP_Measure_ID,
	   f.CDP_Measure_Name,
	   f.Org_Type,
	   f.Org_Code,
	   f.Org_Name,
	   f.ICB_Code,
	   f.ICB_Name,
	   f.Region_Code,
	   f.Region_Name,
	   f.Measure_Type,
	   f.Measure_Value,
	   [Standard],
	   LTP_Trajectory,
	   LTP_Trajectory_Percentage_Achieved,
	   [Plan],
	   Plan_Percentage_Achieved,
	   CASE WHEN e.[Org_Code] IS NOT NULL THEN '-' -- If this row was added in as a missing org then show '-'
			WHEN f.[Measure_Value] IS NULL THEN '*' 
			WHEN f.Measure_Type IN('Percentage','Score') THEN FORMAT(f.Measure_Value,'P1')
			ELSE FORMAT(f.[Measure_Value],N'N0') 
	   END AS [Measure_Value_STR],
	   Standard_STR,
	   LTP_Trajectory_STR,
	   CAST(LTP_Trajectory_Percentage_Achieved*100 as varchar)+'%' as LTP_Trajectory_Percentage_Achieved_STR,
	   Plan_STR,
	   CAST(Plan_Percentage_Achieved*100 as varchar)+'%' as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified

   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_RND] f

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_Is_Latest]  i ON f.Reporting_Period = i.Reporting_Period AND f.CDP_Measure_ID = i.CDP_Measure_ID

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_Missing_Orgs] e 
  ON  f.Reporting_Period = e.Reporting_Period
 AND f.CDP_Measure_ID = e.CDP_Measure_ID 
 AND f.Org_Type = e.Org_Type
 AND f.Org_Code = e.Org_Code
 AND f.Measure_Type = e.Measure_Type

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 7: QA CHECKS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Check for duplicate rows, this should return a blank table if none
SELECT DISTINCT 
	   a.Reporting_Period,
	   a.CDP_Measure_ID,
	   a.CDP_Measure_Name,
	   a.Measure_Type,
	   a.Org_Type,
	   a.Org_Code
  FROM
	   (SELECT 
			   Reporting_Period,
			   CDP_Measure_ID,
			   CDP_Measure_Name,
			   Measure_Type,
			   Org_Type,
			   Org_Code,
			   count(1) cnt
		 FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality]
         GROUP BY 
		 Reporting_Period,
		 CDP_Measure_ID,
		 CDP_Measure_Name,
		 Measure_Type,
		 Org_Type,
		 Org_Code
         HAVING count(1) > 1) a

-- Check for differences between new month and previous month data (nb this will look high for the YTD measures when April data comes in)
-- The parameters may need to change 

-- COULD CHECK THAT PERCENTAGES AT PROV LEVEL FOR COVERAGE ARE 0 OR 100 AND NUM = 0/1 AND DEN = 1. THEN DO NORMAL CHECKS AT ICB, REG, ENG LEVEL?
-- SAME KIND OF THING FOR CONSISTENCY -- CAN ONLY CHANGE BY A MAX OF 0.2 BETWEEN MONTHS SO COULD CHECK THAT TOO? THEN AGAIN SAME CHECKS AT ICB,REG, ENG LEVEL
-- CHECK SOME OF THE 0 dqmi SCORES TO MAKE SURE THIS IS CORRECT?
-- SNOMED AND OUTCOMES CAN MONITOR LIKE USUAL?


SELECT Latest_Reporting_Period, 
	   Previous_Reporting_Period, 
	   CDP_Measure_ID, 
	   CDP_Measure_Name, 
	   Measure_Type,
	   Org_Type,
	   Org_Code, 
	   Org_Name, 
	   Previous_Measure_Value_STR,
	   Latest_Measure_Value_STR,
	 --  Numerical_Change,
	 CASE WHEN Previous_Measure_Value_STR <> '-' AND Previous_Measure_Value_STR <> '*' AND (Latest_Measure_Value_STR = '-' OR Latest_Measure_Value_STR IS NULL) THEN '2 Data Missing - Latest'
	 WHEN Latest_Measure_Value_STR <> '-' AND Latest_Measure_Value_STR <> '*' AND (Previous_Measure_Value_STR = '-' OR Previous_Measure_Value_STR IS NULL) THEN '7 Data Missing - Previous'
		WHEN Previous_Measure_Value_STR = '*' AND Latest_Measure_Value_STR = '*' THEN '9 Supression - Both'
		WHEN Previous_Measure_Value_STR = '-' AND Latest_Measure_Value_STR = '-' THEN '8 Data Missing - Both'
		WHEN ((Measure_Type NOT IN ('Percentage','Rate') AND (Latest_Measure_Value < 100 OR Previous_Measure_Value < 100)) OR Previous_Measure_Value_STR = '*' OR Latest_Measure_Value_STR = '*')
		AND (Percentage_Change >= 0.5 OR Percentage_Change IS NULL) THEN '4 High Variation - Volatile Numbers'
		WHEN Percentage_Change >= 0.5 THEN '1 High Variation'
		WHEN Percentage_Change <= 0.1 THEN '5 Low Variation'
		WHEN ((Measure_Type NOT IN ('Percentage','Rate') AND (Latest_Measure_Value < 100 OR Previous_Measure_Value < 100)) OR Previous_Measure_Value_STR = '*' OR Latest_Measure_Value_STR = '*')
		AND (Percentage_Change < 0.5 OR Percentage_Change IS NULL) THEN '6 Moderate Variation - Volatile Numbers'
		WHEN Percentage_Change < 0.5 THEN '3 Moderate Variation'
		ELSE NULL END AS 'QA_Flag',
	   FORMAT(Percentage_Change,'P1') AS Precentage_Change


	   FROM (
SELECT 
	   latest.Reporting_Period AS Latest_Reporting_Period, 
	   previous.Reporting_Period AS Previous_Reporting_Period, 
	   latest.CDP_Measure_ID, 
	   latest.CDP_Measure_Name, 
	   latest.Measure_Type,
	   latest.Org_Type,
	   latest.Org_Code, 
	   latest.Org_Name, 
	   latest.Measure_Value as Latest_Measure_Value,
	   previous.Measure_Value as Previous_Measure_Value, 
	   ABS(latest.Measure_Value - previous.Measure_Value) as Numerical_Change,
	   previous.Measure_Value_STR AS Previous_Measure_Value_STR,
	   latest.Measure_Value_STR AS Latest_Measure_Value_STR,
	   CASE WHEN latest.Measure_Type = 'Percentage' 
			THEN ROUND(ABS(latest.Measure_Value - previous.Measure_Value),3)
			WHEN latest.Measure_Type <> 'Percentage' AND ABS(latest.Measure_Value - previous.Measure_Value) = 0 THEN 0
			ELSE -- percentage point change if comparing percentages
			ROUND(NULLIF(ABS(latest.Measure_Value - previous.Measure_Value),0)/NULLIF(latest.Measure_Value,0),1)
	   END as Percentage_Change

  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality] latest

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality] previous
	  ON latest.CDP_Measure_ID = previous.CDP_Measure_ID 
		  AND CASE WHEN meta.Update_Frequency = 'Monthly' THEN EOMONTH(DATEADD(mm, -1, latest.Reporting_Period ))
		  WHEN meta.Update_Frequency = 'Quarterly' THEN EOMONTH(DATEADD(mm, -3, latest.Reporting_Period )) 
		  WHEN meta.Update_Frequency = 'Annually' THEN EOMONTH(DATEADD(mm, -12, latest.Reporting_Period )) 
		  END = previous.Reporting_Period
		  AND latest.Measure_Type = previous.Measure_Type
		  AND latest.Org_Code = previous.Org_Code 
		  AND latest.Org_Type = previous.Org_Type

WHERE latest.Is_Latest = 1 )_

ORDER BY QA_Flag, CDP_Measure_Name, Org_Name, Org_Type, Percentage_Change DESC

--check table has updated okay
SELECT MAX(Reporting_Period)
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality]
  WHERE Measure_Value IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 8: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Prov]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Agg]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_GPPostcodeAgg]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_Percentages]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_All]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Org_List_Dates]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Org_List]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_Missing_Orgs]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_RND]
  DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Q_Data_Quality_NEW_Master_Is_Latest] 


 
 select * from [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality] where measure_type = 'denominator'