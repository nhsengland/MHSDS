/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD

MEASURE NAME:	 MHSDS IPS (CDP_I01)

MEASURE DESCRIPTION: 
				 Total accessed (first contact in year) - number of people accessing Individual Placement and? Support (IPS) services. 
				 IPS is a model of employment support integrated within community mental health teams which helps people with severe mental health conditions into employment.

BACKGROUND INFO: 

INPUT:			 [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild] (Comes from patient level MHSDS data (unpublished))
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Provider_Hierarchies]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_Provider_Successor]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards]

TEMP TABLES:	 SEE DROPPED TABLES AT END OF THE SCRIPT.

OUTPUT:			 [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]

WRITTEN BY:		 Kirsty Walker 05/07/2023

UPDATES:		 JADE SYKES    07/12/2023 CHANGE FROM -1 T0 0 IN @Period_Start AND @Period_End VARIABLES FOR DEC-23 CHANGE TO SINGLE SUBMISSION WINDOW 
										  (THERE USE TO BE A PROVISIONAL DATA WINDOW SO WE WOULD DO -1 TO GET THE PERFORMANCE DATA)
				 KIRSTY WALKER 15/12/2023 Commented out the mapping to MPL as was causing double counting in output, the joins need to be done in a slightly different way, happy to talk thru :)

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>.>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Outline timeframe (Alternatively use FY deletion method for MHSDS metrics sourced from Record Level)
-- For metrics which we need to re-run the whole of the current FY each month use this (MHSDS from patient level)
DECLARE @RPEnd as DATE
DECLARE @RPStart as DATE

DECLARE @i INT
 
SET @RPEnd = (SELECT eomonth(dateadd(month,0,MAX(ReportingPeriodEnd))) 
			    FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild])  

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
--SET @RPStart = '2019-04-30'

PRINT @RPStart
PRINT @RPEnd
PRINT @i

-- Delete any rows which already exist in output table for this time period
DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]
WHERE [Reporting_Period] BETWEEN @RPStart AND @RPEnd

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED MEASURE TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

---------- Provider --------

SELECT 
       s.ReportingPeriodEnd as Reporting_Period,
	   'CDP_I01' as CDP_Measure_ID,
	   'MHSDS IPS' as CDP_Measure_Name,
	   'Provider' as Org_Type,
	   COALESCE(ps.Prov_Successor, s.OrgIDProv,'Missing / Invalid' COLLATE database_default) as Org_Code,
	   COALESCE(ph.Organisation_Name, st.Organisation_Name) as Org_Name, --this was under the [ICB Name - CCG Code] naming convention in the NCDR table but in the [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] table in UDAL this will become the SUB LOCATION name.
	   COALESCE(ph.STP_Code,st.ICB_Code) as ICB_Code,
	   COALESCE(ph.STP_Name,chst1.STP_Code) as ICB_Name,
	   COALESCE(ph.Region_Code, st.Region_Code) AS Region_Code,
	   COALESCE(ph.Region_Name,chst2.Region_Name) AS Region_Name,
	   'Count' as Measure_Type,
	   sum(s.MeasureValue) as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs]

  FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild] s

--Provider hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Provider_Successor] ps on s.OrgIDProv = ps.Prov_original COLLATE database_default
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Provider_Hierarchies] ph ON COALESCE(ps.Prov_Successor, s.OrgIDProv) = ph.Organisation_Code COLLATE database_default
LEFT JOIN (SELECT DISTINCT Org_Code, Organisation_Name, ICB_Code, Region_Code FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_MHSDS_Submission_Tracker]) st on s.OrgIDProv = st.Org_Code
	LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) chst1 ON st.ICB_Code = chst1.STP_Code -- GET ICB NAME FROM ODS FOR CONSISTENCY FOR MLP
	LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) chst2 ON st.Region_Code = chst2.Region_Code -- GET REG NAME FROM ODS FOR CONSISTENCY FOR MPL

 WHERE s.ReportingPeriodEnd between @RPStart and @RPEnd
   AND s.MeasureName = 'AccessedInFinancialYear' -- Total accessed (first contact in financial year) on dashboard

