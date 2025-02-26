/*****************************************************************************************************************************************************************************************************************************
CODE FOR CORE DATA PACK DASHBOARD

MEASURE NAME: MHSDS 72hr Follow-Up
			MHSDS CMH 2+ Contacts 
			MHSDS EIP 2 Week Waits
			MHSDS Inpatient No Contact
			MHSDS Perinatal Access (Rolling 12 month)
			MHSDS LoS - Adult Acute 60 days
			MHSDS LoS - Older Adults 90 days
			MHSDS CYP ED Urgent (interim)
			MHSDS CYP ED Routine (interim)
			MHSDS Very Urgent Referrals to CCS (contacts w/in 4hrs - %)
			MHSDS Urgent Referrals to CCS (contacts w/in 24hrs - %)
			MHSDS Referrals to LPS from A&E (contacts w/in 1hr - %)
			MHSDS CYP Self-Rated Measurable Improvement (%)
			MHSDS CYP Paired Scores (%)

BACKGROUND INFO: To add and remove metrics, please insert/remove information from MHDInternal.TEMP_CDP_M_MHSDS_Metric_Info (Top of script) following the format below. 
			No further amendments to the script should be necessary.

			Note, for percentages/ rates, please add ONLY the numerator and denominator information. Should there be multiple metrics which are summed for a single numerator/denominator, please add each as it's own line.
			If data is only available at sub-ICB (no ICB/region published) and therefore requires aggregating to ICB & region, please set Aggregation_Required = 'Y' Else 'N' e.g.
				('CDP_M05','MHS106a','MHSDS Inpatient No Contact','Denominator','Y')
				('CDP_M05','MHS106b','MHSDS Inpatient No Contact','Denominator','Y')

			The script will add the latest month of data into the output table.For the end of year refresh, please delete the data being refreshed and manually update the variables to determine which data period to run. 
		

INPUT:  NHSE_Sandbox_MentalHealth.dbo.Staging_UnsuppressedMHSDSPublicationFiles
		NHSE_Sandbox_Policy.dbo.REFERENCE_CDP_Population_Data
        NHSE_Sandbox_Policy.dbo.REFERENCE_CDP_Boundary_Population_Changes
		NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies
		NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies
		NHSE_Sandbox_Policy.dbo.REFERENCE_MHSDS_Submission_Tracker

OUTPUT: NHSE_Sandbox_Policy.dbo.STAGING_CDP_M_MHSDS_Published 

WRITTEN BY: JADE SYKES    10/10/2023

UPDATES:    JADE SYKES    07/12/2023 Change @RPEnd to remove "WHERE STATUS <> 'Provisional'" FOR DEC-23 CHANGE TO SINGLE SUBMISSION WINDOW 
								     (THERE USE TO BE A PROVISIONAL DATA WINDOW BUT NOW WE JUST PULL OUT MAX REPORTING_PERIOD)
			KIRSTY WALKER 15/12/2023 Commented out the mapping to MPL as was causing double counting in output, the joins need to be done in a slightly different way, happy to talk thru :)

			LOUISE SHUTTLEWORTH 21/06/24 Added in the two LOS measures to the script (MHS140a and MHS141a)    

			MW 16/01/2025 Added RI (MHS96) and IPS (MHS116) metrics

***********************************************************************************************************************************************************************************************************************************/

/* PRE-STEPS - METRIC LIST */

CREATE TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Metric_Info] (CDP_Measure_ID VARCHAR(20), Published_Measure_ID VARCHAR(20), CDP_Measure_Name VARCHAR(150),Measure_Type VARCHAR(50),Aggregation_Required VARCHAR(5))

