/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD

MEASURE NAME:	 Dementia: 65+ Estimated Diagnosis Rate (CDP_D01)

MEASURE DESCRIPTION: 
				 Not everyone with dementia has a formal diagnosis. 
				 The indicator compares the number of people thought to have dementia with the number of people diagnosed with dementia, aged 65 and over. 
				 The target is for at least two thirds of people with dementia to be diagnosed.

BACKGROUND INFO: This metric is published by NHSD.
				 This is the old collection [NHSE_UKHF].[Rec_Dementia_Diag].[vw_Diag_Rate_By_NHS_Org_65Plus1].

				 The data collection goes back to April 2017 but for the core data pack we only need data back to April 2019.
				 There are old STP Codes in the data from period April 2017 to March 2020, the STP [NHSE_Reference].[dbo].[tbl_Ref_Other_STP_Codes] table converts these old codes into ICB codes.
				 There are a few very old STP Codes (E54000045, E54000046, E54000047) in the data in the period April 2017 to August 2018 that are not however in the [NHSE_Reference].[dbo].[tbl_Ref_Other_STP_Codes] table.
				 This code has not dealt with these 3 missing Ecodes as this data period has not been included in the core data pack but these would need to be dealt with if the data period were to be extended further back.

				 Data is published for the most recent 12months, therefore there could be revisions to the data in the previous 11 months.
				 However mapping is only uptodate for the most recent month of reporting.
				 For example, for Jul-22 data, Aug-21 to Jul-22 data is published in Jul-22 but only Jul-22 reflects the Jul-22 ICB boundary changes.
				 Another example, for Apr-20 data, Mar-19 to Apr-20 data is published in Apr-20 but only Apr-20 reflects the 20/21 Sub-ICB mergers.

				 The last example segways into why data is re-aggregated from Sub-ICB to ICB and Region in this code (rather than pulled directly from publication).
				 In Apr-20 the following Sub-ICBs merged but in doing so changed their ICB look-up.
				 Sub-ICBs 09L (ICB - QNX), 09N (ICB - QXU), 09Y (ICB - QXU) merged to create Sub-ICB 92A (ICB - QXU).
				 As you can see 09L had a different ICB look-up previously (please note you will not be able to see this in the [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] table as it has sadly been overridden).
				 Similarly, 
				 Sub-ICBs 03D (ICB - QHM), 03E (ICB - QWO), 03M (ICB - QOQ) merged to create Sub-ICB 42D (ICB - QOQ).
				 As you can see 03D and 03E have different ICBs look-ups previously (again, you will not be able to see this in the [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] table as it has sadly been overridden).

				 This method of re-aggreagtiong data from Sub-ICB to ICB and Region also resolves the issue where Basstelaw Sub-ICB 02Q moved from ICB QF7 to QT1 in Jul-22.
				 Therefore when doing the re-allocations we apply the Bassetlaw look-up to 0 as we have already reallocated the actual data via this method rather than having to create an estimate.

INPUT:			 [NHSE_UKHF].[Rec_Dementia_Diag].[vw_Diag_Rate_By_NHS_Org_65Plus1]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]


OUTPUT:			 [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Dementia_Historic]

WRITTEN BY:		 Kirsty Walker on 28/06/23

UPDATES:		 KW 03/10/23: Changed Bassetlaw lookup to be set = 0 as aggregating from Sub-ICB will reallocate bassetlaw to the correct location
				 KW 03/10/23: Also discovered that although data is updated in the previous 11 months of the collection, the mappings are not updated. 
							  Therefore, changed the reallocations date from 2021-08-01 to the normal 2022-07-01.

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

---------------------- Recorded Dementia Diagnosis (Old Collection) ---------------------------
DECLARE @ENDRP DATETIME
DECLARE @STARTRP DATETIME

SET @STARTRP = '2019-04-30' --we only need data back to Apr-19 for core data pack

SET @ENDRP = (SELECT MAX(Effective_Snapshot_Date)
FROM [NHSE_UKHF].[Rec_Dementia_Diag].[vw_Diag_Rate_By_NHS_Org_65Plus1])

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR AND DENOMINATOR TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

---------- SubICB Numerator and Denominator --------