GROUP BY
	   s.ReportingPeriodEnd,
	   COALESCE(ps.Prov_Successor, s.OrgIDProv,'Missing / Invalid' COLLATE database_default),
	   COALESCE(ph.Organisation_Name, st.Organisation_Name), --this was under the [ICB Name - CCG Code] naming convention in the NCDR table but in the [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] table in UDAL this will become the SUB LOCATION name.
	   COALESCE(ph.STP_Code,st.ICB_Code),
	   COALESCE(ph.STP_Name,chst1.STP_Code),
	   COALESCE(ph.Region_Code, st.Region_Code),
	   COALESCE(ph.Region_Name,chst2.Region_Name)

UNION
---------- SubICB --------

SELECT 
       s.ReportingPeriodEnd as Reporting_Period,
	   'CDP_I01' as CDP_Measure_ID,
	   'MHSDS IPS' as CDP_Measure_Name,
	   'SubICB' as Org_Type,
	   COALESCE(cc.New_Code, s.OrgIDCCGRes,'Missing / Invalid' COLLATE database_default) as Org_Code,
	   ch.Organisation_Name as Org_Name, --this was under the [ICB Name - CCG Code] naming convention in the NCDR table but in the [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] table in UDAL this will become the SUB LOCATION name.
	   ch.STP_Code as ICB_Code,
	   ch.STP_Name as ICB_Name,
	   ch.Region_Code,
	   ch.Region_Name,
	   'Count' as Measure_Type,
	   sum(s.MeasureValue) as Measure_Value

  FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild] s

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON s.OrgIDCCGRes= cc.Org_Code COLLATE database_default
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code,s.OrgIDCCGRes) = ch.Organisation_Code COLLATE database_default

 WHERE s.ReportingPeriodEnd between @RPStart and @RPEnd
   AND s.MeasureName = 'AccessedInFinancialYear' -- Total accessed (first contact in financial year) on dashboard

GROUP BY
	   s.ReportingPeriodEnd,
	   COALESCE(cc.New_Code, s.OrgIDCCGRes,'Missing / Invalid' COLLATE database_default),
	   ch.Organisation_Name,
	   ch.STP_Code,
	   ch.STP_Name,
	   ch.Region_Code,
	   ch.Region_Name

UNION
---------- ICB --------

SELECT 
       s.ReportingPeriodEnd as Reporting_Period,
	   'CDP_I01' as CDP_Measure_ID,
	   'MHSDS IPS' as CDP_Measure_Name,
	   'ICB' as Org_Type,
	   s.STP_Code as Org_Code,
	   i.STP_Name as Org_Name, --this was under the [ICB Name - CCG Code] naming convention in the NCDR table but in the [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] table in UDAL this will become the SUB LOCATION name.
	   i.STP_Code as ICB_Code,
	   i.STP_Name as ICB_Name,
	   i.Region_Code,
	   i.Region_Name,
	   'Count' as Measure_Type,
	   sum(s.MeasureValue) as Measure_Value

  FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild] s

--ICB hierarchies
LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) i
					    ON s.STP_Code = i.STP_Code

 WHERE s.ReportingPeriodEnd between @RPStart and @RPEnd
   AND s.MeasureName = 'AccessedInFinancialYear' -- Total accessed (first contact in financial year) on dashboard

GROUP BY
	   s.ReportingPeriodEnd,
	   s.STP_Code,
	   i.STP_Name, 
	   i.STP_Code,
	   i.STP_Name,
	   i.Region_Code,
	   i.Region_Name

UNION
---------- Region --------

SELECT 
       s.ReportingPeriodEnd as Reporting_Period,
	   'CDP_I01' as CDP_Measure_ID,
	   'MHSDS IPS' as CDP_Measure_Name,
	   'Region' as Org_Type,
	   s.Region_Code as Org_Code,
	   r.Region_Name as Org_Name, --this was under the [ICB Name - CCG Code] naming convention in the NCDR table but in the [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] table in UDAL this will become the SUB LOCATION name.
	   'NA' as ICB_Code,
	   'NA' as ICB_Name,
	   s.Region_Code,
	   r.Region_Name,
	   'Count' as Measure_Type,
	   sum(s.MeasureValue) as Measure_Value

  FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild] s