INSERT INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Metric_Info]
VALUES 
	 ('CDP_M01','MHS79','MHSDS 72hr Follow-Up','Numerator','Y')
	,('CDP_M01','MHS78','MHSDS 72hr Follow-Up','Denominator','Y')
	,('CDP_M02','MHS108','MHSDS CMH 2+ Contacts','Count','N')
	,('CDP_M03','MHS95','MHSDS CYP 1+ Contacts','Count','N')
	,('CDP_M04','EIP23b','MHSDS EIP 2 Week Waits','Numerator','Y')
	,('CDP_M04','EIP23a','MHSDS EIP 2 Week Waits','Denominator','Y')
	,('CDP_M05','MHS106b','MHSDS Inpatient No Contact','Numerator','Y')
	,('CDP_M05','MHS106a','MHSDS Inpatient No Contact','Denominator','Y')
	,('CDP_M05','MHS106b','MHSDS Inpatient No Contact','Denominator','Y')
	,('CDP_M06','MHS91','MHSDS Perinatal Access (Rolling 12 month)','Count','N')
	,('CDP_M07','MHS100','MHSDS LoS - Adult Acute 60 days','Numerator','Y')
	,('CDP_M07',NULL,'MHSDS LoS - Adult Acute 60 days','Denominator','Y')
	,('CDP_M08','MHS103','MHSDS LoS - Older Adults 90 days','Numerator','Y')
	,('CDP_M08',NULL,'MHSDS LoS - Older Adults 90 days','Denominator','Y')
	,('CDP_M09','ED86a','MHSDS CYP ED Urgent (interim)','Numerator','Y')
	,('CDP_M09','ED86','MHSDS CYP ED Urgent (interim)','Denominator','Y')
	,('CDP_M10','ED87a','MHSDS CYP ED Routine (interim)','Numerator','Y')
	,('CDP_M10','ED87b','MHSDS CYP ED Routine (interim)','Numerator','Y')
	,('CDP_M10','ED87','MHSDS CYP ED Routine (interim)','Denominator','Y')
	,('CDP_M11','CCR119','MHSDS Very Urgent Referrals to CCS (contacts w/in 4hrs - %)','Numerator','Y')
	,('CDP_M11','CCR118','MHSDS Very Urgent Referrals to CCS (contacts w/in 4hrs - %)','Denominator','Y')
	,('CDP_M12','CCR120','MHSDS Urgent Referrals to CCS (contacts w/in 24hrs - %)','Numerator','Y')
	,('CDP_M12','CCR73','MHSDS Urgent Referrals to CCS (contacts w/in 24hrs - %)','Denominator','Y')
	,('CDP_M13','PLS123','MHSDS Referrals to LPS from A&E (contacts w/in 1hr - %)','Numerator','Y')
	,('CDP_M13','PLS122','MHSDS Referrals to LPS from A&E (contacts w/in 1hr - %)','Denominator','Y')
	,('CDP_M14','MHS113a','MHSDS CYP Self-Rated Measurable Improvement (%)','Numerator','N')
	,('CDP_M14','MHS112b','MHSDS CYP Self-Rated Measurable Improvement (%)','Denominator','N')
	,('CDP_M15','MHS112','MHSDS CYP Paired Scores (%)','Numerator','N')
	,('CDP_M15','MHS110','MHSDS CYP Paired Scores (%)','Denominator','N')
	,('CDP_M16','MHS140a','MHSDS LoS - Mean LoS for Adult Acute discharges','Mean','N') --try doing as a mean?
	,('CDP_M17','MHS141a','MHSDS LoS - Mean LoS for Older Adult Acute discharges','Mean','N') --try doing as a mean?
	--NEW IPS MEASURE
	,('CDP_M19','MHS116','MHSDS Individual Placement and Support (IPS)','Numerator','Y')
	--NEW RI MEASURE
	,('CDP_M18','MHS96','MHSDS Restrictive Interventions per 1,000 bed days','Numerator','N') --# RI types


/* PRE-STEPS - DATES */

DECLARE @RPEnd AS DATE
DECLARE @RPStart AS DATE

SET @RPEnd = (SELECT MAX(REPORTING_PERIOD_END) FROM [MHDInternal].[STAGING_MH_UnsuppressedMHSDSPublicationFiles])-- These can be manually changed when refreshing for end of financial year refresh
--SET @RPStart = @RPEnd -- This can be manually changed when refreshing for end of financial year refresh '2022-04-01' 
SET @RPStart = '2020-06-30'

PRINT @RPStart
PRINT @RPEnd

-- Delete any rows which already exist in output table for this time period
DELETE FROM [MHDInternal].[STAGING_CDP_M_MHSDS_Published]      --UDAL_Changes
 WHERE Reporting_Period BETWEEN @RPStart AND @RPEnd

-- Get distinct Reporting periods to use with population data for LOS
SELECT DISTINCT REPORTING_PERIOD_END as Reporting_period 
  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Population_Dates]
  FROM [MHDInternal].[STAGING_MH_UnsuppressedMHSDSPublicationFiles] 
 WHERE REPORTING_PERIOD_END BETWEEN @RPStart AND @RPEnd


/* STEP 1: CREATE MASTER TABLE */

-- Select distinct rows from source (in case of duplicate rows)
SELECT DISTINCT 
	   REPORTING_PERIOD_START,
	   REPORTING_PERIOD_END,
	   [STATUS],
	   BREAKDOWN,
	   PRIMARY_LEVEL,
	   PRIMARY_LEVEL_DESCRIPTION,
	   SECONDARY_LEVEL,
	   SECONDARY_LEVEL_DESCRIPTION,
	   MEASURE_ID,
	   MEASURE_VALUE
 INTO [MHDInternal].[TEMP_CDP_M_MHSDS_RAW]
 FROM [MHDInternal].[STAGING_MH_UnsuppressedMHSDSPublicationFiles]

WHERE REPORTING_PERIOD_END BETWEEN @RPStart AND @RPEnd
  AND BREAKDOWN IN ('England'
  ,'Provider of Responsibility','Provider'
  ,'CCG - GP Practice or Residence','Sub ICB - GP Practice or Residence', 'Sub ICB of Residence', 'CCG of Residence','CCG - Residence','Sub ICB of GP Practice or Residence','CCG'
  ,'ICB','ICB of Residence','ICB of GP Practice or Residence','STP','ICB - GP Practice or Residence'
  ,'Commissioning Region','Region'
  )  


SELECT 
	   CAST(REPORTING_PERIOD_END AS DATE) AS 'Reporting_Period',
	   i.CDP_Measure_ID AS 'CDP_Measure_ID',
	   i.CDP_Measure_Name AS 'CDP_Measure_Name',
	   CASE WHEN BREAKDOWN IN ('CCG - GP Practice or Residence','Sub ICB - GP Practice or Residence', 'Sub ICB of Residence', 'CCG of Residence','CCG - Residence','Sub ICB of GP Practice or Residence','CCG') THEN 'SubICB'
			WHEN BREAKDOWN IN ('ICB','ICB of Residence','ICB of GP Practice or Residence','STP','ICB - GP Practice or Residence') THEN 'ICB'
			WHEN BREAKDOWN IN ('Commissioning Region','Region') THEN 'Region'
			WHEN BREAKDOWN IN ('Provider of Responsibility','Provider') THEN 'Provider'
			ELSE BREAKDOWN 
	   END AS 'Org_Type',
	   CASE WHEN BREAKDOWN = 'England' THEN 'ENG' 
			ELSE PRIMARY_LEVEL 
	   END AS 'Org_Code',
	   i.Measure_Type,
	   SUM(p.MEASURE_VALUE) AS 'Measure_Value' -- needs to be a sum for indicators which have multiple metrics which make up a num/den

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Master]

  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_RAW] p

