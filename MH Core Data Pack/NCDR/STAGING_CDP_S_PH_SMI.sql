/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD *TEMPLATE*

MEASURE NAME: CDP_S01 - SMI PH Activity

BACKGROUND INFO: 

INPUT: 
			[NHSE_UKHF].[Physical_Health_Checks_Severe_Mental_Illness].[vw_Data1] 
			[NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] 
			[NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
			NHSE_Sandbox_Policy.dbo.REFERENCE_CDP_Boundary_Population_Changes
			[NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories] l 
			[NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] p 
			[NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards]


OUTPUT: NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI

WRITTEN BY: Jade Sykes

UPDATES: 

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Outline timeframe 

DECLARE @RPEnd as DATE
DECLARE @RPStart as DATE

SET @RPEnd = (SELECT MAX(Effective_Snapshot_Date) FROM [NHSE_UKHF].[Physical_Health_Checks_Severe_Mental_Illness].[vw_Data1])
SET @RPStart = @RPEnd

PRINT @RPStart
PRINT @RPEnd

-- Delete any rows which already exist in output table for this time period
DELETE FROM NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI
WHERE [Reporting_Period] BETWEEN @RPStart AND @RPEnd

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR, DENOMINATOR AND PERCENTAGE TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SubICB

SELECT 
       b.Effective_Snapshot_Date as [Reporting_Period],
	   'CDP_S01' AS [CDP_Measure_ID],
	   'SMI PH Activity' AS [CDP_Measure_Name],
	   'SubICB' AS [Org_Type]
	   ,CASE WHEN cc.New_Code IS NULL THEN b.Commissioner_Code ELSE cc.New_Code COLLATE database_default END AS Org_Code
	   ,[Organisation_Name] AS [Org_Name]
	   ,STP_Code AS ICB_Code
	   ,STP_Name AS ICB_Name
	   ,Region_Code AS Region_Code
	   ,Region_Name AS Region_Name
	   ,'Count' AS [Measure_Type]
	   ,SUM([Answer]) AS [Measure_Value]
	   --CASE WHEN (SUM(CASE WHEN Question = 'SMIRegister' THEN [Value] END))=0 then null else SUM(CASE WHEN Question = 'All6PHC' THEN [Value] END)END AS [Measure_Value]

INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Raw

FROM [NHSE_UKHF].[Physical_Health_Checks_Severe_Mental_Illness].[vw_Data1] b

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]  cc ON b.Commissioner_Code = cc.Org_Code COLLATE SQL_Latin1_General_CP1_CI_AS

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON CASE WHEN cc.New_Code IS NULL THEN Commissioner_Code ELSE New_Code COLLATE SQL_Latin1_General_CP1_CI_AS END = ch.[Organisation_Code] 

WHERE Question = 'All6PHC' AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd

GROUP BY b.Effective_Snapshot_Date, CASE WHEN cc.New_Code IS NULL THEN b.Commissioner_Code ELSE cc.New_Code COLLATE database_default END, [Organisation_Name],STP_Code ,STP_Name ,Region_Code, Region_Name 

UNION

--Region

SELECT 
       b.Effective_Snapshot_Date as [Reporting_Period],
	   'CDP_S01' AS [CDP_Measure_ID],
	   'SMI PH Activity' AS [CDP_Measure_Name],
	   'Region' AS [Org_Type]
	   ,Region_Code AS Org_Code
	   ,Region_Name AS [Org_Name]
	   ,'NA' AS ICB_Code
	   ,'NA' AS ICB_Name
	   ,Region_Code AS Region_Code
	   ,Region_Name AS Region_Name
	   ,'Count' AS [Measure_Type]
	   ,SUM([Answer]) AS [Measure_Value]
	   --CASE WHEN (SUM(CASE WHEN Question = 'SMIRegister' THEN [Value] END))=0 then null else SUM(CASE WHEN Question = 'All6PHC' THEN [Value] END)END AS [Measure_Value]

FROM [NHSE_UKHF].[Physical_Health_Checks_Severe_Mental_Illness].[vw_Data1] b

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]  cc ON b.Commissioner_Code = cc.Org_Code COLLATE SQL_Latin1_General_CP1_CI_AS

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON CASE WHEN cc.New_Code IS NULL THEN Commissioner_Code ELSE New_Code COLLATE SQL_Latin1_General_CP1_CI_AS END = ch.[Organisation_Code] 

