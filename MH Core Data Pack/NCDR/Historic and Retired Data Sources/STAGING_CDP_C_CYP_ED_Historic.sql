/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
MEASURE NAME(s): CDP_C01: CYP ED Routine % (SDCS)
				 CDP_C02: CYP ED Urgent % (SDCS)

MEASURE DESCRIPTION(s):
				 CDP_C01: Percentage of patients starting routine treatment within four weeks
				 CDP_C02: Percentage of patients starting urgent treatment within one week

BACKGROUND INFO: [Anything important to know, caveats. Such as when historic data gets refreshed]

INPUT:			 [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Region1]
				 [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_STP1]
				 [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Comm1]
				 [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Prov1]
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

OUTPUT:			 [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_C_CYP_ED_Historic]

WRITTEN BY:		 Jade Sykes 27/06/2023

UPDATES:		 [insert description of any updates, insert your name and date]
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Outline timeframe 

DECLARE @RPEnd as DATE
DECLARE @RPStart as DATE

SET @RPStart = '2019-04-01'
SET @RPEnd = '2023-03-31'

PRINT @RPStart
PRINT @RPEnd

-- Delete any rows which already exist in output table for this time period
DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_C_CYP_ED]
WHERE [Reporting_Period] BETWEEN @RPStart AND @RPEnd

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR, DENOMINATOR AND PERCENTAGE TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT 
	   Effective_Snapshot_Date AS Reporting_Period,
	   'ENG' AS Org_Code,
	   'England' AS Org_Type,
	   'CDP_C02' AS CDP_Measure_ID,
	   'CYP ED Urgent % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral = '>0-1 week' then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end as [Percentage],
	   SUM(CASE WHEN Weeks_Since_Referral = '>0-1 week' 
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW]

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Region1] d

 WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
   AND Urgent_Routine = 'urgent' 
   AND Effective_Snapshot_Date NOT IN ('2022-12-31','2023-03-31')

GROUP BY 
Effective_Snapshot_Date

-- CYBER IMPUTED ENGLAND FIGURE
UNION

SELECT
	   '2022-12-31' AS Effective_Snapshot_Date,
	   'ENG' AS Org_Code,
	   'England' AS Org_Type,
	   'CDP_C02' AS CDP_Measure_ID,
	   'CYP ED Urgent % (SDCS)' AS CDP_Measure_Name,
	   428 AS Numerator,
	   553 AS Denominator

UNION

SELECT
	   '2023-03-31' AS Effective_Snapshot_Date,
	   'ENG' AS Org_Code,
	   'England' AS Org_Type,
	   'CDP_C02' AS CDP_Measure_ID,
	   'CYP ED Urgent % (SDCS)' AS CDP_Measure_Name,
	   435 AS Numerator,
	   553 AS Denominator

UNION

--REGION

SELECT 
	   Effective_Snapshot_Date,
	   Organisation_Code, 
	   'Region' AS Org_Type,
	   'CDP_C02' AS CDP_Measure_ID,
	   'CYP ED Urgent % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral = '>0-1 week' then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end AS [Percentage], 
	   SUM(CASE WHEN Weeks_Since_Referral = '>0-1 week' 
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Region1] d

WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Urgent_Routine = 'urgent'

GROUP BY 
Effective_Snapshot_Date,
Organisation_Code

UNION

--ICB

SELECT 
	   Effective_Snapshot_Date,
	   Organisation_Code COLLATE DATABASE_DEFAULT,
	   'ICB' AS Org_Type, 
	   'CDP_C02' AS CDP_Measure_ID,
	   'CYP ED Urgent % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral = '>0-1 week' then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end AS [Percentage],
	   SUM(CASE WHEN Weeks_Since_Referral = '>0-1 week' 
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_STP1] d

WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Urgent_Routine = 'urgent'

GROUP BY 
Effective_Snapshot_Date,
Organisation_Code

UNION

--CCG

SELECT 
	   Effective_Snapshot_Date,
	   cc.CCG21 COLLATE DATABASE_DEFAULT,
	   'SubICB' AS Org_Type, 
	   'CDP_C02' AS CDP_Measure_ID,
	   'CYP ED Urgent % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral = '>0-1 week' then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end AS [Percentage],
	   SUM(CASE WHEN Weeks_Since_Referral = '>0-1 week' 
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Comm1] a

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] cc 
	   ON a.Organisation_Code COLLATE DATABASE_DEFAULT = cc.IC_CCG COLLATE DATABASE_DEFAULT

WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Urgent_Routine = 'urgent'
  AND Organisation_Code <> 'X24'

GROUP BY 
Effective_Snapshot_Date,
cc.CCG21

UNION

--PROVIDER

SELECT 
	   Effective_Snapshot_Date,
	   Organisation_Code, 
	   'Provider' as Org_Type,
	   'CDP_C02' As CDP_Measure_ID,
	   'CYP ED Urgent % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral = '>0-1 week' then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end AS [Percentage],
	   SUM(CASE WHEN Weeks_Since_Referral = '>0-1 week' 
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Prov1] d

WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Urgent_Routine = 'urgent'

GROUP BY 
Effective_Snapshot_Date,
Organisation_Code

UNION

-- ROUTINE

SELECT 
	   Effective_Snapshot_Date AS [Reporting_Period],
	   'ENG' AS Org_Code,
	   'England' AS Org_Type,
	   'CDP_C01' AS CDP_Measure_ID,
	   'CYP ED Routine % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral in ('>0-1 week','>1-4 weeks') then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end as [Percentage],
	   SUM(CASE WHEN Weeks_Since_Referral in ('>0-1 week','>1-4 weeks')
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Region1] d

WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Effective_Snapshot_Date NOT IN ('2022-12-31','2023-03-31')
  AND Urgent_Routine = 'routine' 

GROUP BY 
Effective_Snapshot_Date

-- CYBER IMPUTED ENGLAND FIGURE
UNION

SELECT
	   '2022-12-31' AS Effective_Snapshot_Date,
	   'ENG' AS Org_Code,
	   'England' AS Org_Type,
	   'CDP_C01' AS CDP_Measure_ID,
	   'CYP ED Routine % (SDCS)' AS CDP_Measure_Name,
	   2080 AS [Numerator],
	   2577 AS [Denominator]

UNION

SELECT
	   '2023-03-31' AS Effective_Snapshot_Date,
	   'ENG' as Org_Code,
	   'England' as Org_Type,
	   'CDP_C01' As CDP_Measure_ID,
	   'CYP ED Routine % (SDCS)' AS CDP_Measure_Name,
	   2060 AS [Numerator],
	   2497 AS [Denominator]

UNION

--REGION

SELECT 
	   Effective_Snapshot_Date,
	   Organisation_Code, 
	   'Region' as Org_Type,
	   'CDP_C01' As CDP_Measure_ID,
	   'CYP ED Routine % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral in ('>0-1 week','>1-4 weeks') then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end as [Percentage], 
	   SUM(CASE WHEN Weeks_Since_Referral in ('>0-1 week','>1-4 weeks')
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Region1] d

 WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
   AND Urgent_Routine = 'routine'

GROUP BY 
Effective_Snapshot_Date,
Organisation_Code

UNION

--STP

SELECT 
	   Effective_Snapshot_Date,
	   Organisation_Code COLLATE DATABASE_DEFAULT,
	   'ICB' AS Org_Type, 
	   'CDP_C01' AS CDP_Measure_ID,
	   'CYP ED Routine % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral in ('>0-1 week','>1-4 weeks') then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end as [Percentage],
	   SUM(CASE WHEN Weeks_Since_Referral in ('>0-1 week','>1-4 weeks')
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_STP1] d

 WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
   AND Urgent_Routine = 'routine'

GROUP BY 
Effective_Snapshot_Date,
Organisation_Code

UNION

--CCG

SELECT 
	   Effective_Snapshot_Date,
	   cc.CCG21 COLLATE DATABASE_DEFAULT,
	   'SubICB' AS Org_Type, 
	   'CDP_C01' AS CDP_Measure_ID,
	   'CYP ED Routine % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral in ('>0-1 week','>1-4 weeks') then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end as [Percentage],
	   SUM(CASE WHEN Weeks_Since_Referral in ('>0-1 week','>1-4 weeks')
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Comm1] a

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[CCG_2020_Lookup] cc ON a.Organisation_Code COLLATE DATABASE_DEFAULT = cc.IC_CCG COLLATE DATABASE_DEFAULT

 WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
   AND Urgent_Routine = 'routine'
  AND Organisation_Code <> 'X24'

GROUP BY 
Effective_Snapshot_Date,
cc.CCG21

UNION

--PROVIDER

