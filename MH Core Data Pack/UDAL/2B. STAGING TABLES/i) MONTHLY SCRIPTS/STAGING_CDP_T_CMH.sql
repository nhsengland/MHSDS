/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD *TEMPLATE*

MEASURE NAME:    	CDP_T01 - MHSDS CMH 2+ Contacts (Transformed)

BACKGROUND INFO: 

INPUT:			 
				MHDInternal.Dashboard_MH_CMHWaitsAccess
				[Internal_Reference].[ComCodeChanges] 
				 Reporting_UKHD_ODS.Commissioner_Hierarchies
				 [Internal_Reference].[Provider_Successor]
				 NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies
				 [MHDInternal].[REFERENCE_CDP_LTP_Trajectories]
				 [MHDInternal].[REFERENCE_CDP_Plans]
				 [MHDInternal].[REFERENCE_CDP_Standards]

OUTPUT:			 [MHDInternal].[STAGING_CDP_T_CMH]

WRITTEN BY:		 JADE SYKES

UPDATES:		 KIRSTY WALKER 07/12/2023 CHANGE FROM -1 T0 0 IN @Period_Start AND @Period_End VARIABLES FOR DEC-23 CHANGE TO SINGLE SUBMISSION WINDOW 
										  (THERE USE TO BE A PROVISIONAL DATA WINDOW SO WE WOULD DO -1 TO GET THE PERFORMANCE DATA)

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Outline timeframe (Alternatively use FY deletion method for MHSDS metrics sourced from Record Level)

DECLARE @RPEnd as DATE
DECLARE @RPStart as DATE

DECLARE @i INT

SET @RPEnd = EOMONTH(DATEADD(mm, 0, (SELECT MAX(ReportingPeriodEndDate) FROM MHDInternal.Dashboard_MH_CMHWaitsAccess)))

SET @i = 
CASE WHEN MONTH(@RPEnd) = 4 THEN -12
 WHEN MONTH(@RPEnd) = 5 THEN -1
 WHEN MONTH(@RPEnd) = 6 THEN -2
 WHEN MONTH(@RPEnd) = 7 THEN -3
 WHEN MONTH(@RPEnd) = 8 THEN -4
 WHEN MONTH(@RPEnd) = 9 THEN -5
 WHEN MONTH(@RPEnd) = 10 THEN -6
 WHEN MONTH(@RPEnd) = 11 THEN -7
 WHEN MONTH(@RPEnd) = 12 THEN -8
 WHEN MONTH(@RPEnd) = 1 THEN -9
 WHEN MONTH(@RPEnd) = 2 THEN -10
 WHEN MONTH(@RPEnd) = 3 THEN -11
END

SET @RPStart = (SELECT DATEADD(mm,@i,@RPEnd))

PRINT @RPStart
PRINT @RPEnd
PRINT @i

-- Delete any rows which already exist in output table for this time period
DELETE FROM [MHDInternal].[STAGING_CDP_T_CMH]
WHERE [Reporting_Period] BETWEEN @RPStart AND @RPEnd

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR, DENOMINATOR AND PERCENTAGE TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT
	ReportingPeriodEndDate AS [Reporting_Period],
	'CDP_T01' AS CDP_Measure_ID,
	'MHSDS CMH 2+ Contacts (Transformed)' AS CDP_Measure_Name,
	CASE WHEN [Organisation type] = 'STP' THEN 'ICB'
	WHEN [Organisation type] = 'CCG' THEN 'SubICB'
	ELSE [Organisation type] END AS [Org_Type],
	CASE WHEN [Organisation code] = 'England' THEN 'ENG' ELSE [Organisation code] END AS [Org_Code],
	[Organisation name] AS [Org_Name],
	'Count' AS Measure_Type,
	[CMH access] AS [Measure_Value]

INTO [MHDInternal].[TEMP_CDP_T_CMH_Raw] 
		
FROM MHDInternal.Dashboard_MH_CMHWaitsAccess

WHERE Der_AccessType = 'Second - PCN rolling' AND ReportingPeriodEndDate  BETWEEN @RPStart AND @RPEnd