INNER JOIN MHDInternal.TEMP_CDP_M_MHSDS_Metric_Info i ON p.MEASURE_ID = i.Published_Measure_ID

WHERE p.MEASURE_ID NOT IN ('MHS140a','MHS141a') --Exclude the average LOS measures - these get additional suppression applied in the next step, based upon their numerator values

GROUP BY 
CAST(REPORTING_PERIOD_END AS DATE),
i.CDP_Measure_ID,
i.CDP_Measure_Name,
CASE WHEN BREAKDOWN IN ('CCG - GP Practice or Residence','Sub ICB - GP Practice or Residence', 'Sub ICB of Residence', 'CCG of Residence','CCG - Residence','Sub ICB of GP Practice or Residence','CCG') THEN 'SubICB'
WHEN BREAKDOWN IN ('ICB','ICB of Residence','ICB of GP Practice or Residence','STP','ICB - GP Practice or Residence') THEN 'ICB'
WHEN BREAKDOWN IN ('Commissioning Region','Region') THEN 'Region'
WHEN BREAKDOWN IN ('Provider of Responsibility','Provider') THEN 'Provider'
ELSE BREAKDOWN END,
CASE WHEN BREAKDOWN = 'England' THEN 'ENG' ELSE PRIMARY_LEVEL END,
i.Measure_Type

UNION 

-- Attribute population data to reporting periods for LOS Denominators
SELECT *
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Population_Dates]
CROSS JOIN [MHDInternal].[Reference_CDP_Population_Data]


/***************************************************************************************************************************************************************************
START OF LOS SECTION  - BRING THROUGH THE TWO AVERAGE LOS MEASURES (MHS140a AND MHS141a) AND APPLY ADDITIONAL SUPPRESSION BASED ON THEIR NUMERATOR VALUES (MHS140 AND MHS141)
***************************************************************************************************************************************************************************/ 
--1) Get the four LOS measures from the Unsuppressed data file - and where the relevant numerator count is < 5, then suppress the average LOS measure
SELECT 
	Reporting_Period,
	Org_Type,
	Org_Code,
	CASE WHEN [MHS140] < 5 THEN 0 ELSE [MHS140a] END AS [MHS140a] ,
	CASE WHEN [MHS141] < 5 THEN 0 ELSE [MHS141a] END AS [MHS141a] 

INTO [MHDInternal].[TEMP_CDP_M_MHSDS_LOS_Staging]
FROM

	(
	SELECT 
		CAST(REPORTING_PERIOD_END AS DATE) AS 'Reporting_Period',
		MEASURE_ID, 
		 CASE WHEN BREAKDOWN IN ('CCG - GP Practice or Residence','Sub ICB - GP Practice or Residence', 'Sub ICB of Residence', 'CCG of Residence','CCG - Residence','Sub ICB of GP Practice or Residence','CCG') THEN 'SubICB'
				WHEN BREAKDOWN IN ('ICB','ICB of Residence','ICB of GP Practice or Residence','STP','ICB - GP Practice or Residence') THEN 'ICB'
				WHEN BREAKDOWN IN ('Commissioning Region','Region') THEN 'Region'
				WHEN BREAKDOWN IN ('Provider of Responsibility','Provider') THEN 'Provider'
				ELSE BREAKDOWN 
		   END AS 'Org_Type',
		   CASE WHEN BREAKDOWN = 'England' THEN 'ENG' 
				ELSE PRIMARY_LEVEL 
		   END AS 'Org_Code',
		Measure_Value
	FROM [MHDInternal].[TEMP_CDP_M_MHSDS_RAW] WHERE MEASURE_ID IN ('MHS140','MHS140a','MHS141','MHS141a')
	) AS SourceTable
PIVOT
	(
	SUM(Measure_Value) 
	FOR MEASURE_ID IN ([MHS140],[MHS140a],[MHS141],[MHS141a])
	)
AS PivotTable;

--2) Unpivot the now-suppressed average LOS measures
SELECT 
	Reporting_Period,
	Org_Type,
	Org_Code,
	Measure_ID,
	Measure_Value

INTO [MHDInternal].[TEMP_CDP_M_MHSDS_LOS_Staging_2]

FROM 

(SELECT Reporting_Period, Org_Type, Org_Code, MHS140a, MHS141a
FROM  [MHDInternal].[TEMP_CDP_M_MHSDS_LOS_Staging]) AS s

UNPIVOT
	(
		Measure_Value FOR Measure_ID IN (MHS140a, MHs141a) 
	) AS Unpivoted


--3) Insert the unpivoted, suppressed average LOS measures into the [MHDInternal].[TEMP_CDP_M_MHSDS_Master] table

INSERT INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Master]

SELECT
	s.Reporting_Period, 
	i.CDP_Measure_ID,
	i.CDP_Measure_Name,
	s.Org_Type,
	s.Org_Code,
	i.Measure_Type,
	s.Measure_Value