SELECT 
       d.Effective_Snapshot_Date as Reporting_Period,
	   'CDP_D01' as CDP_Measure_ID,
	   'Dementia: 65+ Estimated Diagnosis Rate' as CDP_Measure_Name,
	   'SubICB' as Org_Type,
	   COALESCE(cc.New_Code,d.Org_Code,'Missing / Invalid' COLLATE database_default) as Org_Code,
	   ch.Organisation_Name as Org_Name, --this was under the [ICB Name - CCG Code] naming convention in the NCDR table but in the [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] table in UDAL this will become the SUB LOCATION name.
	   ch.STP_Code as ICB_Code,
	   ch.STP_Name as ICB_Name,
	   ch.Region_Code,
	   ch.Region_Name,
	   CASE WHEN d.Measure='DEMENTIA_REGISTER_65_PLUS'
	        THEN 'Numerator' 
			WHEN d.Measure='DEMENTIA_ESTIMATE_65_PLUS'
			THEN 'Denominator'
	   END as Measure_Type,
	   SUM(d.Measure_Value) as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_SubICB_Num_&_Den]

  FROM [NHSE_UKHF].[Rec_Dementia_Diag].[vw_Diag_Rate_By_NHS_Org_65Plus1] d

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON d.Org_Code = cc.Org_Code COLLATE database_default
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code,d.Org_Code) = ch.Organisation_Code COLLATE database_default

 WHERE d.Effective_Snapshot_Date between @STARTRP and @ENDRP
   and d.Org_Type  in ('SUB_ICB_LOC', 'CCG') -- to filter for SubICB locations
   and d.Measure in ('DEMENTIA_REGISTER_65_PLUS','DEMENTIA_ESTIMATE_65_PLUS')  --to filter for numerator

 GROUP BY
d.Measure,
d.Effective_Snapshot_Date,
COALESCE(cc.New_Code,d.Org_Code,'Missing / Invalid' COLLATE database_default),
ch.Organisation_Name,
ch.STP_Code,
ch.STP_Name,
ch.Region_Code,
ch.Region_Name

---------- ICB Numerator and Denominator --------

SELECT 
       d.Reporting_Period,
	   d.CDP_Measure_ID,
	   d.CDP_Measure_Name,
	   'ICB' as Org_Type,
	   d.ICB_Code as Org_Code,
	   d.ICB_Name as Org_Name, 
	   d.ICB_Code,
	   d.ICB_Name,
	   d.Region_Code,
	   d.Region_Name,
	   d.Measure_Type,
	   SUM(d.Measure_Value) as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_ICB_Num_&_Den]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_SubICB_Num_&_Den] d
  
 GROUP BY
d.Reporting_Period,
d.CDP_Measure_ID,
d.CDP_Measure_Name,
d.ICB_Code,
d.ICB_Name, 
d.ICB_Code,
d.ICB_Name,
d.Region_Code,
d.Region_Name,
d.Measure_Type

---------- Region Numerator and Denominator --------

SELECT 
       d.Reporting_Period,
	   d.CDP_Measure_ID,
	   d.CDP_Measure_Name,
	   'Region' as Org_Type,
	   d.Region_Code as Org_Code,
	   d.Region_Name as Org_Name, 
	   'NA' as ICB_Code,
	   'NA' as ICB_Name,
	   d.Region_Code,
	   d.Region_Name,
	   d.Measure_Type,
	   SUM(d.Measure_Value) as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Region_Num_&_Den]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_SubICB_Num_&_Den] d
  
 GROUP BY
d.Reporting_Period,
d.CDP_Measure_ID,
d.CDP_Measure_Name,
d.Region_Code,
d.Region_Name,
d.Measure_Type

---------- England Numerator and Denominator --------