-- Code for pulling org names from reference tables
SELECT 
	   Reporting_Period,
	   CDP_Measure_ID,
	   CDP_Measure_Name,
	   Org_Type,
	   CASE WHEN Org_Type = 'England' THEN 'ENG'
			WHEN Org_Type = 'Region' THEN m.Org_Code
			WHEN Org_Type in ('ICB', 'STP') THEN m.Org_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN COALESCE(cc.New_Code, m.Org_Code,'Missing / Invalid' COLLATE database_default)
			WHEN Org_Type = 'Provider' THEN COALESCE(ps.Prov_Successor, m.Org_Code, 'Missing / Invalid' COLLATE database_default)
			ELSE m.Org_Code
	   END as Org_Code,
	   CASE WHEN Org_Type = 'England' THEN 'England'
	   		WHEN Org_Type = 'Region' THEN r.Region_Name
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Organisation_Name
			WHEN Org_Type = 'Provider' THEN ph.Organisation_Name 
			ELSE ch.Organisation_Name 
	   END as Org_Name,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Code
			WHEN Org_Type = 'Provider' THEN ph.STP_Code
			ELSE ch.STP_Code 
	   END as ICB_Code,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Name
			WHEN Org_Type = 'Provider' THEN ph.STP_Name
			ELSE ch.STP_Name 
	   END as ICB_Name,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN r.Region_Code
			WHEN Org_Type in ('ICB','STP') THEN i.Region_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Code
			WHEN Org_Type = 'Provider' THEN ph.Region_Code
			ELSE ch.Region_Code
	   END as Region_Code,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN r.Region_Name
			WHEN Org_Type in ('ICB', 'STP') THEN i.Region_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Name
			WHEN Org_Type = 'Provider' THEN ph.Region_Name
			ELSE ch.Region_Name
	   END as Region_Name,
	   Measure_Type,
	   SUM(Measure_Value) AS Measure_Value

  INTO [MHDInternal].[TEMP_CDP_T_CMH_Master]  

  FROM [MHDInternal].[TEMP_CDP_T_CMH_Raw]  m

--Region names
LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name 
					  FROM Reporting_UKHD_ODS.Commissioner_Hierarchies) r 
					    ON Org_Code = r.Region_Code

--ICB hierarchies
LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM Reporting_UKHD_ODS.Commissioner_Hierarchies) i
					    ON Org_Code = i.STP_Code

--SubICB hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON m.Org_Code = cc.Org_Code COLLATE database_default
LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies ch ON COALESCE(cc.New_Code, m.Org_Code) = ch.Organisation_Code COLLATE database_default

--Provider hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [Internal_Reference].[Provider_Successor] ps on m.Org_Code = ps.Prov_original COLLATE database_default
LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies ph ON COALESCE(ps.Prov_Successor, m.Org_Code) = ph.Organisation_Code COLLATE database_default

GROUP BY Reporting_Period,
	   CDP_Measure_ID,
	   CDP_Measure_Name,
	   Org_Type,
	   CASE WHEN Org_Type = 'England' THEN 'ENG'
			WHEN Org_Type = 'Region' THEN m.Org_Code
			WHEN Org_Type in ('ICB', 'STP') THEN m.Org_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN COALESCE(cc.New_Code, m.Org_Code,'Missing / Invalid' COLLATE database_default)
			WHEN Org_Type = 'Provider' THEN COALESCE(ps.Prov_Successor, m.Org_Code, 'Missing / Invalid' COLLATE database_default)
			ELSE m.Org_Code
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'England'
	   		WHEN Org_Type = 'Region' THEN r.Region_Name
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Organisation_Name
			WHEN Org_Type = 'Provider' THEN ph.Organisation_Name 
			ELSE ch.Organisation_Name 
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Code
			WHEN Org_Type = 'Provider' THEN ph.STP_Code
			ELSE ch.STP_Code 
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Name
			WHEN Org_Type = 'Provider' THEN ph.STP_Name
			ELSE ch.STP_Name 
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN r.Region_Code
			WHEN Org_Type in ('ICB','STP') THEN i.Region_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Code
			WHEN Org_Type = 'Provider' THEN ph.Region_Code
			ELSE ch.Region_Code
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN r.Region_Name
			WHEN Org_Type in ('ICB', 'STP') THEN i.Region_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Name
			WHEN Org_Type = 'Provider' THEN ph.Region_Name
			ELSE ch.Region_Name
	   END,
	   Measure_Type

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: REALLOCATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside

-- Reallocations Data

--GET LIST OF UNIQUE REALLOCATIONS FOR ORGS minus bassetlaw
IF OBJECT_ID ('MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]') IS NOT NULL
DROP TABLE MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]

SELECT DISTINCT [From] COLLATE database_default as Orgs
  INTO MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]
  FROM [MHDInternal].[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 0

UNION

SELECT DISTINCT [Add] COLLATE database_default as Orgs
  FROM [MHDInternal].[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 0

-- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location)
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_T_CMH_Reallocations]
  FROM [MHDInternal].[TEMP_CDP_T_CMH_Master] 

 WHERE Org_Code IN (SELECT Orgs FROM MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
   AND Reporting_Period <'2022-07-01'

--No change data
-- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location) 
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_T_CMH_No_Change]
  FROM [MHDInternal].[TEMP_CDP_T_CMH_Master] 
 WHERE Reporting_Period >='2022-07-01' 
    OR (Org_Code NOT IN (SELECT Orgs FROM MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
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

  INTO [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Changes_From]
  FROM [MHDInternal].[TEMP_CDP_T_CMH_Reallocations] r

INNER JOIN [MHDInternal].[REFERENCE_CDP_Boundary_Population_Changes] c ON r.Org_Code = c.[From]
 WHERE Bassetlaw_Indicator = 0	--change depending on Bassetlaw mappings (0 or 1)

-- Sum activity movement for orgs gaining (need to sum for Midlands Y60 which recieves from 2 orgs)
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   [Add] as Org_Code,
	   r.Measure_Type,
	   SUM(Measure_Value_Change) as Measure_Value_Change

  INTO [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Changes_Add]
  FROM [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Changes_From] r

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

  INTO [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Final]
  FROM [MHDInternal].[TEMP_CDP_T_CMH_Reallocations] r

INNER JOIN [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Changes_From] c 
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

  FROM [MHDInternal].[TEMP_CDP_T_CMH_Reallocations] r

INNER JOIN [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Changes_Add] c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_T_CMH_Master_2]
  FROM [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Final]

UNION

SELECT * 
  FROM [MHDInternal].[TEMP_CDP_T_CMH_No_Change]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ADD IN MISSING SubICBs & ICBs
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get list of SubICBs and ICBs
SELECT DISTINCT 
'SubICB' AS Org_Type
,Organisation_Code AS [Org_Code]
,[Organisation_Name] AS Org_Name
,STP_Code AS [ICB_Code]
,STP_Name AS [ICB_Name]
,Region_Code
,Region_Name
INTO [MHDInternal].[TEMP_CDP_T_CMH_Org_List]
FROM Reporting_UKHD_ODS.Commissioner_Hierarchies WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'
AND Organisation_Name NOT LIKE '%SUB-ICB REPORTING ENTITY' --To exclude sub-ICB reporting entities being brought through with no data

UNION

SELECT DISTINCT 
'ICB' AS Org_Type
,STP_Code AS [Org_Code]
,STP_Name AS Org_Name
,STP_Code AS [ICB_Code]
,STP_Name AS [ICB_Name]
,Region_Code
,Region_Name
FROM Reporting_UKHD_ODS.Commissioner_Hierarchies WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'


-- Get list of all orgs and indicator combinations
SELECT * 
INTO [MHDInternal].[TEMP_CDP_T_CMH_Org_List_Dates]
FROM [MHDInternal].[TEMP_CDP_T_CMH_Org_List]
CROSS JOIN (SELECT DISTINCT [Reporting_Period], [CDP_Measure_ID],[CDP_Measure_Name],[Measure_Type] FROM [MHDInternal].[TEMP_CDP_T_CMH_Master_2]    )_


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
	   NULL AS Measure_Value

	   INTO [MHDInternal].[TEMP_CDP_T_CMH_Missing_Orgs]

	   FROM [MHDInternal].[TEMP_CDP_T_CMH_Org_List_Dates] d

LEFT JOIN [MHDInternal].[TEMP_CDP_T_CMH_Master_2]  e ON d.CDP_Measure_ID = e.CDP_Measure_ID  AND d.[Org_Type] = e.[Org_Type] AND d.CDP_Measure_ID = e.CDP_Measure_ID AND  d.[Reporting_Period] = e.[Reporting_Period] AND d.[Org_Code] = e.[Org_Code] AND d.[Measure_Type] = e.[Measure_Type] AND d.[Org_Type] = e.[Org_Type]
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [MHDInternal].[TEMP_CDP_T_CMH_Master_2] 
SELECT * FROM [MHDInternal].[TEMP_CDP_T_CMH_Missing_Orgs]

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
	   CASE WHEN f.Measure_Type IN('Percentage') AND f.Org_Type = 'England' 
			THEN CAST(ROUND(Measure_Value,1) as FLOAT)/100 -- If rate and eng round to 1dp
		    WHEN f.Measure_Type IN('Percentage') AND f.Org_Type <> 'England' 
			THEN CAST(ROUND(Measure_Value,0) as FLOAT)/100 -- If rate and not Eng then round to 0dp
            WHEN f.Measure_Type IN('Rate') AND f.Org_Type = 'England' 
			THEN CAST(ROUND(Measure_Value,1) as FLOAT)
            WHEN f.Measure_Type IN('Rate') AND f.Org_Type <> 'England' 
			THEN CAST(ROUND(Measure_Value,0) as FLOAT)
			WHEN Measure_Value < 5 
			THEN NULL -- supressed values shown as NULL
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

  INTO [MHDInternal].[TEMP_CDP_T_CMH_Final]
  FROM [MHDInternal].[TEMP_CDP_T_CMH_Master_2] f

LEFT JOIN [MHDInternal].[REFERENCE_CDP_LTP_Trajectories] l 
    ON f.Reporting_Period = l.Reporting_Period 
   AND f.Org_Code = l.Org_Code 
   AND f.CDP_Measure_ID = l.CDP_Measure_ID
   AND f.Measure_Type = l.Measure_Type

LEFT JOIN [MHDInternal].[REFERENCE_CDP_Plans] p 
    ON f.Reporting_Period = p.Reporting_Period 
   AND f.Org_Code = p.Org_Code 
   AND f.CDP_Measure_ID = p.CDP_Measure_ID 
   AND f.Measure_Type = p.Measure_Type

LEFT JOIN [MHDInternal].[REFERENCE_CDP_Standards] s 
    ON f.Reporting_Period = s.Reporting_Period 
   AND f.CDP_Measure_ID = s.CDP_Measure_ID 
   AND f.Measure_Type = s.Measure_Type


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 4: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Set Is_Latest in current table as 0
--UPDATE [MHDInternal].[STAGING_CDP_T_CMH]
--   SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) as Reporting_Period 
  INTO [MHDInternal].[TEMP_CDP_T_CMH_Is_Latest] 
  FROM [MHDInternal].[TEMP_CDP_T_CMH_Final]