FROM [MHDInternal].[TEMP_CDP_M_MHSDS_LOS_Staging_2] s

INNER JOIN MHDInternal.TEMP_CDP_M_MHSDS_Metric_Info i ON s.MEASURE_ID = i.Published_Measure_ID

/***************************************************************************************************************************************************************************
END OF LOS SECTION  - CODE AS IT WAS
***************************************************************************************************************************************************************************/ 


-- Remove provider level LOS data, inpatient no contact, CYP outcomes  metrics
DELETE FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master]
 WHERE Org_Type = 'Provider' 
   AND CDP_Measure_ID IN ('CDP_M07','CDP_M08','CDP_M05','CDP_M14','CDP_M15')

-- remove CYP ED (interim) data for pre Apr-23
DELETE FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master]
 WHERE CDP_Measure_Name IN ('MHSDS CYP ED Urgent (interim)','MHSDS CYP ED Routine (interim)') 
   AND Reporting_Period < '2023-04-01'



-- Code for pulling org names from reference tables
SELECT 
	   m.Reporting_Period,
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
			WHEN Org_Type = 'Provider' THEN  COALESCE(ph.Organisation_Name, st.Organisation_Name)
			ELSE ch.Organisation_Name 
	   END as Org_Name,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Code
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.STP_Code,st.ICB_Code)
			ELSE ch.STP_Code 
	   END as ICB_Code,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Name
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.STP_Name,chst1.STP_Code)
			ELSE ch.STP_Name 
	   END as ICB_Name,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN r.Region_Code
			WHEN Org_Type in ('ICB','STP') THEN i.Region_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Code
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.Region_Code, st.Region_Code)
			ELSE ch.Region_Code
	   END as Region_Code,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN r.Region_Name
			WHEN Org_Type in ('ICB', 'STP') THEN i.Region_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Name
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.Region_Name,chst2.Region_Name)
			ELSE ch.Region_Name
	   END as Region_Name,
	   Measure_Type,
	   SUM(Measure_Value) AS Measure_Value

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Master_2]

  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master] m

--Region names
LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name 
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]) r 
					    ON Org_Code = r.Region_Code

--ICB hierarchies
LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]) i
					    ON Org_Code = i.STP_Code

--SubICB hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON m.Org_Code = cc.Org_Code COLLATE database_default
LEFT JOIN [Reporting_UKHD_ODS].[Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code, m.Org_Code) = ch.Organisation_Code COLLATE database_default

--Provider hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table. Using Submission Tracker where no information in ODS table
LEFT JOIN [Internal_Reference].[Provider_Successor] ps on m.Org_Code = ps.Prov_original COLLATE database_default
LEFT JOIN [Reporting_UKHD_ODS].[Provider_Hierarchies] ph ON COALESCE(ps.Prov_Successor, m.Org_Code) = ph.Organisation_Code COLLATE database_default
LEFT JOIN (SELECT DISTINCT Org_Code, Organisation_Name, ICB_Code, Region_Code, Reporting_Period FROM [MHDInternal].[Reference_MHSDS_Submission_Tracker]) st on m.Org_Code = st.Org_Code and m.Reporting_Period=st.Reporting_Period
	LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]) chst1 ON st.ICB_Code = chst1.STP_Code -- GET ICB NAME FROM ODS FOR CONSISTENCY FOR MLP
	LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]) chst2 ON st.Region_Code = chst2.Region_Code -- GET REG NAME FROM ODS FOR CONSISTENCY FOR MPL

GROUP BY m.Reporting_Period,
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
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.Organisation_Name, st.Organisation_Name)
			ELSE ch.Organisation_Name 
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Code
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.STP_Code,st.ICB_Code)
			ELSE ch.STP_Code 
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Name
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.STP_Name,chst1.STP_Code)
			ELSE ch.STP_Name 
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN r.Region_Code
			WHEN Org_Type in ('ICB','STP') THEN i.Region_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Code
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.Region_Code, st.Region_Code)
			ELSE ch.Region_Code
	   END,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN r.Region_Name
			WHEN Org_Type in ('ICB', 'STP') THEN i.Region_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Name
			WHEN Org_Type = 'Provider' THEN COALESCE(ph.Region_Name,chst2.Region_Name)
			ELSE ch.Region_Name
	   END,
	   Measure_Type



-- Aggregate measures to ICB and Regional level where Aggregation_Required = 'Y'

-- England, Provider & SubICB
SELECT m.* 
  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Aggregation]
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master_2] m
  INNER JOIN [MHDInternal].[TEMP_CDP_M_MHSDS_Metric_Info] i ON m.CDP_Measure_ID = i.CDP_Measure_ID
 WHERE Aggregation_Required = 'Y' AND Org_Type IN('Provider','SubICB','England')

UNION

--ICB
SELECT 
	   Reporting_Period,
	   m.CDP_Measure_ID,
	   m.CDP_Measure_Name,
	   'ICB' as Org_Type,
	   ICB_Code as Org_Code,
	   ICB_Name as Org_Name,
	   ICB_Code,
	   ICB_Name,
	   Region_Code,
	   Region_Name,
	   m.Measure_Type,
	   SUM(Measure_Value) as Measure_Value

  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master_2] m

  LEFT JOIN (SELECT DISTINCT CDP_Measure_ID, Measure_Type, Aggregation_Required FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Metric_Info]) i ON m.CDP_Measure_ID = i.CDP_Measure_ID AND m.Measure_Type = i.Measure_Type

  WHERE Aggregation_Required = 'Y' 
   AND Org_Type = 'SubICB'