SELECT 
	   Effective_Snapshot_Date,
	   Organisation_Code, 
	   'Provider' AS Org_Type,
	   'CDP_C01' AS CDP_Measure_ID,
	   'CYP ED Routine % (SDCS)' AS CDP_Measure_Name,
	   --case when sum(No_Of_Patients) = 0 then NULL else
	   --sum(case when Weeks_Since_Referral in ('>0-1 week','>1-4 weeks') then (No_Of_Patients) else 0 end)*1.0 / sum(No_Of_Patients) *100 end as [Percentage],
	   SUM(CASE WHEN Weeks_Since_Referral in ('>0-1 week','>1-4 weeks')
				THEN (No_Of_Patients) 
				ELSE 0 
	   END)*1.0 AS Numerator,
	   SUM(No_Of_Patients) AS Denominator

  FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Prov1] d

 WHERE Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
   AND Urgent_Routine = 'routine'

GROUP BY 
Effective_Snapshot_Date,
Organisation_Code

-- cast as floats so all the same for the unpivot

SELECT 
	   Reporting_Period,
	   Org_Type,
	   Org_Code,
	   CDP_Measure_ID,
	   CDP_Measure_Name,
	   --CAST([Percentage]/100 AS FLOAT) AS [Percentage],
	   CAST(Numerator AS FLOAT) AS Numerator,
	   CAST(Denominator AS FLOAT) AS Denominator

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW_2]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW]

--unpivot to new structure

SELECT 
	   Reporting_Period,
	   CDP_Measure_ID,
	   CDP_Measure_Name,
	   Measure_Type,
	   Org_Type,
	   Org_Code,
	   Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW_3]
  FROM   
      (SELECT *
		 FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW_2]) p  
		UNPIVOT  
			( Measure_Value FOR Measure_Type IN   
				 (Numerator,Denominator)  
			)AS unpvt;  

--select * from [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW_3]

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_MASTER]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW_3] m

--Region names
LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name 
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) r 
					    ON Org_Code = r.Region_Code

--ICB hierarchies
LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) i
					    ON Org_Code = i.STP_Code

--SubICB hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON m.Org_Code = cc.Org_Code COLLATE database_default
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code, m.Org_Code) = ch.Organisation_Code COLLATE database_default

--Provider hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Provider_Successor] ps on m.Org_Code = ps.Prov_original COLLATE database_default
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Provider_Hierarchies] ph ON COALESCE(ps.Prov_Successor, m.Org_Code) = ph.Organisation_Code COLLATE database_default

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

--GET LIST OF UNIQUE REALLOCATIONS FOR ALL ORGS
IF OBJECT_ID ('[NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_All_Orgs]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_All_Orgs]

SELECT DISTINCT [From] COLLATE database_default as Orgs
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_All_Orgs]
  FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 1

UNION

SELECT DISTINCT [Add] COLLATE database_default as Orgs
  FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 1

-- Use this for if Bassetlaw_Indicator = 1 (bassetlaw has not yet been moved to new location)
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_MASTER]

 WHERE Org_Code IN (SELECT Orgs FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_All_Orgs])
   AND Reporting_Period <'2022-07-01'

--No change data
-- Use this for if Bassetlaw_Indicator = 1 (bassetlaw has not yet been moved to new location)
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_No_Change]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_MASTER]
 WHERE Reporting_Period >='2022-07-01' 
    OR (Org_Code NOT IN (SELECT Orgs FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_All_Orgs]) 
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_From]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations] r

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_Add]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_From] r

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_Final]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_From] c 
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

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_Add] c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated_Num_&_Den]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_Final]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_No_Change]

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
	   CASE WHEN a.CDP_Measure_ID IN ('CDP_M07','CDP_M08') THEN 'Rate' 
			ELSE 'Percentage' 
	   END as Measure_Type, -- change metric names etc
	   ((CAST(a.Measure_Value as FLOAT) 
			 ) 
		/
	   (NULLIF(CAST(b.Measure_Value as FLOAT),0)
			 ) 
	    )*100  as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated_%] 
  FROM (SELECT * 
		  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated_Num_&_Den]
		 WHERE Measure_Type = 'Numerator') a
INNER JOIN 
	   (SELECT * 
	      FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated_Num_&_Den]
		 WHERE Measure_Type = 'Denominator') b  
		    ON a.Reporting_Period = b.Reporting_Period 
		   AND a.Org_Code = b.Org_Code 
		   AND a.CDP_Measure_ID = b.CDP_Measure_ID
		   AND a.Org_Type = b.Org_Type

