/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD

MEASURE NAME(s): OAPs Bed Days (inappropriate only) (CDP_O01)
				 OAPs started in period (inappropriate only) (CDP_O02)

MEASURE DESCRIPTION(s):
				 The total number of days in which patients have been placed out of area due to unavailable beds in their usual network.
				 Total number of inappropriate OAPs started in the period.


BACKGROUND INFO: Publication contains ONS (E) codes. Some codes not currently available in reference tables so are hardcoded, details below.
				 There is one month where the question name wording is slightly different (July 2019)

INPUT:			 [UKHF_Mental_Health].[Out_Of_Area_Placements1]
				 [UKHD_ODS].[STP_Names_And_Codes_England_SCD]
				 [Internal_Reference].[ComCodeChanges]
				 [Reporting_UKHD_ODS].[Commissioner_Hierarchies]
				 [Reporting_UKHD_ODS].[Provider_Hierarchies]
				 [Internal_Reference].[Provider_Successor]
				 [MHDInternal].[Reference_CDP_Boundary_Population_Changes]
				 [MHDInternal].[Reference_CDP_Trajectories]
				 [MHDInternal].[Reference_CDP_Plans]
				 [MHDInternal].[Reference_CDP_Standards]

TEMP TABLES:	 SEE DROPPED TABLES AT END OF THE SCRIPT.

OUTPUT:			 [MHDInternal].[STAGING_CDP_O_OAPs]

WRITTEN BY:		 Jade Sykes 25/5/23

UPDATES:		 [insert description of any updates, insert your name and date]

<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Outline timeframe (Alternatively use FY deletion method for MHSDS metrics sourced from Record Level)

DECLARE @RPEnd AS DATE
DECLARE @RPStart AS DATE
DECLARE @PreviousEOY as Date  ---Used to calculate standards - see step 6

SET @RPEnd = (SELECT MAX(REPORTING_PERIOD_END) FROM UKHF_Mental_Health.Monthly_MHSDS_Out_Of_Area_Placements1)-- These can be manually changed when refreshing for end of financial year refresh

SET @RPStart =@RPEnd -- This can be manually changed when refreshing for end of financial year refresh '2022-04-01' 

SET @PreviousEOY=EOMONTH(CASE WHEN  MONTH(@RPEnd)>3 Then DATEADD(MONTH,-1*(MONTH(@RPEnd)-3),@RPEnd) ELSE DATEADD(MONTH,-1*(MONTH(@RPEnd)+9),@RPEnd) END,0)

PRINT @RPStart
PRINT @RPEnd
PRINT @PreviousEOY

---- Delete any rows which already exist in output table for this time period
DELETE FROM [MHDInternal].[STAGING_CDP_O_OAPs] 
WHERE [Reporting_Period] BETWEEN @RPStart AND @RPEnd

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1: CREATE MASTER TABLE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Provider
SELECT 
	   Reporting_Period_End as Reporting_Period,
	   CASE 
			WHEN Metric = 'OAP02a' THEN 'CDP_O01' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'CDP_O02' --CHECK
		 END AS CDP_Measure_ID,

	   CASE WHEN Metric = 'OAP02a' THEN 'OAPs Bed Days (inappropriate only)' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'OAPs active at the end of the period (inappropriate only)'--CHECK?

	  END as CDP_Measure_Name,

	  'Provider' as Org_Type,
	  Primary_Level as Org_Code,
	  'Count' as Measure_Type,
	  Metric_Value as Measure_Value

INTO [MHDInternal].[TEMP_CDP_O_OAPs_Raw]

FROM UKHF_Mental_Health.Monthly_MHSDS_Out_Of_Area_Placements1 oap

INNER JOIN [Reporting_UKHD_ODS].[Provider_Hierarchies] ph ON oap.Primary_Level = ph.Organisation_Code COLLATE database_default --only bring through providers in the [Provider_Hierarchies] table

WHERE Metric IN ('OAP02a','OAP03a') --To confirm this is what's needed

  AND Breakdown = 'Sending Provider'
  AND Reporting_Period_End BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'Quarterly'
  AND ph.NHSE_Organisation_Type NOT LIKE '%SITE%' --Exclude provider sites from the reporting
  AND ph.NHSE_Organisation_Type NOT IN ('LOCAL HEALTH BOARD','PRESCRIBING COST CENTRE','UNKNOWN') --Exclude these provider types from the reporting

UNION

 --SubICB