GROUP BY 
Reporting_Period,
m.CDP_Measure_ID,
m.CDP_Measure_Name,
ICB_Code,
ICB_Name,
Region_Code,
Region_Name,
m.Measure_Type

UNION 

--Region
SELECT 
	   Reporting_Period,
	   m.CDP_Measure_ID,
	   m.CDP_Measure_Name,
	   'Region' as Org_Type,
	   Region_Code as Org_Code,
	   Region_Name as Org_Name,
	   'NA' as ICB_Code,
	   'NA' as ICB_Name,
	   Region_Code,
	   Region_Name,
	   m.Measure_Type,
	   SUM(Measure_Value) as Measure_Value

  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master_2] m

  LEFT JOIN (SELECT DISTINCT CDP_Measure_ID, Measure_Type, Aggregation_Required FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Metric_Info]) i ON m.CDP_Measure_ID = i.CDP_Measure_ID AND m.Measure_Type = i.Measure_Type

  WHERE Aggregation_Required = 'Y' 
  AND Org_Type = 'SubICB'

GROUP BY 
Reporting_Period,
m.CDP_Measure_ID,
m.CDP_Measure_Name,
Region_Code,
Region_Name,
m.Measure_Type

--Delete data used in aggregation from master table

DELETE MHDInternal.TEMP_CDP_M_MHSDS_Master_2 
FROM MHDInternal.TEMP_CDP_M_MHSDS_Master_2  m

INNER JOIN [MHDInternal].[TEMP_CDP_M_MHSDS_Metric_Info] i ON m.CDP_Measure_ID = i.CDP_Measure_ID

  WHERE Aggregation_Required = 'Y'
	 AND Org_Type IN ('SubICB','ICB','Region')


/* STEP 2: REALLOCATIONS */

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside
-- Aggregated and non-aggregated data processed seperately due to the mis-match of Bassetlaw mapping 

-- Reallocations data
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations]
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master_2]
 WHERE Org_Code IN('01Y','06H','71E','D2P2L','QF7','Y63','QJM','QOP','Y62','QUA','QUE','Y61','15M','78H','03W','15E','QT1','Y60','QK1','QJ2','QHL','QPM') 
   AND Reporting_Period <'2022-07-01'

UNION

SELECT * 
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Aggregation]
 WHERE Org_Code IN('01Y','06H','71E','D2P2L','QJM','QOP','Y62','QUA','QUE','Y61','15M','78H','03W','15E','Y60','QK1','QJ2','QHL','QPM')
   AND Reporting_Period <'2022-07-01'

--No change data
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_No_Change]
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master_2]
 WHERE [Reporting_Period] >='2022-07-01' 
    OR ([Org_Code] NOT IN('01Y','06H','71E','D2P2L','QF7','Y63','QJM','QOP','Y62','QUA','QUE','Y61','15M','78H','03W','15E','QT1','Y60','QK1','QJ2','QHL','QPM') 
	    AND [Reporting_Period] <'2023-07-01')

UNION

SELECT * 
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Aggregation]
 WHERE Reporting_Period >='2022-07-01' 
    OR (Org_Code NOT IN('01Y','06H','71E','D2P2L','QJM','QOP','Y62','QUA','QUE','Y61','15M','78H','03W','15E','Y60','QK1','QJ2','QHL','QPM') 
        AND Reporting_Period <'2023-07-01')

-- Calculate activity movement for donor orgs
-- Bassetlaw included in pre-aggregated metrics
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Measure_Type,
	   r.Measure_Value * [Change] as Measure_Value_Change,
	   [Add]

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Changes_From]
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations] r

INNER JOIN [MHDInternal].[Reference_CDP_Boundary_Population_Changes] c ON r.[Org_Code] = c.[From]
 WHERE Bassetlaw_Indicator = 1 
   AND Measure_Type NOT IN ('Numerator','Denominator')

UNION 

-- Bassetlaw not included in metrics aggregated in script
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Measure_Type,
	   r.Measure_Value * [Change] as Measure_Value_Change,
	   [Add]

  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations] r
INNER JOIN [MHDInternal].[Reference_CDP_Boundary_Population_Changes] c ON r.[Org_Code] = c.[From]

 WHERE Bassetlaw_Indicator = 0 
   AND Measure_Type IN ('Numerator','Denominator')

-- Sum activity movement for orgs gaining (need to sum for Midlands Y60 which recieves from 2 orgs)
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   [Add] as Org_Code,
	   r.Measure_Type,
	   SUM(Measure_Value_Change) as Measure_Value_Change

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Changes_Add]
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Changes_From] r

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

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Final]
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations] r

INNER JOIN [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Changes_From] c 
        ON r.Reporting_Period = c.Reporting_Period
	   AND r.CDP_Measure_ID = c.CDP_Measure_ID
	   AND r.Org_Code = c.Org_Code
	   AND r.Measure_Type = c.Measure_Type

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

  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations] r

INNER JOIN [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Changes_Add] c 
        ON r.Reporting_Period = c.Reporting_Period
	   AND r.CDP_Measure_ID = c.CDP_Measure_ID
	   AND r.Org_Code = c.Org_Code
	   AND r.Measure_Type = c.Measure_Type

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Master_3]
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Final]

