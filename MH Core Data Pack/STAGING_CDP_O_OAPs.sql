/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD

MEASURE NAME(s): OAPs Bed Days (inappropriate only) (CDP_O01)
				 OAPs started in period (inappropriate only) (CDP_O02)

MEASURE DESCRIPTION(s):
				 The total number of days in which patients have been placed out of area due to unavailable beds in their usual network.
				 Total number of inappropriate OAPs started in the period.


BACKGROUND INFO: Publication contains ONS (E) codes. Some codes not currently available in reference tables so are hardcoded, details below.
				 There is one month where the question name wording is slightly different (July 2019)

INPUT:			 [NHSE_UKHF].[Mental_Health].[vw_Out_Of_Area_Placements1]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_STP_Codes]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Provider_Hierarchies]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_Provider_Successor]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards]

TEMP TABLES:	 SEE DROPPED TABLES AT END OF THE SCRIPT.

OUTPUT:			 [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]

WRITTEN BY:		 Jade Sykes 25/5/23

UPDATES:		 [insert description of any updates, insert your name and date]

<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Outline timeframe (Alternatively use FY deletion method for MHSDS metrics sourced from Record Level)

DECLARE @RPEnd AS DATE
DECLARE @RPStart AS DATE

SET @RPEnd = (SELECT MAX(Publication_Period_End) FROM [NHSE_UKHF].[Mental_Health].[vw_Out_Of_Area_Placements1])
SET @RPStart = @RPEnd 

PRINT @RPStart
PRINT @RPEnd

-- Delete any rows which already exist in output table for this time period
DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]
WHERE [Reporting_Period] BETWEEN @RPStart AND @RPEnd

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1: CREATE MASTER TABLE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Provider
SELECT 
	   Publication_Period_End as Reporting_Period,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period')
			THEN 'CDP_O01'
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'CDP_O02'
	   END as CDP_Measure_ID,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period') 
			THEN 'OAPs Bed Days (inappropriate only)' 
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'OAPs started in period (inappropriate only)'
	  END as CDP_Measure_Name,
	  'Provider' as Org_Type,
	  Breakdown1Code as Org_Code,
	  'Count' as Measure_Type,
	  [Value] as Measure_Value

 INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Raw]

 FROM [NHSE_UKHF].[Mental_Health].[vw_Out_Of_Area_Placements1]

WHERE Question IN ('Total number of inappropriate OAP days over the period','Inappropriate OAPs started in period','Inappropriate out of area placements started in period','Total number of inappropriate out of area placement days over the period')
  AND Breakdown1 = 'SendingProvider'
  AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'quarterly'
  AND Breakdown1Code not in ('999','England')

UNION

 --SubICB
SELECT 
	   Publication_Period_End as Reporting_Period,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period')
			THEN 'CDP_O01'
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'CDP_O02'
	   END as CDP_Measure_ID,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period') 
			THEN 'OAPs Bed Days (inappropriate only)' 
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'OAPs started in period (inappropriate only)'
	  END as CDP_Measure_Name,
	  'SubICB' as Org_Type,
	  CASE WHEN o.New_Code IS NULL 
		   THEN Breakdown1Code COLLATE SQL_Latin1_General_CP1_CI_AS 
		   ELSE o.New_Code 
	  END as Org_Code,
	  'Count' as Measure_Type,
	  SUM(Value) as Measure_Value

  FROM [NHSE_UKHF].[Mental_Health].[vw_Out_Of_Area_Placements1] oap

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] o
ON oap.Breakdown1Code = o.Org_Code COLLATE SQL_Latin1_General_CP1_CI_AS

WHERE Question IN ('Total number of inappropriate OAP days over the period','Inappropriate OAPs started in period','Inappropriate out of area placements started in period','Total number of inappropriate out of area placement days over the period')
  AND Breakdown1 IN( 'CCG','Sub-ICB')
  AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'quarterly'
  AND Breakdown1Code NOT IN ('999','England')

GROUP BY 
Publication_Period_End,
CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period')
	 THEN 'CDP_O01'
	 WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
	 THEN 'CDP_O02'
END,
CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period') 
	 THEN 'OAPs Bed Days (inappropriate only)' 
	 WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
	 THEN 'OAPs started in period (inappropriate only)'
END,
CASE WHEN o.New_Code IS NULL 
	 THEN Breakdown1Code COLLATE SQL_Latin1_General_CP1_CI_AS 
	 ELSE o.New_Code 
END

UNION