SELECT 
	   Reporting_Period_End as Reporting_Period,
	   CASE 
			WHEN Metric = 'OAP02a' THEN 'CDP_O01' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'CDP_O02' --CHECK
		 END AS CDP_Measure_ID,

	   CASE WHEN Metric = 'OAP02a' THEN 'OAPs Bed Days (inappropriate only)' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'OAPs active at the end of the period (inappropriate only)'--CHECK?
	  END as CDP_Measure_Name,

	  'SubICB' as Org_Type,
	  CASE WHEN o.New_Code IS NULL 
		   THEN oap.Primary_Level COLLATE SQL_Latin1_General_CP1_CI_AS 
		   ELSE o.New_Code 
	  END as Org_Code,
	  'Count' as Measure_Type,
	  SUM(Metric_Value) as Measure_Value

 FROM UKHF_Mental_Health.Monthly_MHSDS_Out_Of_Area_Placements1 oap

LEFT JOIN [Internal_Reference].[ComCodeChanges] o ON oap.Primary_Level = o.Org_Code COLLATE SQL_Latin1_General_CP1_CI_AS

WHERE Metric IN ('OAP02a','OAP03a') --To confirm this is what's needed
  AND Breakdown = 'Sub ICB of GP Practice or Residence'
  AND Reporting_Period_End BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'Quarterly'
  --AND Breakdown not in ('999','England')

GROUP BY 	   
	Reporting_Period_End,
	   CASE 
			WHEN Metric = 'OAP02a' THEN 'CDP_O01' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'CDP_O02' --CHECK
			END,
	   CASE 
			WHEN Metric = 'OAP02a' THEN 'OAPs Bed Days (inappropriate only)' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'OAPs active at the end of the period (inappropriate only)'--CHECK?
			END,
	  CASE 
			WHEN o.New_Code IS NULL 
			THEN oap.Primary_Level COLLATE SQL_Latin1_General_CP1_CI_AS 
			ELSE o.New_Code 
			END

UNION

-- ICB
SELECT 
	   Reporting_Period_End as Reporting_Period,
	   CASE 
			WHEN Metric = 'OAP02a' THEN 'CDP_O01' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'CDP_O02' --CHECK
		 END AS CDP_Measure_ID,

	   CASE WHEN Metric = 'OAP02a' THEN 'OAPs Bed Days (inappropriate only)' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'OAPs active at the end of the period (inappropriate only)'--CHECK?
	  END as CDP_Measure_Name,

	  'ICB' as Org_Type,
	  Primary_Level AS Org_Code,
	  'Count' as Measure_Type,
	  Metric_Value as Measure_Value

FROM UKHF_Mental_Health.Monthly_MHSDS_Out_Of_Area_Placements1 oap

--LEFT JOIN [UKHD_ODS].[STP_Names_And_Codes_England_SCD] s ON oap.Primary_Level = s.STP_Code COLLATE SQL_Latin1_General_CP1_CI_AS

WHERE Metric IN ('OAP02a','OAP03a') --To confirm this is what's needed
  AND Breakdown = 'ICB of GP Practice or Residence'
  AND Reporting_Period_End BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'Quarterly'
  

UNION

 --Region
SELECT 
	   Reporting_Period_End as Reporting_Period,
	   CASE 
			WHEN Metric = 'OAP02a' THEN 'CDP_O01' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'CDP_O02' --CHECK
		 END AS CDP_Measure_ID,

	   CASE WHEN Metric = 'OAP02a' THEN 'OAPs Bed Days (inappropriate only)' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'OAPs active at the end of the period (inappropriate only)'--CHECK?
	  END as CDP_Measure_Name,

	  'Region' as Org_Type,
	  Primary_Level AS Org_Code,
	  'Count' as Measure_Type,
	  Metric_Value as Measure_Value

FROM UKHF_Mental_Health.Monthly_MHSDS_Out_Of_Area_Placements1 oap

WHERE Metric IN ('OAP02a','OAP03a') --To confirm this is what's needed
  AND Breakdown = 'Commissioning Region'
  AND Reporting_Period_End BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'Quarterly'


UNION 

 --England
SELECT 
	   Reporting_Period_End as Reporting_Period,
	   CASE 
			WHEN Metric = 'OAP02a' THEN 'CDP_O01' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'CDP_O02' --CHECK
		 END AS CDP_Measure_ID,

	   CASE WHEN Metric = 'OAP02a' THEN 'OAPs Bed Days (inappropriate only)' --CHECK?
			WHEN Metric = 'OAP03a' THEN 'OAPs active at the end of the period (inappropriate only)'--CHECK?
	  END as CDP_Measure_Name,
	  'England' as Org_Type,
	  'ENG' AS Org_Code,
	  'Count' as Measure_Type,
	  Metric_Value as Measure_Value