UNION

SELECT * 
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_No_Change]

--CALCULATE RATES & PERCENTAGES

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
	   END AS Measure_Type,
	   (
	   (CASE WHEN a.Measure_Value < 5 THEN NULL 
			 WHEN a.CDP_Measure_ID IN ('CDP_M07','CDP_M08') THEN CAST(a.Measure_Value*1000 AS FLOAT) 
			 ELSE CAST(a.Measure_Value AS FLOAT) 
			 END) 
		/
	   (CASE WHEN b.Measure_Value < 5 THEN NULL 
			 ELSE NULLIF(CAST(b.Measure_Value AS FLOAT),0)
			 END) 
	    )*100  as Measure_Value

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Percentage_Calcs]

  FROM (SELECT * 
		  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master_3] 
		 WHERE Measure_Type = 'Numerator') a

INNER JOIN (SELECT * 
	          FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master_3] 
		     WHERE Measure_Type = 'Denominator') b  
	    ON a.Reporting_Period = b.Reporting_Period
	   AND a.CDP_Measure_ID = b.CDP_Measure_ID 
	   AND a.Org_Type = b.Org_Type
	   AND a.Org_Code = b.Org_Code 

-- COLLATE ALL DATA

SELECT * 
  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Final] 
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Master_3]

UNION

SELECT * 
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Percentage_Calcs]

-- ADD MISSING ORGS

SELECT DISTINCT 
	   'SubICB' as Org_Type,
	   Organisation_Code as Org_Code,
	   Organisation_Name as Org_Name,
	   STP_Code as ICB_Code,
	   STP_Name as ICB_Name,
	   Region_Code,
	   Region_Name

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Org_List]

  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] 
 WHERE Effective_To IS NULL 
   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'
   AND Organisation_Name NOT LIKE '%SUB-ICB REPORTING ENTITY' --To exclude sub-ICB reporting entities being brought through with no dat

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
   AND Organisation_Name NOT LIKE '%SUB-ICB REPORTING ENTITY' --To exclude sub-ICB reporting entities being brought through with no data 

SELECT * 
  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Org_List_Dates]
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Org_List]
CROSS JOIN (SELECT DISTINCT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Measure_Type 
		      FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Final])_

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
	   NULL as Measure_Value

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Final_Extra_Orgs]

  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Org_List_Dates] d

LEFT JOIN [MHDInternal].[TEMP_CDP_M_MHSDS_Final] e 
       ON d.Reporting_Period = e.Reporting_Period
	  AND d.CDP_Measure_ID = e.CDP_Measure_ID  
	  AND d.Org_Type = e.Org_Type 
	  AND d.Org_Code = e.Org_Code 
	  AND d.Measure_Type = e.Measure_Type 

  WHERE e.Org_Code IS NULL

-- Add missing orgs into data

INSERT INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Final]
SELECT * 
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Final_Extra_Orgs]

/* STEP 3: ROUNDING & SUPRESSION, ADDING TARGETS, % ACHIEVED */

SELECT distinct
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
			WHEN f.Measure_Type = 'Mean' THEN f.[Measure_Value] --If a calculated mean, then do not round 
			WHEN f.Measure_Type IN('Percentage') AND f.Org_Type = 'England' THEN CAST(ROUND(f.[Measure_Value],1) AS FLOAT)/100 -- If percentage and eng round to 1dp
	        WHEN f.Measure_Type IN('Percentage') AND f.Org_Type <> 'England' THEN CAST(ROUND(f.[Measure_Value],0) AS FLOAT)/100 -- If percentage and not Eng then round to 0dp
			WHEN f.Measure_Type IN('Rate') AND f.Org_Type = 'England' THEN CAST(ROUND(f.[Measure_Value],1) AS FLOAT)
			WHEN f.Measure_Type IN('Rate') AND f.Org_Type <> 'England' THEN CAST(ROUND(f.[Measure_Value],0) AS FLOAT)
			WHEN f.[Measure_Value] < 5 THEN NULL -- supressed values shown as NULL
			WHEN f.Org_Type = 'England' THEN f.[Measure_Value] -- Counts for Eng no rounding
			ELSE CAST(ROUND(f.[Measure_Value]/5.0,0)*5 AS FLOAT) 
	   END as Measure_Value,
	   s.[Standard],
	   l.[LTP_Trajectory_Rounded] as LTP_Trajectory,
	   CASE WHEN f.Measure_Type NOT IN ('Rate','Percentage','Numerator','Denominator') 
			THEN ROUND(CAST([Measure_Value] AS FLOAT)/NULLIF(CAST(l.[LTP_Trajectory] AS FLOAT),0),2) 
			ELSE NULL 
	   END as LTP_Trajectory_Percentage_Achieved,
	   p.Plan_Rounded as [Plan],
	   CASE WHEN f.Measure_Type NOT IN ('Rate','Percentage','Numerator','Denominator') 
			THEN ROUND(CAST([Measure_Value] AS FLOAT)/NULLIF(CAST(p.[Plan] AS FLOAT),0),2) 
			ELSE NULL 
	   END as Plan_Percentage_Achieved,
	   s.Standard_STR,
	   l.LTP_Trajectory_STR,
	   p.Plan_STR

  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Final_2]

  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Final] f