INSERT INTO [MHDInternal].[STAGING_CDP_T_CMH]
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
			WHEN f.Measure_Type IN('Percentage') THEN CAST(f.[Measure_Value]*100 AS VARCHAR)+'%' 
			ELSE FORMAT(f.[Measure_Value],N'N0') END AS [Measure_Value_STR],
	   Standard_STR,
	   LTP_Trajectory_STR,
	   CAST(LTP_Trajectory_Percentage_Achieved*100 as varchar)+'%' as LTP_Trajectory_Percentage_Achieved_STR,
	   Plan_STR,
	   CAST(Plan_Percentage_Achieved*100 as varchar)+'%' as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified

   --INTO [MHDInternal].[STAGING_CDP_T_CMH]
   FROM [MHDInternal].[TEMP_CDP_T_CMH_Final] f

LEFT JOIN [MHDInternal].[TEMP_CDP_T_CMH_Is_Latest] i ON f.Reporting_Period = i.Reporting_Period
LEFT JOIN [MHDInternal].[TEMP_CDP_T_CMH_Missing_Orgs] e ON f.CDP_Measure_ID = e.CDP_Measure_ID AND f.[Reporting_Period] = e.[Reporting_Period] AND f.[Measure_Type] = e.[Measure_Type] AND f.[Org_Code] = e.[Org_Code] AND f.[Org_Type] = e.[Org_Type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [MHDInternal].[STAGING_CDP_T_CMH]
 WHERE Region_Code LIKE 'REG%' 
	OR Org_Code IS NULL 
	OR (Org_Type = 'SubICB' 
   AND Org_Code NOT IN (SELECT DISTINCT Organisation_Code FROM Reporting_UKHD_ODS.Commissioner_Hierarchies WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))
    OR (Org_Type = 'ICB' AND Org_Code NOT IN (SELECT DISTINCT STP_Code FROM Reporting_UKHD_ODS.Commissioner_Hierarchies WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP')) 
	OR (Org_Type = 'Region' AND Org_Code NOT IN (SELECT DISTINCT Region_Code FROM Reporting_UKHD_ODS.Commissioner_Hierarchies WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

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
		 FROM [MHDInternal].[STAGING_CDP_T_CMH]
         GROUP BY 
		 Reporting_Period,
		 CDP_Measure_ID,
		 CDP_Measure_Name,
		 Measure_Type,
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

  FROM [MHDInternal].[STAGING_CDP_T_CMH] latest

  LEFT JOIN [MHDInternal].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [MHDInternal].[STAGING_CDP_T_CMH] previous
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
  FROM [MHDInternal].[STAGING_CDP_T_CMH]
 WHERE Measure_Value IS NOT NULL
		 
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 6: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Raw] 
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Master] 
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Reallocations]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_No_Change]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Changes_From]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Changes_Add]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Reallocations_Final]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Master_2]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Org_List]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Org_List_Dates]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Missing_Orgs]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Final]
DROP TABLE [MHDInternal].[TEMP_CDP_T_CMH_Is_Latest]


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