FROM UKHF_Mental_Health.Monthly_MHSDS_Out_Of_Area_Placements1 oap

WHERE Metric IN ('OAP02a','OAP03a') --To confirm this is what's needed

  AND Breakdown = 'England'
  AND Reporting_Period_End BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'Quarterly'


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

  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Master]

  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Raw] m

--Region names
LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name 
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]) r 
					    ON Org_Code = r.Region_Code COLLATE database_default

--ICB hierarchies
LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]) i
					    ON Org_Code = i.STP_Code COLLATE database_default

--SubICB hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON m.Org_Code = cc.Org_Code COLLATE database_default
LEFT JOIN [Reporting_UKHD_ODS].[Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code, m.Org_Code) = ch.Organisation_Code COLLATE database_default

--Provider hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [Internal_Reference].[Provider_Successor] ps on m.Org_Code = ps.Prov_original COLLATE database_default
LEFT JOIN [Reporting_UKHD_ODS].[Provider_Hierarchies] ph ON COALESCE(ps.Prov_Successor, m.Org_Code) = ph.Organisation_Code COLLATE database_default

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

-- COLLATE DATABASE_DEFAULT 

SELECT  
	   Reporting_Period,
       CDP_Measure_ID collate database_default as CDP_Measure_ID,
       CDP_Measure_Name collate database_default as CDP_Measure_Name,
       Org_Type collate database_default as Org_Type,
       Org_Code collate database_default as Org_Code,
       Org_Name collate database_default as Org_Name,
       ICB_Code collate database_default as ICB_Code,
       ICB_Name collate database_default as ICB_Name,
       Region_Code collate database_default as Region_Code,
       Region_Name collate database_default as Region_Name,
       Measure_Type collate database_default as Measure_Type,
       CAST(Measure_Value as float) as Measure_Value

  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Master_2]

  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Master]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: REALLOCATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside

-- Reallocations Data
-- Use this for if Bassetlaw_Indicator = 1
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations]
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Master_2]

 WHERE Org_Code IN('01Y','06H','71E','D2P2L','QF7','Y63','QJM','QOP','Y62','QUA','QUE','Y61','15M','78H','03W','15E','QT1','Y60','QK1','QJ2','QHL','QPM') 
   AND Reporting_Period <'2022-07-01'

--No change data
-- Use this for if Bassetlaw_Indicator = 1
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_O_OAPs_No_Change]
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Master_2]
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

  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Changes_From]
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations] r

INNER JOIN [MHDInternal].[Reference_CDP_Boundary_Population_Changes] c ON r.Org_Code = c.[From]
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

  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Changes_Add]
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Changes_From] r

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

  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Final]
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations] r

INNER JOIN [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Changes_From] c 
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

  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations] r

INNER JOIN [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Changes_Add] c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Reallocated]
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Final]

UNION

SELECT * 
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_No_Change]

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

  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Org_List]
  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] 
 WHERE Effective_To IS NULL 
   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'
   AND Organisation_Name NOT LIKE '%REPORTING ENTITY'

UNION

SELECT DISTINCT 
	   'ICB' as Org_Type,
	   STP_Code as Org_Code,
	   STP_Name as Org_Name,
	   STP_Code as ICB_Code,
	   STP_Name as ICB_Name,
	   Region_Code,
	   Region_Name

  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]
 WHERE Effective_To IS NULL 
   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'

-- Get list of all orgs and indicator combinations
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Org_List_Dates]
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Org_List]
CROSS JOIN (SELECT DISTINCT 
				   Reporting_Period, 
				   CDP_Measure_ID,
				   CDP_Measure_Name,
				   Measure_Type 
			  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Reallocated])_

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

 INTO [MHDInternal].[TEMP_CDP_O_OAPs_Missing_Orgs]

 FROM [MHDInternal].[TEMP_CDP_O_OAPs_Org_List_Dates] d