LEFT JOIN [MHDInternal].[Reference_CDP_LTP_Trajectories] l 
       ON f.Reporting_Period = l.Reporting_Period 
	  AND f.Org_Code = l.Org_Code
	  AND (CASE WHEN f.Measure_Type IN ('Percentage','Rate','Count') THEN f.CDP_Measure_ID ELSE NULL END) = l.CDP_Measure_ID

LEFT JOIN [MHDInternal].[Reference_CDP_Plans] p 
	   ON f.Reporting_Period = p.Reporting_Period 
	  AND f.Org_Code = p.Org_Code 
	  AND (CASE WHEN f.Measure_Type  IN ('Percentage','Rate','Count') THEN f.CDP_Measure_ID ELSE NULL END) = p.CDP_Measure_ID

LEFT JOIN [MHDInternal].[Reference_CDP_Standards] s 
	   ON f.Reporting_Period = s.Reporting_Period 
	  AND f.CDP_Measure_ID  = s.CDP_Measure_ID  
	  AND f.Measure_Type = s.Measure_Type

/* STEP 4: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED */

-- Set Is_Latest in current table as 0
UPDATE [MHDInternal].[STAGING_CDP_M_MHSDS_Published]     --UDAL_Changes
SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) as Reporting_Period 
  INTO [MHDInternal].[TEMP_CDP_M_MHSDS_Is_Latest] 
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Final_2]



INSERT INTO [MHDInternal].[STAGING_CDP_M_MHSDS_Published]
SELECT 
	   f.Reporting_Period,
	   CASE WHEN i.Reporting_Period IS NOT NULL THEN 1 
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
	   CASE WHEN e.Org_Code IS NOT NULL THEN '-' -- If this row was added in as a missing org then show '-'
			WHEN f.[Measure_Value] IS NULL THEN '*' 
			WHEN f.Measure_Type IN('Percentage') THEN CAST(f.[Measure_Value]*100 AS VARCHAR)+'%' 
			ELSE FORMAT(f.Measure_Value,N'N0') 
	   END as Measure_Value_STR,
	   Standard_STR,
	   LTP_Trajectory_STR,
	   CAST(LTP_Trajectory_Percentage_Achieved*100 AS VARCHAR)+'%' as LTP_Trajectory_Percentage_Achieved_STR,
	   Plan_STR,
	   CAST(Plan_Percentage_Achieved*100 AS VARCHAR)+'%' as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified

  --INTO [MHDInternal].[STAGING_CDP_M_MHSDS_Published]                                                                 
  FROM [MHDInternal].[TEMP_CDP_M_MHSDS_Final_2] f

LEFT JOIN [MHDInternal].[TEMP_CDP_M_MHSDS_Is_Latest] i 
	   ON f.Reporting_Period = i.Reporting_Period

LEFT JOIN [MHDInternal].[TEMP_CDP_M_MHSDS_Final_Extra_Orgs] e 
	   ON f.Reporting_Period = e.Reporting_Period
	  AND f.CDP_Measure_ID = e.CDP_Measure_ID  
	  AND f.Org_Type = e.Org_Type
	  AND f.Org_Code = e.Org_Code
	  AND f.Measure_Type = e.Measure_Type

-------- ADDED TO REPLACE DELETES BELOW

LEFT JOIN (SELECT DISTINCT Organisation_Code AS Org_Code
			FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]
			WHERE Effective_To IS NULL 
			AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP') AS SubICB
	   ON f.Org_Code = SubICB.Org_Code
	  AND f.Org_Type = 'SubICB'

LEFT JOIN (SELECT DISTINCT STP_Code  AS Org_Code
			FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]
			WHERE Effective_To IS NULL 
			AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP') AS ICB
	   ON f.Org_Code = ICB.Org_Code
	  AND f.Org_Type = 'ICB'

LEFT JOIN (SELECT DISTINCT Region_Code  AS Org_Code
			FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]
			WHERE Effective_To IS NULL 
			AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP') AS Region
	   ON f.Org_Code = Region.Org_Code
	  AND f.Org_Type = 'Region'

WHERE f.Region_Code NOT LIKE 'REG%'
  AND f.Org_Code IS NOT NULL
  AND f.Org_Code <> 'UNKNOWN'
  AND ((f.Org_Type = 'SubICB' AND SubICB.Org_Code IS NOT NULL)
		OR (f.Org_Type = 'ICB' AND ICB.Org_Code IS NOT NULL)
		OR (f.Org_Type = 'Region' AND Region.Org_Code IS NOT NULL)
		OR (f.Org_Type = 'Provider' AND f.Org_Code <> '36L')
		OR f.Org_Type NOT IN ('SubICB', 'ICB', 'Region'))

ORDER BY 1,
		 3,
		 CASE WHEN f.Org_Type = 'England' THEN 1
			  WHEN f.Org_Type = 'Region' THEN 2
			  WHEN f.Org_Type = 'ICB' THEN 3
			  WHEN f.Org_Type = 'SubICB' THEN 4
			  WHEN f.Org_Type = 'Provider' THEN 5
			  ELSE 99 END,
		 f.Org_Code


/* STEP 5: QA - REMOVE UNSUPPORTED ORGS */