-- Collate Percentage calcs with rest of data
SELECT * 

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated] 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated_Num_&_Den]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated_%]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 3: ADD IN MISSING SubICBs & ICBs
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get list of SubICBs and ICBs and region
SELECT DISTINCT 
	   'SubICB' AS Org_Type,
	   Organisation_Code AS Org_Code,
	   Organisation_Name AS Org_Name,
	   STP_Code AS ICB_Code,
	   STP_Name AS ICB_Name,
	   Region_Code,
	   Region_Name

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Org_List]
  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] 

 WHERE Effective_To IS NULL 
   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'

UNION

SELECT DISTINCT 
	   'ICB' AS Org_Type,
	   STP_Code AS Org_Code,
	   STP_Name AS Org_Name,
	   STP_Code AS ICB_Code,
	   STP_Name AS ICB_Name,
	   Region_Code,
	   Region_Name

  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] 

 WHERE Effective_To IS NULL 
   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'

UNION

SELECT DISTINCT 
	   'Region' AS Org_Type,
	   Region_Code AS Org_Code,
	   Region_Name AS Org_Name,
	   'NA' AS ICB_Code,
	   'NA' AS ICB_Name,
	   Region_Code,
	   Region_Name

  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'

-- Get list of all orgs and indicator combinations
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Org_List_Dates]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Org_List]
CROSS JOIN (SELECT DISTINCT 
				   Reporting_Period, 
				   CDP_Measure_ID,
				   CDP_Measure_Name,
				   Measure_Type 
			  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated]     )_


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

 INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Missing_Orgs]

 FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Org_List_Dates] d

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated] e 
   ON d.CDP_Measure_ID = e.CDP_Measure_ID  
  AND d.Org_Type = e.Org_Type
  AND d.CDP_Measure_ID = e.CDP_Measure_ID 
  AND d.Reporting_Period = e.Reporting_Period 
  AND d.Org_Code = e.Org_Code 
  AND d.Measure_Type = e.Measure_Type 
  AND d.Org_Type = e.Org_Type

WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated] 
SELECT * FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Missing_Orgs]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 4: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
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
	   CASE 
			WHEN f.Measure_Type IN('Percentage') 
			THEN CAST(ROUND(Measure_Value,1) as FLOAT)/100 -- If rate and eng round to 1dp
			ELSE Measure_Value
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Measures]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated] f

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
STEP 5: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
--NOT NEEDED FOR HISTORIC DATA SCRIPTS
-- Set Is_Latest in current table as 0
--UPDATE [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_C_CYP_ED_Historic]
--   SET Is_Latest = 0

--Determine latest month of data for is_Latest
--SELECT MAX(Reporting_Period) as Reporting_Period 
--  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Is_Latest] 
--  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Measures]


INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_C_CYP_ED_Historic]
SELECT
	   f.Reporting_Period,
	  --NOT NEEDED FOR HISTORIC DATA SCRIPTS
	  -- CASE WHEN i.Reporting_Period IS NOT NULL 
			--THEN 1 
			--ELSE 0 
	  -- END as Is_Latest,
	   0 as Is_Latest,
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

   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Measures] f

--LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Is_Latest]  i ON f.Reporting_Period = i.Reporting_Period
LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Missing_Orgs] e ON f.CDP_Measure_ID = e.CDP_Measure_ID AND f.[Reporting_Period] = e.[Reporting_Period] AND f.[Measure_Type] = e.[Measure_Type] AND f.[Org_Code] = e.[Org_Code] AND f.[Org_Type] = e.[Org_Type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_C_CYP_ED_Historic]
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
		 FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_C_CYP_ED_Historic]
         GROUP BY 
		 Reporting_Period,
		 CDP_Measure_ID,
		 CDP_Measure_Name,
		 Measure_Type,
		 Org_Type,
		 Org_Code
         HAVING count(1) > 1) a

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 6: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR, DENOMINATOR AND PERCENTAGE TABLES
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW]
-- cast as floats so all the same for the unpivot
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW_2]
--unpivot to new structure
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_RAW_3]
-- Code for pulling org names from reference tables
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_MASTER]

--STEP 2: REALLOCATIONS
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_All_Orgs]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_No_Change]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_From]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_Add]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocations_Final]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated_%]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Reallocated]

--STEP 3: ADD IN MISSING SubICBs & ICBs
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Org_List]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Org_List_Dates]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Missing_Orgs]

--STEP 4: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Measures]

--STEP 5: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_C_CYP_ED_Is_Latest] 