LEFT JOIN [MHDInternal].[TEMP_CDP_O_OAPs_Reallocated] e 
   ON d.Reporting_Period = e.Reporting_Period
  AND d.CDP_Measure_ID = e.CDP_Measure_ID  
  AND d.Org_Type = e.Org_Type
  AND d.Org_Code = e.Org_Code 
  AND d.Measure_Type = e.Measure_Type 
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [MHDInternal].[TEMP_CDP_O_OAPs_Reallocated]
SELECT * 
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Missing_Orgs]

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
	   ROUND(f.Measure_Value,0) AS Measure_Value,
	   s.[Standard], --CDP_O02 Standards are not included in then [MHDInternal].[Reference_CDP_Standards] table as they are calculated for organistions based on previous EOY measure value SEE STEP 6
	   l.LTP_Trajectory_Rounded AS LTP_Trajectory,
	   NULL AS LTP_Trajectory_Percentage_Achieved, -- Lower is better so not used for OAPs
	   p.[Plan_Rounded] AS [Plan],
	   NULL AS Plan_Percentage_Achieved, -- Lower is better so not used for OAPs
	   CASE WHEN s.Standard_STR IS NULL THEN CAST(NULL AS VARCHAR) ELSE s.Standard_STR END AS Standard_STR,
	    CASE WHEN l.LTP_Trajectory_STR IS NULL THEN CAST(NULL AS VARCHAR) ELSE l.LTP_Trajectory_STR END AS LTP_Trajectory_STR,
	   CASE WHEN p.Plan_STR IS NULL THEN CAST(NULL AS VARCHAR) ELSE p.Plan_STR END AS Plan_STR
	   

  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Measures_&_targets]
  
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Reallocated] f

LEFT JOIN [MHDInternal].[Reference_CDP_LTP_Trajectories] l 
    ON f.Reporting_Period = l.Reporting_Period 
   AND f.Org_Code = l.Org_Code 
   AND (CASE WHEN f.Measure_Type IN ('Percentage','Rate','Count') 
             THEN f.CDP_Measure_ID 
			 ELSE NULL 
		END)= l.CDP_Measure_ID

LEFT JOIN [MHDInternal].[Reference_CDP_Plans] p 
    ON f.Reporting_Period = p.Reporting_Period 
   AND f.Org_Code = p.Org_Code 
   AND (CASE WHEN f.Measure_Type IN ('Percentage','Rate','Count') 
			 THEN f.CDP_Measure_ID 
			 ELSE NULL 
	   END) = p.CDP_Measure_ID

LEFT JOIN [MHDInternal].[Reference_CDP_Standards] s 
    ON f.Reporting_Period = s.Reporting_Period 
   AND (CASE WHEN f.Measure_Type  IN ('Percentage','Rate','Count') 
			 THEN f.CDP_Measure_ID 
			 ELSE NULL 
	   END) = s.CDP_Measure_ID 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

 --Set Is_Latest in current table as 0
UPDATE [MHDInternal].[STAGING_CDP_O_OAPs]
   SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) as Reporting_Period 
  INTO [MHDInternal].[TEMP_CDP_O_OAPs_Is_Latest]
  FROM [MHDInternal].[TEMP_CDP_O_OAPs_Measures_&_targets]


INSERT INTO [MHDInternal].[STAGING_CDP_O_OAPs]
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
	   CAST(NULL as varchar)+'%' as LTP_Trajectory_Percentage_Achieved_STR,
	   Plan_STR,
	   CAST(NULL as varchar)+'%' as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified


  
FROM [MHDInternal].[TEMP_CDP_O_OAPs_Measures_&_targets] f

LEFT JOIN [MHDInternal].[TEMP_CDP_O_OAPs_Is_Latest] i ON f.Reporting_Period = i.Reporting_Period

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 6: Add standards which are calculated rather than using refrence tables
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Create standards table using previous EOY March Measure_Value
SELECT DISTINCT reporting_period,org_code,CDP_MEASURE_ID,MEASURE_TYPE, measure_value [STANDARD], MEASURE_VALUE_STR Standard_str into [MHDInternal].[Temp_oap_standard]
FROM  [MHDInternal].[STAGING_CDP_O_OAPs] 
WHERE reporting_period=@PreviousEOY
AND CDP_MEASURE_ID ='CDP_o02'
AND measure_TYPE='Count'
AND org_type in ('ICB', 'ENGLAND','SUBICB','England','Region')
--Update standard and standard_str
UPDATE [MHDInternal].[STAGING_CDP_O_OAPs] 
SET [standard]=[MHDInternal].[Temp_oap_standard].[STANDARD],
    standard_str=[MHDInternal].[Temp_oap_standard].Standard_str