SELECT 
       d.Effective_Snapshot_Date as Reporting_Period,
	   'CDP_D01' as CDP_Measure_ID,
	   'Dementia: 65+ Estimated Diagnosis Rate' as CDP_Measure_Name,
	   'England' as Org_Type,
	   'ENG' as Org_Code,
	   'England' as Org_Name,
	   'NA' as ICB_Code,
	   'NA' as ICB_Name,
	   'NA' as Region_Code,
	   'NA' as Region_Name,
	   CASE WHEN d.Measure='DEMENTIA_REGISTER_65_PLUS'
	        THEN 'Numerator' 
			WHEN d.Measure='DEMENTIA_ESTIMATE_65_PLUS'
			THEN 'Denominator'
	   END as Measure_Type,
	   SUM(d.Measure_Value) as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_ENG_Num_&_Den]

  FROM [NHSE_UKHF].[Rec_Dementia_Diag].[vw_Diag_Rate_By_NHS_Org_65Plus1] d

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON d.Org_Code = cc.Org_Code COLLATE database_default
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code,d.Org_Code) = ch.Organisation_Code COLLATE database_default

 WHERE d.Effective_Snapshot_Date between @STARTRP and @ENDRP
   and d.Org_Type='COUNTRY_RESPONSIBILITY' -- to filter for England data
   and d.Measure in ('DEMENTIA_REGISTER_65_PLUS','DEMENTIA_ESTIMATE_65_PLUS')  --to filter for numerator

 GROUP BY
d.Measure,
d.Effective_Snapshot_Date

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1B: UNION ALL NUMERATOR AND DENOMINATOR TABLES TOGETHER
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT *

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Num_&_Den]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_SubICB_Num_&_Den]

UNION

SELECT *
  FROM  [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_ICB_Num_&_Den]

UNION

SELECT *
  FROM  [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Region_Num_&_Den]

UNION

SELECT *
  FROM  [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_ENG_Num_&_Den]

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
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Num_&_Den]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Num_&_Den]

 WHERE Org_Code IN (SELECT Orgs FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
   AND Reporting_Period <'2022-07-01'

--No change data
-- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location) 
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_No_Change_Num_&_Den]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Num_&_Den]
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Changes_From_Num_&_Den]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Num_&_Den] r

INNER JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes] c ON r.Org_Code = c.[From]
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Changes_Add_Num_&_Den]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Changes_From_Num_&_Den] r

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Num_&_Den_Calc]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Num_&_Den] r

INNER JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Changes_From_Num_&_Den] c 
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

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Num_&_Den] r

INNER JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Changes_Add_Num_&_Den] c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new Reallocated table
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated_Num_&_Den]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Num_&_Den_Calc]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_No_Change_Num_&_Den]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1C: WRANGLE THE RAW DATA INTO THE REQUIRED PERCENTAGE TABLES 
AND UNION PERCENTAGE, NUMERATOR AND DENOMINATOR DATA TOGETHER INTO MEASURES TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT 
       Num.Reporting_Period,
	   Num.CDP_Measure_ID,
	   Num.CDP_Measure_Name,
	   Num.Org_Type,
	   Num.Org_Code,
	   Num.Org_Name,
       Num.ICB_Code,
	   Num.ICB_Name,
	   Num.Region_Code,
	   Num.Region_Name,
	   'Percentage' as Measure_Type,
	   Num.Measure_Value/Den.Measure_Value as Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated_%]

  FROM (SELECT * 
		  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated_Num_&_Den]
		 WHERE Measure_Type='Numerator') Num

LEFT JOIN 
	   (SELECT * 
		  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated_Num_&_Den]
		 WHERE Measure_Type='Denominator') Den 
			ON Num.Reporting_Period = Den.Reporting_Period
		   AND Num.Org_Code = Den.Org_Code
-- Collate Percentage calcs with rest of data
SELECT * 

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated_Num_&_Den]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated_%]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: ADD IN MISSING SubICBs & ICBs
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Org_List]
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
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Org_List_Dates]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Org_List]
CROSS JOIN (SELECT DISTINCT 
				   Reporting_Period, 
				   CDP_Measure_ID,
				   CDP_Measure_Name,
				   Measure_Type 
			  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated])_

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

 INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Missing_Orgs]

 FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Org_List_Dates] d

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated] e 
   ON d.Reporting_Period = e.Reporting_Period
  AND d.CDP_Measure_ID = e.CDP_Measure_ID  
  AND d.Org_Type = e.Org_Type
  AND d.Org_Code = e.Org_Code 
  AND d.Measure_Type = e.Measure_Type 
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated] 
SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Missing_Orgs]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 3 ADD TARGETS (STANDARD AND PLAN)
ROUNDING AND SUPRESSION not required here
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT  
	   m.Reporting_Period,
       m.CDP_Measure_ID,
       m.CDP_Measure_Name,
       m.Org_Type,
       m.Org_Code,
       m.Org_Name,
       m.ICB_Code,
       m.ICB_Name,
       m.Region_Code,
       m.Region_Name,
       m.Measure_Type,
       m.Measure_Value,
	   s.[Standard],
	   p.[Plan],
	   CAST(NULL as float) as Plan_Percentage_Achieved,
	   s.Standard_STR,
	   p.Plan_STR
	   
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Measures_&_targets]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated] m

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards] s on m.Reporting_Period = s.Reporting_Period
and m.CDP_Measure_ID = s.CDP_Measure_ID

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] p on m.Reporting_Period = p.Reporting_Period
and m.CDP_Measure_ID = p.CDP_Measure_ID
and m.Org_Code = p.Org_Code

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 4 ADD IN STR VALUES AND LAST MODIFIED DATE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
--NOT NEEDED FOR HISTORIC DATA SCRIPTS
---- Set Is_Latest in current table as 0
--UPDATE [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Dementia_Historic]
--SET Is_Latest = 0

