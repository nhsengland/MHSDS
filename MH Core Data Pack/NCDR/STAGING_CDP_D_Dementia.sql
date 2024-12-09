/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD

MEASURE NAME:	 Dementia: 65+ Estimated Diagnosis Rate (CDP_D01)

MEASURE DESCRIPTION: 
				 Not everyone with dementia has a formal diagnosis. 
				 The indicator compares the number of people thought to have dementia with the number of people diagnosed with dementia, aged 65 and over. 
				 The target is for at least two thirds of people with dementia to be diagnosed.

BACKGROUND INFO: This metric is published by NHSD.
				 The lowest level of data published is Sub-ICB, data is published at all levels; ICB, Region and England.
				 Data is published for the most recent 12months, therefore there could be revisions to the data in the previous 11 months.
				 However mapping is only uptodate for the most recent month of reporting.

				 In Historic data script:
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

INPUT:			 [NHSE_UKHF].[Primary_Care_Dementia].[vw_Diag_Rate_By_NHS_Org_65Plus1]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]

TEMP:			 SEE DROPPED TABLES AT THE END OF SCRIPT

OUTPUT:			 [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia]

WRITTEN BY:		 Kirsty Walker on 16/05/23

UPDATES:		 [insert description of any updates, insert your name and date]

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

---------------------- Primary_Care_Dementia (New Collection) ---------------------------
DECLARE @ENDRP DATETIME
DECLARE @Month DATETIME
DECLARE @MonthBack INT
DECLARE @STARTRP DATETIME

SET @ENDRP = (SELECT MAX(Effective_Snapshot_Date) FROM [NHSE_UKHF].[Primary_Care_Dementia].[vw_Diag_Rate_By_NHS_Org_65Plus1])
SET @MonthBack = 11 --as 12 months of data is published each month and loaded into the table.

SET @STARTRP = EOMONTH((SELECT DATEADD(mm,-@MonthBack,@ENDRP)))
--SET @STARTRP = 'Oct 31 2022 12:00AM' -- Data from Oct-22 is sourced from the new Primary Care Dementia data source
--CHANGE THIS BACK TO THE OLD STARTRP WHEN WE HAVE 12 MONTH'S OF DATA, SO FOR OCT-23 DATA IN NOV-23.
-- THEN CAN CHANGE TO INSERT TO RATHER THAN DROP TABLES SO JUST ADD NEW MONTHS (IN STEP 4)

-- Delete any rows which already exist in output table for this time period
DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia]
 WHERE Reporting_Period BETWEEN @STARTRP AND @ENDRP

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_SubICB_Num_&_Den]

  FROM [NHSE_UKHF].[Primary_Care_Dementia].[vw_Diag_Rate_By_NHS_Org_65Plus1] d

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

-- We aggregate up from SubICB data to ICB and Region as some SubICBs have merged historically and are accounted for in the SubICB table.

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_ICB_Num_&_Den]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_SubICB_Num_&_Den] d
  
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Region_Num_&_Den]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_SubICB_Num_&_Den] d
  
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_ENG_Num_&_Den]

  FROM [NHSE_UKHF].[Primary_Care_Dementia].[vw_Diag_Rate_By_NHS_Org_65Plus1] d

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Num_&_Den]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_SubICB_Num_&_Den]

UNION

SELECT *
  FROM  [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_ICB_Num_&_Den]

UNION

SELECT *
  FROM  [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Region_Num_&_Den]

UNION

SELECT *
  FROM  [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_ENG_Num_&_Den]

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures]

  FROM (SELECT * 
		  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Num_&_Den]
		 WHERE Measure_Type='Numerator') Num

LEFT JOIN 
	   (SELECT * 
		  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Num_&_Den]
		 WHERE Measure_Type='Denominator') Den 
			ON Num.Reporting_Period = Den.Reporting_Period
		   AND Num.Org_Code = Den.Org_Code

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Num_&_Den]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2 REMAPPING - not required here
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
  
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LOOP IN MISSING ICBs and SubICBs
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Org_List]
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
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Org_List_Dates]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Org_List]
CROSS JOIN (SELECT DISTINCT 
				   Reporting_Period, 
				   CDP_Measure_ID,
				   CDP_Measure_Name,
				   Measure_Type 
			  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures] )_

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

 INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Missing_Orgs]

 FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Org_List_Dates] d

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures] e 
   ON d.Reporting_Period = e.Reporting_Period
  AND d.CDP_Measure_ID = e.CDP_Measure_ID  
  AND d.Org_Type = e.Org_Type
  AND d.Org_Code = e.Org_Code 
  AND d.Measure_Type = e.Measure_Type 
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures] 
SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Missing_Orgs]

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
	   
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures_&_targets]

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures] m

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards] s on m.Reporting_Period = s.Reporting_Period
and m.CDP_Measure_ID = s.CDP_Measure_ID

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] p on m.Reporting_Period = p.Reporting_Period
and m.CDP_Measure_ID = p.CDP_Measure_ID
and m.Org_Code = p.Org_Code

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 4 ADD IN STR VALUES, LAST MODIFIED DATE AND LATEST DATE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Set Is_Latest in current table as 0
UPDATE [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia]
SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) AS Reporting_Period
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Is_Latest] 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures_&_targets]


INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia]

SELECT  
	   m.Reporting_Period,
	   CASE WHEN i.Reporting_Period IS NOT NULL 
	        THEN 1 
	        ELSE 0 
	   END AS Is_Latest,
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

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures_&_targets] m