FROM [MHDInternal].Temp_oap_standard
WHERE [MHDInternal].[STAGING_CDP_O_OAPs].org_code =[MHDInternal].Temp_oap_standard.org_code
AND  [MHDInternal].[STAGING_CDP_O_OAPs].CDP_MEASURE_ID =[MHDInternal].Temp_oap_standard.CDP_MEASURE_ID
AND  [MHDInternal].[STAGING_CDP_O_OAPs].Measure_Type =[MHDInternal].Temp_oap_standard.Measure_Type 
AND [MHDInternal].[STAGING_CDP_O_OAPs].reporting_period>[MHDInternal].Temp_oap_standard.reporting_period
AND [MHDInternal].[STAGING_CDP_O_OAPs].reporting_period=@RPEnd




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 7: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [MHDInternal].[STAGING_CDP_O_OAPs]
 WHERE Region_Code LIKE 'REG%' OR Org_Code IS NULL
	OR (Org_Type = 'SubICB' 
   AND Org_Code NOT IN (SELECT DISTINCT Organisation_Code FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))
    OR (Org_Type = 'ICB' AND Org_Code NOT IN (SELECT DISTINCT STP_Code FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP')) 
	OR (Org_Type = 'Region' AND Org_Code NOT IN (SELECT DISTINCT Region_Code FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

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
		 FROM [MHDInternal].[STAGING_CDP_O_OAPs]
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

  FROM [MHDInternal].[STAGING_CDP_O_OAPs] latest

  LEFT JOIN [MHDInternal].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [MHDInternal].[STAGING_CDP_O_OAPs] previous
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
  FROM [MHDInternal].[STAGING_CDP_O_OAPs]
  WHERE Measure_Value IS NOT NULL


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 8: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--STEP 1: CREATE MASTER TABLE
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Raw]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Master]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Master_2]

--STEP 2: REALLOCATIONS
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_No_Change]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Changes_From]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Changes_Add]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Reallocations_Final]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Reallocated]

--STEP 3: ADD IN MISSING SubICBs & ICBs
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Org_List_Dates]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Org_List]
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Missing_Orgs]

--STEP 4: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Measures_&_targets]


















--STEP 5: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
DROP TABLE [MHDInternal].[TEMP_CDP_O_OAPs_Is_Latest]
---STEP 6: ADD CALCLTATED STANDARDS
DROP TABLE [MHDInternal].Temp_oap_standard


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

--  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_O_OAPs_Future_Months]

--FROM (SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [MHDInternal].[Reference_CDP_Trajectories]
--	   WHERE CDP_Measure_ID IN('CDP_O01') -- ADD MEASURE IDS FOR LTP TRAJECTORY METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets
		 
--	   UNION

--	  SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [MHDInternal].[Reference_CDP_Plans] 
--	   WHERE CDP_Measure_ID IN('CDP_O01') -- ADD MEASURE IDS FOR PLANNING METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets )_

--INSERT INTO [MHDInternal].[STAGING_CDP_O_OAPs]
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

--  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_O_OAPs_Future_Months] f

--LEFT JOIN [MHDInternal].[Reference_CDP_Plans]  p  ON f.[Reporting_Period] = p.[Reporting_Period] AND f.Org_Code = p.Org_Code AND f.[CDP_Measure_ID] = p.[CDP_Measure_ID] AND f.Org_Type = p.Org_Type
--LEFT JOIN [MHDInternal].[Reference_CDP_Trajectories]  l  ON f.[Reporting_Period] = l.[Reporting_Period] AND f.Org_Code = l.Org_Code AND f.[CDP_Measure_ID] = l.[CDP_Measure_ID] AND f.Org_Type = l.Org_Type
--INNER JOIN (SELECT DISTINCT Org_Code, Org_Name, ICB_Code, ICB_Name, Region_Code, Region_Name 
--			  FROM [MHDInternal].[STAGING_CDP_O_OAPs]) s ON f.Org_Code = s.Org_Code-- Used the output table to lookup mapping

--DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_O_OAPs_Future_Months]


--DROP TABLE IF exists [MHDInternal].[TEMP_CDP_O02_STANDARDS]

--SELECT DISTINCT Org_Code, cast(Measure_Value as int)[Standard], 
--						CASE WHEN measure_value_str='*' THEN  '*' ELSE cast(cast(Measure_Value as int) as varchar) end Standard_STR,
--						RANK() OVER (PARTITION BY org_Code ORDER BY Coalesce([standard],0) desc ) AS RN
--						into [MHDInternal].[TEMP_CDP_O02_STANDARDS]
--					  FROM MHDInternal.STAGING_CDP_O_OAPs
--					  WHERE reporting_period='2024-03-31'
--					  and cdp_measure_id='CDP_o02'
--					  and standard_STR is not null

--DROP TABLE IF exists [MHDInternal].[TEMP_CDP_O02_STANDARDS]