-- ICB
-- Some ICB codes changed from April 2020. The new codes (ending 50+) are currently not present in the reference table. I've added both versions of the code in the CASE WHEN statement
-- Incase the reference table is updated and old codes are lost.
SELECT 
	   Publication_Period_End as Reporting_Period,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period')
			THEN 'CDP_O01'
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'CDP_O02'
	   END as CDP_Measure_ID,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period') 
			THEN 'OAPs Bed Days (inappropriate only)' 
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'OAPs started in period (inappropriate only)'
	   END as CDP_Measure_Name,
	   'ICB' as Org_Type,
	   CASE WHEN Breakdown1Code IN ('E54000050','e54000049') 
			THEN 'QHM'
			WHEN Breakdown1Code IN ('E54000051','E54000006') 
			THEN 'QOQ'
			WHEN Breakdown1Code IN ('E54000052','E54000035') 
			THEN 'QXU'
			WHEN Breakdown1Code IN ('E54000053','E54000033') 
			THEN 'QNX'
			WHEN Breakdown1Code IN ('E54000054','E54000005') 
			THEN 'QWO'
			ELSE STP_Code_ODS COLLATE SQL_Latin1_General_CP1_CI_AS 
	   END as Org_Code,
	   'Count' as Measure_Type,
	   [Value] as Measure_Value

  FROM [NHSE_UKHF].[Mental_Health].[vw_Out_Of_Area_Placements1]

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_STP_Codes] ON Breakdown1Code = STP_Code_ONS COLLATE SQL_Latin1_General_CP1_CI_AS

WHERE Question IN ('Total number of inappropriate OAP days over the period','Inappropriate OAPs started in period','Inappropriate out of area placements started in period','Total number of inappropriate out of area placement days over the period')
  AND Breakdown1 IN( 'STP','ICB')
  AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'quarterly'
  AND Breakdown1Code NOT IN ('999','England')

UNION

 --Region
SELECT 
	   Publication_Period_End as Reporting_Period,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period')
			THEN 'CDP_O01'
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'CDP_O02'
	   END as CDP_Measure_ID,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period') 
			THEN 'OAPs Bed Days (inappropriate only)' 
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'OAPs started in period (inappropriate only)'
	   END as CDP_Measure_Name,
	   'Region' as Org_Type,
	   Breakdown1Code as Org_Code,
	   'Count' as Measure_Type,
	   [Value] as Measure_Value

  FROM [NHSE_UKHF].[Mental_Health].[vw_Out_Of_Area_Placements1]

WHERE Question IN ('Total number of inappropriate OAP days over the period','Inappropriate OAPs started in period','Inappropriate out of area placements started in period','Total number of inappropriate out of area placement days over the period')
  AND Breakdown1 = 'Region'
  AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'quarterly'
  AND Breakdown1Code NOT IN ('999','England')

UNION 

 --England
SELECT 
	   Publication_Period_End as Reporting_Period,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period')
			THEN 'CDP_O01'
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'CDP_O02'
	   END as CDP_Measure_ID,
	   CASE WHEN Question IN ('Total number of inappropriate OAP days over the period','Total number of inappropriate out of area placement days over the period') 
			THEN 'OAPs Bed Days (inappropriate only)' 
			WHEN Question IN ('Inappropriate OAPs started in period','Inappropriate out of area placements started in period') 
			THEN 'OAPs started in period (inappropriate only)'
	   END as CDP_Measure_Name,
	   'England' as Org_Type,
	   'ENG' as Org_Code,
	   'Count' as Measure_Type,
	   [Value] as Measure_Value

  FROM [NHSE_UKHF].[Mental_Health].[vw_Out_Of_Area_Placements1]

WHERE Question IN ('Total number of inappropriate OAP days over the period','Inappropriate OAPs started in period','Inappropriate out of area placements started in period','Total number of inappropriate out of area placement days over the period')
  AND Breakdown1 = 'England'
  AND Effective_Snapshot_Date BETWEEN @RPStart AND @RPEnd
  AND Report_Period_Length = 'quarterly'

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

  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Master]

  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Raw] m

--Region names
LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name 
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) r 
					    ON Org_Code = r.Region_Code COLLATE database_default

--ICB hierarchies
LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]) i
					    ON Org_Code = i.STP_Code COLLATE database_default

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

  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Master_2]

  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Master]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: REALLOCATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside

-- Reallocations Data
-- Use this for if Bassetlaw_Indicator = 1
SELECT * 
  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations]
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Master_2]

 WHERE Org_Code IN('01Y','06H','71E','D2P2L','QF7','Y63','QJM','QOP','Y62','QUA','QUE','Y61','15M','78H','03W','15E','QT1','Y60','QK1','QJ2','QHL','QPM') 
   AND Reporting_Period <'2022-07-01'