LEFT JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Is_Latest]  i ON m.Reporting_Period = i.Reporting_Period

-- Check for differences between new month and previous month data (nb this will look high for the YTD measures when April data comes in)
-- The parameters may need to change 

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
		AND (Percentage_Change >= 0.05 OR Percentage_Change IS NULL) THEN '4 High Variation - Volatile Numbers'
		WHEN Percentage_Change >= 0.05 THEN '1 High Variation'
		WHEN Percentage_Change <= 0.01 THEN '5 Low Variation'
		WHEN ((Measure_Type NOT IN ('Percentage','Rate') AND (Latest_Measure_Value < 100 OR Previous_Measure_Value < 100)) OR Previous_Measure_Value_STR = '*' OR Latest_Measure_Value_STR = '*')
		AND (Percentage_Change < 0.05 OR Percentage_Change IS NULL) THEN '6 Moderate Variation - Volatile Numbers'
		WHEN Percentage_Change < 0.05 THEN '3 Moderate Variation'
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

  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia] latest

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia] previous
	  ON latest.CDP_Measure_ID = previous.CDP_Measure_ID 
		  AND CASE WHEN meta.Update_Frequency = 'Monthly' THEN EOMONTH(DATEADD(mm, -1, latest.Reporting_Period ))
		  WHEN meta.Update_Frequency = 'Quarterly' THEN EOMONTH(DATEADD(mm, -3, latest.Reporting_Period )) 
		  WHEN meta.Update_Frequency = 'Annually' THEN EOMONTH(DATEADD(mm, -12, latest.Reporting_Period )) 
		  END = previous.Reporting_Period
		  AND latest.Measure_Type = previous.Measure_Type
		  AND latest.Org_Code = previous.Org_Code 
		  AND latest.Org_Type = previous.Org_Type

WHERE latest.Is_Latest = 1 )_

ORDER BY --QA_Flag, CDP_Measure_Name, Org_Name, Org_Type, 
Percentage_Change DESC

--check table has updated okay
SELECT MAX(Reporting_Period)
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia]
  WHERE Measure_Value IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5 DROP ALL TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR AND DENOMINATOR TABLES
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_SubICB_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_ICB_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Region_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_ENG_Num_&_Den]

--STEP 1B: UNION ALL NUMERATOR AND DENOMINATOR TABLES TOGETHER
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Num_&_Den]

--STEP 1C: WRANGLE THE RAW DATA INTO THE REQUIRED PERCENTAGE TABLES 
--AND UNION PERCENTAGE, NUMERATOR AND DENOMINATOR DATA TOGETHER INTO MEASURES TABLE
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures]

--LOOP IN MISSING ICBs and SubICBs
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Org_List]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Org_List_Dates]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Missing_Orgs]

--STEP 3 ADD TARGETS (STANDARD AND PLAN)
--ROUNDING AND SUPRESSION not required here
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Measures_&_targets]

--STEP 4 ADD IN STR VALUES, LAST MODIFIED DATE AND LATEST DATE
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Is_Latest]


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ADDITIONAL STEP - KEEP COMMENTED OUT UNTIL NEEDED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
-- Adding future months of data for metrics with LTP trajectories/Plans
-- This only needs running once when new months are added to LTP Trajectories/Plans reference tables

--DECLARE @RPEndTargets as DATE
--DECLARE @RPStartTargets as DATE

--SET @RPStartTargets = '2023-09-01'
--SET @RPEndTargets = '2024-03-31'

--PRINT @RPStartTargets
--PRINT @RPEndTargets

--SELECT DISTINCT 
--[Reporting_Period],
--[CDP_Measure_ID],
--[CDP_Measure_Name],
--[Org_Type],
--[Org_Code],
--[Org_Name],
--[Measure_Type]

--INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Future_Months]

--FROM ( 
--SELECT [Reporting_Period],
--[CDP_Measure_ID],
--[CDP_Measure_Name],
--[Org_Type],
--[Org_Code],
--[Org_Name],
--[Measure_Type] 
--FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]
--WHERE CDP_Measure_ID IN('CDP_D01') -- ADD MEASURE IDS
--AND [Reporting_Period] BETWEEN @RPStartTargets AND @RPEndTargets 

--UNION

--SELECT [Reporting_Period],
--[CDP_Measure_ID],
--[CDP_Measure_Name],
--[Org_Type],
--[Org_Code],
--[Org_Name],
--[Measure_Type]
--FROM  [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] 
--WHERE CDP_Measure_ID IN('CDP_D01') -- ADD MEASURE IDS
--AND [Reporting_Period] BETWEEN @RPStartTargets AND @RPEndTargets )_

--INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia]
--SELECT
--f.Reporting_Period,
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

--	FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Future_Months] f
--	LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]  p  ON f.[Reporting_Period] = p.[Reporting_Period] AND f.Org_Code = p.Org_Code AND f.[CDP_Measure_ID] = p.[CDP_Measure_ID] AND f.Org_Type = p.Org_Type
--	LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]  l  ON f.[Reporting_Period] = l.[Reporting_Period] AND f.Org_Code = l.Org_Code AND f.[CDP_Measure_ID] = l.[CDP_Measure_ID] AND f.Org_Type = l.Org_Type
--	INNER JOIN 
--	(SELECT DISTINCT Org_Code, Org_Name, ICB_Code, ICB_Name, Region_Code, Region_Name 
--	FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia]) s ON f.Org_Code = s.Org_Code-- Used the output table to lookup mapping

--	DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_D_Dementia_Future_Months]