WHERE Question = 'All6PHC' AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd

GROUP BY b.Effective_Snapshot_Date, Region_Code, Region_Name

UNION

-- ICB

SELECT 
       b.Effective_Snapshot_Date as [Reporting_Period],
	   'CDP_S01' AS [CDP_Measure_ID],
	   'SMI PH Activity' AS [CDP_Measure_Name],
	   'ICB' AS [Org_Type]
	   ,STP_Code AS Org_Code
	   ,STP_Name AS [Org_Name]
	   ,STP_Code AS ICB_Code
	   ,STP_Name AS ICB_Name
	   ,Region_Code AS Region_Code
	   ,Region_Name AS Region_Name
	   ,'Count' AS [Measure_Type]
	   ,SUM([Answer]) AS [Measure_Value]
	   --CASE WHEN (SUM(CASE WHEN Question = 'SMIRegister' THEN [Value] END))=0 then null else SUM(CASE WHEN Question = 'All6PHC' THEN [Value] END)END AS [Measure_Value]

FROM [NHSE_UKHF].[Physical_Health_Checks_Severe_Mental_Illness].[vw_Data1] b

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]  cc ON b.Commissioner_Code = cc.Org_Code COLLATE SQL_Latin1_General_CP1_CI_AS

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON CASE WHEN cc.New_Code IS NULL THEN Commissioner_Code ELSE New_Code COLLATE SQL_Latin1_General_CP1_CI_AS END = ch.[Organisation_Code] 

WHERE Question = 'All6PHC' AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd

GROUP BY b.Effective_Snapshot_Date, STP_Code, STP_Name,Region_Code, Region_Name 

UNION

-- England

SELECT 
       b.Effective_Snapshot_Date as [Reporting_Period],
	   'CDP_S01' AS [CDP_Measure_ID],
	   'SMI PH Activity' AS [CDP_Measure_Name],
	   'England' AS [Org_Type]
	   ,'ENG' AS Org_Code
	   ,'England' AS [Org_Name]
	   ,'NA' AS ICB_Code
	   ,'NA' AS ICB_Name
	   ,'NA' AS Region_Code
	   ,'NA' AS Region_Name
	   ,'Count' AS [Measure_Type]
	   ,SUM([Answer]) AS [Measure_Value]
	   --CASE WHEN (SUM(CASE WHEN Question = 'SMIRegister' THEN [Value] END))=0 then null else SUM(CASE WHEN Question = 'All6PHC' THEN [Value] END)END AS [Measure_Value]

FROM [NHSE_UKHF].[Physical_Health_Checks_Severe_Mental_Illness].[vw_Data1] b

WHERE Question = 'All6PHC' AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd

GROUP BY b.Effective_Snapshot_Date

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: REALLOCATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside

-- Reallocations Data
-- Use this for if Bassetlaw_Indicator = 1
SELECT * 
  INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations
  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Raw

 WHERE Org_Code IN('01Y','06H','71E','D2P2L','QF7','Y63','QJM','QOP','Y62','QUA','QUE','Y61','15M','78H','03W','15E','QT1','Y60','QK1','QJ2','QHL','QPM') 
   AND Reporting_Period <'2022-07-01'

--No change data
-- Use this for if Bassetlaw_Indicator = 1
SELECT * 
  INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_No_Change
  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Raw
 WHERE Reporting_Period >='2022-07-01' 
    OR (Org_Code NOT IN('01Y','06H','71E','D2P2L','QF7','Y63','QJM','QOP','Y62','QUA','QUE','Y61','15M','78H','03W','15E','QT1','Y60','QK1','QJ2','QHL','QPM') 
	AND Reporting_Period <'2022-07-01' )

-- Calculate activity movement for donor orgs
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Measure_Type,
	   r.Measure_Value * Change as Measure_Value_Change,
	   [Add]

  INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Changes_From
  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations r

INNER JOIN NHSE_Sandbox_Policy.dbo.REFERENCE_CDP_Boundary_Population_Changes c ON r.Org_Code = c.[From]
 WHERE Bassetlaw_Indicator = 1	--change depending on Bassetlaw mappings (0 or 1)