--Region names
LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name 
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) r 
					    ON s.Region_Code = r.Region_Code

 WHERE s.ReportingPeriodEnd between @RPStart and @RPEnd
   AND s.MeasureName = 'AccessedInFinancialYear' -- Total accessed (first contact in financial year) on dashboard

GROUP BY
	   s.ReportingPeriodEnd,
	   s.Region_Code,
	   r.Region_Name

UNION
---------- England --------

SELECT 
       s.ReportingPeriodEnd as Reporting_Period,
	   'CDP_I01' as CDP_Measure_ID,
	   'MHSDS IPS' as CDP_Measure_Name,
	   'England' as Org_Type,
	   'ENG' as Org_Code,
	   'England' as Org_Name, --this was under the [ICB Name - CCG Code] naming convention in the NCDR table but in the [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] table in UDAL this will become the SUB LOCATION name.
	   'NA' as ICB_Code,
	   'NA' as ICB_Name,
	   'NA' as Region_Code,
	   'NA' as Region_Name,
	   'Count' as Measure_Type,
	   sum(s.MeasureValue) as Measure_Value

  FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS_rebuild] s

 WHERE s.ReportingPeriodEnd between @RPStart and @RPEnd
   AND s.MeasureName = 'AccessedInFinancialYear' -- Total accessed (first contact in financial year) on dashboard

GROUP BY
	   s.ReportingPeriodEnd

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: REALLOCATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside

-- Reallocations Data

--GET LIST OF UNIQUE REALLOCATIONS FOR ORGS minus bassetlaw
IF OBJECT_ID ('[NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]

SELECT DISTINCT [From] COLLATE database_default as Orgs
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]
  FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 0

UNION

SELECT DISTINCT [Add] COLLATE database_default as Orgs
  FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 0

-- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location)
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs]

 WHERE Org_Code IN (SELECT Orgs FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
   AND Reporting_Period <'2022-07-01'

--No change data
-- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location) 
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_No_Change]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs]
 WHERE Reporting_Period >='2022-07-01' 
    OR (Org_Code NOT IN (SELECT Orgs FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Changes_From]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes] c ON r.Org_Code = c.[From]
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Changes_Add]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Changes_From] r

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Final]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Changes_From] c 
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

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Changes_Add] c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocated]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Final]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_No_Change]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 3: CALCULATE IPS CUMULATIVE
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
	   CASE when f.Reporting_Period like '%-04-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 0 PRECEDING AND CURRENT ROW) 
		    when f.Reporting_Period like '%-05-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-06-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-07-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-08-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-09-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-10-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-11-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 7 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-12-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 8 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-01-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-02-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) 
			when f.Reporting_Period like '%-03-%' then SUM(SUM(f.Measure_Value)) OVER (PARTITION BY f.Org_Type, f.Org_Code, f.Org_Name ORDER BY f.Reporting_Period ASC ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) 
	   END as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocated] f

GROUP BY
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
	   f.Measure_Type

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 4: ADD IN MISSING SubICBs & ICBs
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Org_List]
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
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Org_List_Dates]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Org_List]
CROSS JOIN (SELECT DISTINCT 
				   Reporting_Period, 
				   CDP_Measure_ID,
				   CDP_Measure_Name,
				   Measure_Type 
			  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative])_

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

 INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Missing_Orgs]

 FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Org_List_Dates] d

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative] e 
   ON d.Reporting_Period = e.Reporting_Period
  AND d.CDP_Measure_ID = e.CDP_Measure_ID  
  AND d.Org_Type = e.Org_Type
  AND d.Org_Code = e.Org_Code 
  AND d.Measure_Type = e.Measure_Type 
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative]
SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Missing_Orgs]

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
	   -- This set-up uses 'standard' rounding and supression rules
	   CASE WHEN Measure_Value < 5 
			THEN NULL -- supressed values shown as NULL
			WHEN f.Org_Type = 'England' 
			THEN Measure_Value -- Counts for Eng no rounding
			ELSE CAST(ROUND(Measure_Value/5.0,0)*5 as FLOAT) 
	   END as Measure_Value,
	   s.[Standard],
	   l.[LTP_Trajectory_Rounded] AS [LTP_Trajectory],
	   ROUND(CAST(Measure_Value as FLOAT)/NULLIF(CAST(l.LTP_Trajectory as FLOAT),0),2) as LTP_Trajectory_Percentage_Achieved,
	   p.[Plan_Rounded] AS [Plan],
	   ROUND(CAST(Measure_Value as FLOAT)/NULLIF(CAST(p.[Plan] as FLOAT),0),2) as Plan_Percentage_Achieved,
	   s.Standard_STR,
	   l.LTP_Trajectory_STR,
	   p.Plan_STR

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative_Rounded_&_Targets]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative] f

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
UPDATE [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]
SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) as Reporting_Period 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Is_Latest] 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative_Rounded_&_Targets]


INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]
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
			WHEN f.Measure_Type IN('Percentage') THEN FORMAT(f.Measure_Value,'P1')
			ELSE FORMAT(f.[Measure_Value],N'N0') 
	   END AS [Measure_Value_STR],
	   Standard_STR,
	   LTP_Trajectory_STR,
	   CAST(LTP_Trajectory_Percentage_Achieved*100 as varchar)+'%' as LTP_Trajectory_Percentage_Achieved_STR,
	   Plan_STR,
	   CAST(Plan_Percentage_Achieved*100 as varchar)+'%' as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative_Rounded_&_Targets] f

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Is_Latest] i ON f.Reporting_Period = i.Reporting_Period

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Missing_Orgs] e 
  ON  f.Reporting_Period = e.Reporting_Period
 AND f.CDP_Measure_ID = e.CDP_Measure_ID 
 AND f.Org_Type = e.Org_Type
 AND f.Org_Code = e.Org_Code
 AND f.Measure_Type = e.Measure_Type


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 7: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]
 WHERE Region_Code LIKE 'REG%' 
	OR Org_Code IS NULL 
	OR (Org_Type = 'SubICB' 
   AND Org_Code NOT IN (SELECT DISTINCT Organisation_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))
    OR (Org_Type = 'ICB' AND Org_Code NOT IN (SELECT DISTINCT STP_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP')) 
	OR (Org_Type = 'Region' AND Org_Code NOT IN (SELECT DISTINCT Region_Code FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

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
		 FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]
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
	   ICB_Code,
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
	   latest.ICB_Code,
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

  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS] latest

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS] previous
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
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]
  WHERE Measure_Value IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 7: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED MEASURE TABLE
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs]

--STEP 2: REALLOCATIONS
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_No_Change]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Changes_From]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Changes_Add]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocations_Final]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_All_Orgs_Reallocated]

--STEP 3: CALCULATE IPS CUMULATIVE
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative]

--STEP 4: ADD IN MISSING SubICBs & ICBs
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Org_List]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Org_List_Dates]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Missing_Orgs]

--STEP 5: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Cumulative_Rounded_&_Targets]

--STEP 6: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Is_Latest]

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

--  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Future_Months]

--FROM (SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]
--	   WHERE CDP_Measure_ID IN('CDP_I01') -- ADD MEASURE IDS FOR LTP TRAJECTORY METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets
		 
--	   UNION

--	  SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] 
--	   WHERE CDP_Measure_ID IN('CDP_I01') -- ADD MEASURE IDS FOR PLANNING METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets )_

--INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]
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

--  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Future_Months] f

--LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]  p  ON f.[Reporting_Period] = p.[Reporting_Period] AND f.Org_Code = p.Org_Code AND f.[CDP_Measure_ID] = p.[CDP_Measure_ID] AND f.Org_Type = p.Org_Type
--LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]  l  ON f.[Reporting_Period] = l.[Reporting_Period] AND f.Org_Code = l.Org_Code AND f.[CDP_Measure_ID] = l.[CDP_Measure_ID] AND f.Org_Type = l.Org_Type
--INNER JOIN (SELECT DISTINCT Org_Code, Org_Name, ICB_Code, ICB_Name, Region_Code, Region_Name 
--			  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]) s ON f.Org_Code = s.Org_Code-- Used the output table to lookup mapping

--DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_I_IPS_Future_Months]