--  INTO MHDInternal.[TEMP_CDP_T_CMH_Future_Months]

--FROM (SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [MHDInternal].[REFERENCE_CDP_LTP_Trajectories]
--	   WHERE CDP_Measure_ID IN('CDP_T01') -- ADD MEASURE IDS FOR LTP TRAJECTORY METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets
		 
--	   UNION

--	  SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [MHDInternal].[REFERENCE_CDP_Plans] 
--	   WHERE CDP_Measure_ID IN('CDP_T01') -- ADD MEASURE IDS FOR PLANNING METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets )_

--INSERT INTO [MHDInternal].[STAGING_CDP_T_CMH]
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

--  FROM MHDInternal.[TEMP_CDP_T_CMH_Future_Months] f

--LEFT JOIN [MHDInternal].[REFERENCE_CDP_Plans]  p  ON f.[Reporting_Period] = p.[Reporting_Period] AND f.Org_Code = p.Org_Code AND f.[CDP_Measure_ID] = p.[CDP_Measure_ID] AND f.Org_Type = p.Org_Type
--LEFT JOIN [MHDInternal].[REFERENCE_CDP_LTP_Trajectories]  l  ON f.[Reporting_Period] = l.[Reporting_Period] AND f.Org_Code = l.Org_Code AND f.[CDP_Measure_ID] = l.[CDP_Measure_ID] AND f.Org_Type = l.Org_Type
--INNER JOIN (SELECT DISTINCT Org_Code, Org_Name, ICB_Code, ICB_Name, Region_Code, Region_Name 
--			  FROM [MHDInternal].[STAGING_CDP_T_CMH]) s ON f.Org_Code = s.Org_Code-- Used the output table to lookup mapping

--DROP TABLE MHDInternal.[TEMP_CDP_T_CMH_Future_Months]