-- Sum activity movement for orgs gaining (need to sum for Midlands Y60 which recieves from 2 orgs)
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   [Add] as Org_Code,
	   r.Measure_Type,
	   SUM(Measure_Value_Change) as Measure_Value_Change

  INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Changes_Add

  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Changes_From r

GROUP BY 
r.Reporting_Period,
r.CDP_Measure_ID,
r.CDP_Measure_Name,
r.Org_Type,
[Add],
r.Measure_Type

--Calculate new figures
-- From
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Org_Name,
	   r.ICB_Code,
	   r.ICB_Name,
	   r.Region_Code,
	   r.Region_Name,
	   r.Measure_Type,
	   r.Measure_Value - Measure_Value_Change as Measure_Value

  INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Final
  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations r

INNER JOIN NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Changes_From c 
        ON r.Org_Code = c.Org_Code 
       AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

UNION

--Add
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Org_Name,
	   r.ICB_Code,
	   r.ICB_Name,
	   r.Region_Code,
	   r.Region_Name,
	   r.Measure_Type,
	   r.Measure_Value + Measure_Value_Change as Measure_Value

  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations r

INNER JOIN NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Changes_Add c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Master
  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Final

UNION

SELECT * 
  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_No_Change

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 3: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
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
	   -- This set-up uses 'standard' rounding and supression rules
	   ROUND(Measure_Value,0) AS Measure_Value,
	   s.[Standard],
	   l.LTP_Trajectory_rounded AS LTP_Trajectory,
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

  INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Final
  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Master f

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories] l 
    ON f.Reporting_Period = l.Reporting_Period 
   AND f.Org_Code = l.Org_Code 
   AND (CASE WHEN f.Measure_Type IN ('Percentage','Rate','Count') 
             THEN f.CDP_Measure_ID 
			 ELSE NULL 
		END)= l.CDP_Measure_ID

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] p 
    ON f.Reporting_Period = p.Reporting_Period 
   AND f.Org_Code = p.Org_Code 
   AND (CASE WHEN f.Measure_Type IN ('Percentage','Rate','Count') 
			 THEN f.CDP_Measure_ID 
			 ELSE NULL 
	   END) = p.CDP_Measure_ID

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards] s 
    ON f.Reporting_Period = s.Reporting_Period 
   AND (CASE WHEN f.Measure_Type  IN ('Percentage','Rate','Count') 
			 THEN f.CDP_Measure_ID 
			 ELSE NULL 
	   END) = s.CDP_Measure_ID 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 4: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Set Is_Latest in current table as 0
UPDATE NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI
   SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) as Reporting_Period 
  INTO NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Is_Latest 
  FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Final


INSERT INTO NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI
SELECT
	   f.Reporting_Period,
	   CASE WHEN i.Reporting_Period IS NOT NULL 
			THEN 1 
			ELSE 0 
	   END as Is_Latest,
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
	   [Standard],
	   LTP_Trajectory,
	   LTP_Trajectory_Percentage_Achieved,
	   [Plan],
	   Plan_Percentage_Achieved,
	   CASE WHEN Measure_Value IS NULL 
			THEN '*' 
			ELSE FORMAT(Measure_Value,N'N0') 
	   END as Measure_Value_STR,
	   Standard_STR,
	   LTP_Trajectory_STR,
	   CAST(LTP_Trajectory_Percentage_Achieved*100 as varchar)+'%' as LTP_Trajectory_Percentage_Achieved_STR,
	   Plan_STR,
	   CAST(Plan_Percentage_Achieved*100 as varchar)+'%' as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified
	  -- INTO NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI
   FROM NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Final f