--No change data
-- Use this for if Bassetlaw_Indicator = 1
SELECT * 
  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_No_Change]
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Master_2]
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

  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Changes_From]
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations] r

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

  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Changes_Add]
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Changes_From] r

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

  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Final]
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Changes_From] c 
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

  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Changes_Add] c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocated]
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Final]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_No_Change]

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

  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Org_List]
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
  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Org_List_Dates]
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Org_List]
CROSS JOIN (SELECT DISTINCT 
				   Reporting_Period, 
				   CDP_Measure_ID,
				   CDP_Measure_Name,
				   Measure_Type 
			  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocated])_

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

 INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Missing_Orgs]

 FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Org_List_Dates] d

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocated] e 
   ON d.Reporting_Period = e.Reporting_Period
  AND d.CDP_Measure_ID = e.CDP_Measure_ID  
  AND d.Org_Type = e.Org_Type
  AND d.Org_Code = e.Org_Code 
  AND d.Measure_Type = e.Measure_Type 
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocated]
SELECT * 
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Missing_Orgs]

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
	   s.[Standard],
	   l.LTP_Trajectory_Rounded AS LTP_Trajectory,
	   NULL AS LTP_Trajectory_Percentage_Achieved, -- Lower is better so not used for OAPs
	   p.[Plan_Rounded] AS [Plan],
	   NULL AS Plan_Percentage_Achieved, -- Lower is better so not used for OAPs
	   CASE WHEN s.Standard_STR IS NULL THEN CAST(NULL AS VARCHAR) ELSE s.Standard_STR END AS Standard_STR,
	   CASE WHEN l.LTP_Trajectory_STR IS NULL THEN CAST(NULL AS VARCHAR) ELSE l.LTP_Trajectory_STR END AS LTP_Trajectory_STR,
	   CASE WHEN p.Plan_STR IS NULL THEN CAST(NULL AS VARCHAR) ELSE p.Plan_STR END AS Plan_STR
	   

  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Measures_&_targets]
  
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocated] f

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
STEP 5: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Set Is_Latest in current table as 0
UPDATE [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]
   SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) as Reporting_Period 
  INTO [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Is_Latest]
  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Measures_&_targets]

INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]
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

  FROM [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Measures_&_targets] f

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Is_Latest] i ON f.Reporting_Period = i.Reporting_Period

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 6: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]
 WHERE Region_Code LIKE 'REG%' OR Org_Code IS NULL
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
		 FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]
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

  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs] latest

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs] previous
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
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]
  WHERE Measure_Value IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 7: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--STEP 1: CREATE MASTER TABLE
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Raw]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Master]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Master_2]

--STEP 2: REALLOCATIONS
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_No_Change]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Changes_From]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Changes_Add]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocations_Final]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Reallocated]

--STEP 3: ADD IN MISSING SubICBs & ICBs
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Org_List_Dates]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Org_List]
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Missing_Orgs]

--STEP 4: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Measures_&_targets]

--STEP 5: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[TEMP_CDP_O_OAPs_Is_Latest]

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
--		FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]
--	   WHERE CDP_Measure_ID IN('CDP_O01') -- ADD MEASURE IDS FOR LTP TRAJECTORY METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets
		 
--	   UNION

--	  SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Org_Type, Org_Code, Org_Name, Measure_Type
--		FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] 
--	   WHERE CDP_Measure_ID IN('CDP_O01') -- ADD MEASURE IDS FOR PLANNING METRICS
--	     AND Reporting_Period BETWEEN @RPStartTargets AND @RPEndTargets )_

--INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]
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

--LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]  p  ON f.[Reporting_Period] = p.[Reporting_Period] AND f.Org_Code = p.Org_Code AND f.[CDP_Measure_ID] = p.[CDP_Measure_ID] AND f.Org_Type = p.Org_Type
--LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]  l  ON f.[Reporting_Period] = l.[Reporting_Period] AND f.Org_Code = l.Org_Code AND f.[CDP_Measure_ID] = l.[CDP_Measure_ID] AND f.Org_Type = l.Org_Type
--INNER JOIN (SELECT DISTINCT Org_Code, Org_Name, ICB_Code, ICB_Name, Region_Code, Region_Name 
--			  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]) s ON f.Org_Code = s.Org_Code-- Used the output table to lookup mapping

--DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_O_OAPs_Future_Months]