----Determine latest month of data for is_Latest
--SELECT MAX(Reporting_Period) AS Reporting_Period
--  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Is_Latest] 
--  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Measures_&_targets]

SELECT  
	   m.Reporting_Period,
	  --NOT NEEDED FOR HISTORIC DATA SCRIPTS
	  -- CASE WHEN i.Reporting_Period IS NOT NULL 
			--THEN 1 
			--ELSE 0 
	  -- END AS Is_Latest,
	   0 as Is_Latest,
       m.CDP_Measure_ID,
       m.CDP_Measure_Name,
       m.Org_Type,
       m.Org_Code,
       m.Org_Name,
       m.ICB_Code,
       m.ICB_Name,
       m.Region_Code,
       m.Region_Name,
       m.Measure_Type,
       m.Measure_Value,
	   m.[Standard],
	   CAST(NULL as float) as LTP_Trajectory,
	   CAST(NULL as float) as LTP_Trajectory_Percentage_Achieved,
	   m.[Plan],
	   m.Plan_Percentage_Achieved,
	   CASE WHEN m.Measure_Type ='Numerator'
	        THEN FORMAT(m.[Measure_Value],N'N0') 
			WHEN m.Measure_Type ='Denominator'
	        THEN FORMAT(m.[Measure_Value],N'N1') 
		    WHEN m.Measure_Type='Percentage'
	        THEN FORMAT(m.Measure_Value,'P1')
	        ELSE FORMAT(m.[Measure_Value],N'N0') 
	   END as Measure_Value_STR,
	   m.Standard_STR,
	   CAST(NULL as varchar) as LTP_Trajectory_STR,
	   CAST(NULL as varchar) as LTP_Trajectory_Percentage_Achieved_STR,
	   m.Plan_STR,
	   CAST(NULL as varchar) as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified
	   
  INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Dementia_Historic]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Measures_&_targets] m
--LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Is_Latest] i ON m.Reporting_Period = i.Reporting_Period

--select *
--from [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Dementia_Historic]
--where Measure_Type  in ('Numerator', 'Denominator')

--select *
--from [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Dementia_Historic]
--where Measure_Type='Percentage'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5 DROP ALL TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
--STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR AND DENOMINATOR TABLES
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_SubICB_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_ICB_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Region_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_ENG_Num_&_Den]

--STEP 1B: UNION ALL NUMERATOR AND DENOMINATOR TABLES TOGETHER
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Num_&_Den]

--STEP 2: REALLOCATIONS
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_No_Change_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Changes_From_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Changes_Add_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocations_Num_&_Den_Calc]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated_%]

--STEP 1C: WRANGLE THE RAW DATA INTO THE REQUIRED PERCENTAGE TABLES AND UNION PERCENTAGE, NUMERATOR AND DENOMINATOR DATA TOGETHER INTO MEASURES TABLE
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Reallocated]

--STPE 2: ADD IN MISSING SubICBs & ICBs
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Org_List]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Org_List_Dates]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Missing_Orgs]

--STEP 3 ADD TARGETS (STANDARD AND PLAN) ROUNDING AND SUPRESSION not required here
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Dementia_Historic_Measures_&_targets]

--STEP 4 ADD IN STR VALUES AND LAST MODIFIED DATE
--DROP TABLE [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Dementia_Historic]