LEFT JOIN NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Is_Latest  i ON f.Reporting_Period = i.Reporting_Period

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI
 WHERE Region_Code LIKE 'REG%' 
	OR (Org_Type = 'SubICB' 
   AND Org_Code NOT IN (SELECT DISTINCT Organisation_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))
    OR (Org_Type = 'ICB' AND Org_Code NOT IN (SELECT DISTINCT STP_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP')) 
	OR (Org_Type = 'Region' AND Org_Code NOT IN (SELECT DISTINCT Region_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

-- Check for duplicate rows, this should return a blank table if none
SELECT DISTINCT 
	   a.Reporting_Period,
	   a.CDP_Measure_ID,
	   a.CDP_Measure_Name,
	   a.Org_Type,
	   a.Org_Code
  FROM
	   (SELECT 
			   Reporting_Period,
			   CDP_Measure_ID,
			   CDP_Measure_Name,
			   Org_Type,
			   Org_Code,
			   count(1) cnt
		 FROM NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI
         GROUP BY 
		 Reporting_Period,
		 CDP_Measure_ID,
		 CDP_Measure_Name,
		 Org_Type,
		 Org_Code
         HAVING count(1) > 1) a

-- Check for differences between new month and previous month data (nb this will look high for the YTD measures when April data comes in)

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
	   FORMAT(Percentage_Change,'P1') AS Percentage_Change


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

  FROM NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI latest

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI previous
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

--select * from NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI
--DELETE FROM NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI

--check table has updated okay
SELECT MAX(Reporting_Period)
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_S_PH_SMI]
  WHERE Measure_Value IS NOT NULL
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 6: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Raw
DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations
DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_No_Change
DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Changes_From
DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Changes_Add
DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Reallocations_Final
DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Master
DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Final
DROP TABLE NHSE_Sandbox_Policy.dbo.TEMP_CDP_S_PH_SMI_Is_Latest 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ADDITIONAL STEP - KEEPT COMMENTED OUT UNTIL NEEDED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
-- Adding future months of data for metrics with LTP trajectories/Plans
-- This only needs running once when new months are added to LTP Trajectories/Plans reference tables

--DECLARE @RPEndTargets as DATE
--DECLARE @RPStartTargets as DATE

--SET @RPStartTargets = '2023-07-01'
--SET @RPEndTargets = '2024-03-31'

--PRINT @RPStartTargets
--PRINT @RPEndTargets

--SELECT DISTINCT 
--	   Reporting_Period,
--	   CDP_Measure_ID,
--	   CDP_Measure_Name,
--	   Org_Type,
--	   Org_Code,
--	   Org_Name,
--	   Measure_Type

--  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_S_PH_SMI_Future_Months]

--FROM (SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]
--	   WHERE CDP_Measure_ID IN('CDP_S01') -- ADD MEASURE IDS FOR LTP TRAJECTORY METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets
		 
--	   UNION

--	  SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] 
--	   WHERE CDP_Measure_ID IN('CDP_S01') -- ADD MEASURE IDS FOR PLANNING METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets )_

--INSERT INTO NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI
--SELECT
--	   f.Reporting_Period,
--	   0 as Is_Latest,
--	   f.CDP_Measure_ID,
--	   f.CDP_Measure_Name,
--	   f.Org_Type,
--	   f.Org_Code,
--	   f.Org_Name,
--	   s.ICB_Code, 
--	   s.ICB_Name, 
--	   s.Region_Code, 
--	   s.Region_Name, 
--	   f.Measure_Type,
--	   NULL AS Measure_Value,
--	   NULL AS [Standard],
--	   l.LTP_Trajectory_Rounded AS LTP_Trajectory,
--	   NULL AS LTP_Trajectory_Percentage_Achieved,
--	   p.[Plan_Rounded] AS [Plan],
--	   NULL AS Plan_Percentage_Achieved,
--	   NULL AS Measure_Value_STR,
--	   NULL AS Standard_STR,
--	   l.LTP_Trajectory_STR,
--	   NULL as LTP_Trajectory_Percentage_Achieved_STR,
--	   p.Plan_STR,
--	   NULL as Plan_Percentage_Achieved_STR,
--	   GETDATE() as Last_Modified

--  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_S_PH_SMI_Future_Months] f

--LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]  p  ON f.[Reporting_Period] = p.[Reporting_Period] AND f.Org_Code = p.Org_Code AND f.[CDP_Measure_ID] = p.[CDP_Measure_ID] AND f.Org_Type = p.Org_Type
--LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]  l  ON f.[Reporting_Period] = l.[Reporting_Period] AND f.Org_Code = l.Org_Code AND f.[CDP_Measure_ID] = l.[CDP_Measure_ID] AND f.Org_Type = l.Org_Type
--INNER JOIN (SELECT DISTINCT Org_Code, Org_Name, ICB_Code, ICB_Name, Region_Code, Region_Name 
--			  FROM NHSE_Sandbox_Policy.dbo.STAGING_CDP_S_PH_SMI) s ON f.Org_Code = s.Org_Code-- Used the output table to lookup mapping

--DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_S_PH_SMI_Future_Months]