DELETE FROM [MHDInternal].[STAGING_CDP_M_MHSDS_Published]
WHERE Region_Code LIKE 'REG%' 
   OR Org_Code IS NULL 
   OR (Org_Type = 'SubICB' 
       AND Org_Code NOT IN (SELECT DISTINCT Organisation_Code 
							  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]
							 WHERE Effective_To IS NULL 
							   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))
  OR (Org_Type = 'ICB' 
      AND Org_Code NOT IN (SELECT DISTINCT STP_Code 
	                         FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]
							WHERE Effective_To IS NULL 
							  AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP')) 
  OR (Org_Type = 'Region' 
      AND Org_Code NOT IN (SELECT DISTINCT Region_Code 
							 FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]
							WHERE Effective_To IS NULL 
							  AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

-- Remove 'Unknown' provider
DELETE FROM [MHDInternal].[STAGING_CDP_M_MHSDS_Published]
where org_Code = 'UNKNOWN' OR (Org_Type = 'Provider' AND Org_Code = '36L')

           
-- QA Check for duplicate rows, this should return a blank table if none
SELECT Distinct 
	   Reporting_Period,
	   CDP_Measure_ID,
	   CDP_Measure_Name,
	   Measure_Type,
	   Org_Type,
	   Org_Code

 FROM (SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Measure_Type, Org_Type, Org_Code, count(1) cnt
         FROM [MHDInternal].[STAGING_CDP_M_MHSDS_Published]
       GROUP BY Reporting_Period,
	   CDP_Measure_ID, 
	   CDP_Measure_Name,
	   Measure_Type,
	   Org_Type,
	   Org_Code
	   HAVING count(1) > 1
       ) a
	 

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

  FROM [MHDInternal].[STAGING_CDP_M_MHSDS_Published] latest

  LEFT JOIN [MHDInternal].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [MHDInternal].[STAGING_CDP_M_MHSDS_Published] previous
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

--check dates of each metric match what is expected
SELECT DISTINCT CDP_MEASURE_ID, Reporting_Period
  FROM [MHDInternal].[STAGING_CDP_M_MHSDS_Published]  
 WHERE Measure_Value IS NOT NULL -- needed once future trajectories/plans are added
   AND Reporting_Period >= @RPEnd
ORDER BY 1 ASC

--check table has updated okay, should be 15 measures as of 18/10/2023:
SELECT COUNT(DISTINCT cdp_measure_id)
  FROM [MHDInternal].[STAGING_CDP_M_MHSDS_Published]  
  WHERE Measure_Value IS NOT NULL -- needed once future trajectories/plans are added
  AND Reporting_Period >= @RPEnd

/* STEP 6: DROP TEMP TABLES */

DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Metric_Info]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Population_Dates]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_RAW]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Master]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Master_2]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_No_Change]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Changes_From]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Changes_Add]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Reallocations_Final]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Master_3]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Aggregation]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Percentage_Calcs]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Is_Latest]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Final]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Final_2]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Org_List_Dates]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Org_List]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_Final_Extra_Orgs]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_LOS_Staging]
DROP TABLE [MHDInternal].[TEMP_CDP_M_MHSDS_LOS_Staging_2]
 
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ADDITIONAL STEP - KEEP COMMENTED OUT UNTIL NEEDED
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
--[Reporting_Period],
--[CDP_Measure_ID],
--[CDP_Measure_Name],
--[Org_Type],
--[Org_Code],
--[Org_Name],
--[Measure_Type]

--INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_M_MHSDS_Published_Future_Months]

--FROM ( 
--SELECT [Reporting_Period],
--[CDP_Measure_ID],
--[CDP_Measure_Name],
--[Org_Type],
--[Org_Code],
--[Org_Name],
--[Measure_Type] 
--FROM [MHDInternal].[Reference_CDP_Trajectories]
--WHERE CDP_Measure_ID IN('CDP_M02','CDP_M03','CDP_M04') -- ADD MEASURE IDS
--AND [Reporting_Period] BETWEEN @RPStartTargets AND @RPEndTargets 

--UNION

--SELECT [Reporting_Period],
--[CDP_Measure_ID],
--[CDP_Measure_Name],
--[Org_Type],
--[Org_Code],
--[Org_Name],
--[Measure_Type]
--FROM  [MHDInternal].[Reference_CDP_Plans] 
--WHERE CDP_Measure_ID IN('CDP_M01','CDP_M02','CDP_M03','CDP_M04','CDP_M06') -- ADD MEASURE IDS
--AND [Reporting_Period] BETWEEN @RPStartTargets AND @RPEndTargets )_

--INSERT INTO NHSE_Sandbox_Policy.dbo.STAGING_CDP_M_MHSDS_Published
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

--	FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_M_MHSDS_Published_Future_Months] f
--	LEFT JOIN [MHDInternal].[Reference_CDP_Plans]  p  ON f.[Reporting_Period] = p.[Reporting_Period] AND f.Org_Code = p.Org_Code AND f.[CDP_Measure_ID] = p.[CDP_Measure_ID] AND f.Org_Type = p.Org_Type
--	LEFT JOIN [MHDInternal].[Reference_CDP_Trajectories]  l  ON f.[Reporting_Period] = l.[Reporting_Period] AND f.Org_Code = l.Org_Code AND f.[CDP_Measure_ID] = l.[CDP_Measure_ID] AND f.Org_Type = l.Org_Type
--	INNER JOIN 
--	(SELECT DISTINCT Org_Code, Org_Name, ICB_Code, ICB_Name, Region_Code, Region_Name 
--	FROM NHSE_Sandbox_Policy.dbo.STAGING_CDP_M_MHSDS_Published) s ON f.Org_Code = s.Org_Code-- Used the output table to lookup mapping

--	DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_M_MHSDS_Published_Future_Months]
