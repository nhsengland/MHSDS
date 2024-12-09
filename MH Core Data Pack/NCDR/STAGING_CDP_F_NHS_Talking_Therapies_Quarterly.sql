/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

CODE FOR CORE DATA PACK DASHBOARD 

MEASURE NAME(s): CDP_F01: NHS Talking Therapies Access 65+
			     CDP_F02: NHS Talking Therapies Recovery BME
			     CDP_F03: NHS Talking Therapies Recovery White British

MEASURE DESCRIPTION(s):
				 CDP_F01: The number of people aged 65+ who enter NHS funded treatment with IAPT services in the reporting period
				 CDP_F02: The proportion of people who have attended at least two contacts and are moving to recovery in the reporting period (BME)
				 CDP_F03: The proportion of people who have attended at least two contacts and are moving to recovery in the reporting period (White British)
				 

BACKGROUND INFO: This is a quarterly collection, therefore there should only be updates to the data for the most recent quarter.
				 The code has been set up this way, if there are revisions to previous quarters the code will need adjusting.
				 New quarter data will be in Mar for Dec data, Jun for Mar data, Sep for Jun data, Dec for Sep data.

				 There were changes to the collection in 2020-12-31, this has a few effects on the code.
				 1. The data < 2020-12-31 does not have measure_id so the data is looked up from the measure_name, 
				    this is why there is a metric info table at the start of the script and a case when join to it in the master data table in step 1.
				 2. There is no data for 2020-09-30 whilst the changes were being made.

				 For data < 2020-06-30 there were STP e-codes, these have been changed to ICB codes using the [UKHD_ODS].[STP_Names_And_Codes_England_SCD]
				 and hard coding those that are missing from this table.

				 Originally there was no Region data in the dataset, however from 2023-03-31 onwards there is.
				 The code accomodates for this; < 2023-03-31 Region data is aggregated up from STP/ICB, for 2023-03-31 onwards it comes directly from source.

				 The reallocations for the ICB boundary changes in 2022-07-01 have been applies as usual.
				 The percentage data is re-calculated for the effected orgs for data < 2022-07-01.

INPUT:			 FOR ALL MEASURES (Access 65+, BME, WhiteBritish)
				 [UKHF_IAPT].[Activity_Data_Qtr1]
				 [Reporting].[Ref_ODS_Commissioner_Hierarchies]
				 [Internal_Reference].[ComCodeChanges]
				 [UKHD_ODS].[STP_Names_And_Codes_England_SCD]
				 [MHDInternal].[Reference_CDP_Boundary_Population_Changes]
				 [MHDInternal].[Reference_CDP_Trajectories]
				 [MHDInternal].[Reference_CDP_Plans]
				 [MHDInternal].[Reference_CDP_Standards]

TEMP TABLES:	 SEE DROPPED TABLES AT END OF THE SCRIPT.

OUTPUT:			 [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]

WRITTEN BY:		 KIRSTY WALKER 25/05/2023

UPDATES:		 [insert description of any updates, insert your name and date]

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE-STEPS - METRIC LIST
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

CREATE TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Metric_Info] (CDP_Measure_ID VARCHAR(20), Published_Measure_ID VARCHAR(20) collate SQL_Latin1_General_CP1_CI_AS, Published_Measure_Name_New VARCHAR(40) collate SQL_Latin1_General_CP1_CI_AS, Published_Measure_Name_Old VARCHAR(30) collate SQL_Latin1_General_CP1_CI_AS, Variable_Type VARCHAR(20), Variable_A VARCHAR(20), CDP_Measure_Name VARCHAR(150),Measure_Type VARCHAR(50))

INSERT INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Metric_Info]
VALUES 
	  ('CDP_F01','M031','Count_AccessingServices','FirstTreatment','Working Age','65 and over','NHS Talking Therapies Access 65+','Count'), -- replaced by new access measure
	  ('CDP_F02','M192','Percentage_Recovery','RecoveryRate','BME Group','BME','NHS Talking Therapies Recovery BME','Percentage'), -- replaced by reliable recovery 
	  ('CDP_F02','M191','Count_Recovery','Recovery','BME Group','BME','NHS Talking Therapies Recovery BME','Numerator'), -- replaced by reliable recovery 
	  ('CDP_F02','M076','Count_FinishedCourseTreatment','FinishedCourseTreatment','BME Group','BME','NHS Talking Therapies Recovery BME','Denominator1'),
	  ('CDP_F02','M179','Count_NotAtCaseness','NotCaseness','BME Group','BME','NHS Talking Therapies Recovery BME','Denominator2'),
	  ('CDP_F03','M192','Percentage_Recovery','RecoveryRate','BME Group','White British','NHS Talking Therapies Recovery White British','Percentage'),
	  ('CDP_F03','M191','Count_Recovery','Recovery','BME Group','White British','NHS Talking Therapies Recovery White British','Numerator'),
	  ('CDP_F03','M076','Count_FinishedCourseTreatment','FinishedCourseTreatment','BME Group','White British','NHS Talking Therapies Recovery White British','Denominator1'),
	  ('CDP_F03','M179','Count_NotAtCaseness','NotCaseness','BME Group','White British','NHS Talking Therapies Recovery White British','Denominator2'),
	  ('CDP_F04','M076','Count_FinishedCourseTreatment','FinishedCourseTreatment','Working Age','65 and over','NHS Talking Therapies Completing a Course of Treatment 65+','Count'), -- new access measure 
	  ('CDP_F05','M195','Percentage_ReliableRecovery','ReliableRecoveryRate','BME Group','BME','NHS Talking Therapies Reliable Recovery BME','Percentage'), -- new 
	  ('CDP_F05','M193','Count_ReliableRecovery','ReliableRecovery','BME Group','BME','NHS Talking Therapies Reliable Recovery BME','Numerator'), -- new
	  ('CDP_F05','M076','Count_FinishedCourseTreatment','FinishedCourseTreatment','BME Group','BME','NHS Talking Therapies Reliable Recovery BME','Denominator1'), -- new
	  ('CDP_F05','M179','Count_NotAtCaseness','NotCaseness','BME Group','BME','NHS Talking Therapies Reliable Recovery BME','Denominator2'), -- new 
	  ('CDP_F06','M195','Percentage_ReliableRecovery','ReliableRecoveryRate','BME Group','White British','NHS Talking Therapies Reliable Recovery White British','Percentage'), -- new 
	  ('CDP_F06','M193','Count_ReliableRecovery','ReliableRecovery','BME Group','White British','NHS Talking Therapies Reliable Recovery White British','Numerator'), -- new 
	  ('CDP_F06','M076','Count_FinishedCourseTreatment','FinishedCourseTreatment','BME Group','White British','NHS Talking Therapies Reliable Recovery White British','Denominator1'), -- new
	  ('CDP_F06','M179','Count_NotAtCaseness','NotCaseness','BME Group','White British','NHS Talking Therapies Reliable Recovery White British','Denominator2') -- new
	  
 
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE-STEPS - DATES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DECLARE @NEWQUARTER as DATE

SET @NEWQUARTER = (select MAX(Effective_Snapshot_Date) FROM [UKHF_IAPT].[Activity_Data_Qtr1])

PRINT @NEWQUARTER

DELETE FROM [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly] WHERE REPORTING_PERIOD=@NEWQUARTER

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1: WRANGLE THE RAW DATA INTO MASTER DATA TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
SELECT 
	   TT.Effective_Snapshot_Date as Reporting_Period,
	   mi.CDP_Measure_ID,
	   mi.CDP_Measure_Name,
	   CASE WHEN TT.Group_Type = 'England' THEN 'England'
			WHEN TT.Group_Type = 'CommRegion' THEN 'Region'
			WHEN TT.Group_Type in ('ICB', 'STP') THEN 'ICB'
			WHEN TT.Group_Type in ('SubICB', 'CCG') THEN 'SubICB'
	   END as Org_Type,
	   CASE WHEN TT.Group_Type = 'England' THEN 'ENG'
			WHEN TT.Group_Type = 'CommRegion' THEN r.Region_Code
			WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code ='E54000050' THEN 'QHM'
															WHEN TT.STP_Code ='E54000051' THEN 'QOQ'
															WHEN TT.STP_Code ='E54000052' THEN 'QXU'
															WHEN TT.STP_Code ='E54000053' THEN 'QNX'
															WHEN TT.STP_Code ='E54000054' THEN 'QWO'
														    ELSE COALESCE(s.STP_Code, i.STP_Code) END)
			WHEN TT.Group_Type in ('SubICB', 'CCG') THEN COALESCE(cc.New_Code, TT.Commissioner_Code COLLATE database_default)
	   END as Org_Code,
	   CASE WHEN TT.Group_Type = 'England' THEN 'England'
	   		WHEN TT.Group_Type = 'CommRegion' THEN r.Region_Name
			WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code ='E54000050' THEN 'NHS NORTH EAST AND NORTH CUMBRIA INTEGRATED CARE BOARD'
															WHEN TT.STP_Code ='E54000051' THEN 'NHS HUMBER AND NORTH YORKSHIRE INTEGRATED CARE BOARD'
															WHEN TT.STP_Code ='E54000052' THEN 'NHS SURREY HEARTLANDS INTEGRATED CARE BOARD'
															WHEN TT.STP_Code ='E54000053' THEN 'NHS SUSSEX INTEGRATED CARE BOARD'
															WHEN TT.STP_Code ='E54000054' THEN 'NHS WEST YORKSHIRE INTEGRATED CARE BOARD'
														    ELSE COALESCE(s.STP_Name, i.STP_Name) END) 
			WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.Organisation_Name
	   END as Org_Name,
	   CASE WHEN TT.Group_Type = 'England' THEN 'NA' 
	   		WHEN TT.Group_Type = 'CommRegion' THEN 'NA'
			WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code ='E54000050' THEN 'QHM'
															WHEN TT.STP_Code ='E54000051' THEN 'QOQ'
															WHEN TT.STP_Code ='E54000052' THEN 'QXU'
															WHEN TT.STP_Code ='E54000053' THEN 'QNX'
															WHEN TT.STP_Code ='E54000054' THEN 'QWO'
														    ELSE COALESCE(s.STP_Code, i.STP_Code) END)
			WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.STP_Code
	   END as ICB_Code,
	   CASE WHEN TT.Group_Type = 'England' THEN 'NA' 
	   		WHEN TT.Group_Type = 'CommRegion' THEN 'NA'
			WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code ='E54000050' THEN 'NHS NORTH EAST AND NORTH CUMBRIA INTEGRATED CARE BOARD'
															WHEN TT.STP_Code ='E54000051' THEN 'NHS HUMBER AND NORTH YORKSHIRE INTEGRATED CARE BOARD'
															WHEN TT.STP_Code ='E54000052' THEN 'NHS SURREY HEARTLANDS INTEGRATED CARE BOARD'
															WHEN TT.STP_Code ='E54000053' THEN 'NHS SUSSEX INTEGRATED CARE BOARD'
															WHEN TT.STP_Code ='E54000054' THEN 'NHS WEST YORKSHIRE INTEGRATED CARE BOARD'
														    ELSE COALESCE(s.STP_Name, i.STP_Name) END)
			WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.STP_Name
	   END as ICB_Name,
	   CASE WHEN TT.Group_Type = 'England' THEN 'NA' 
	   		WHEN TT.Group_Type = 'CommRegion' THEN r.Region_Code
			WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'Y63'
															WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'Y59'
														    ELSE COALESCE(s.Region_Code, i.Region_Code) END)
			WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.Region_Code
	   END as Region_Code,
	   CASE WHEN TT.Group_Type = 'England' THEN 'NA' 
	   		WHEN TT.Group_Type = 'CommRegion' THEN r.Region_Name
			WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'NORTH EAST AND YORKSHIRE'
															WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'SOUTH EAST'
														    ELSE COALESCE(s.Region_Name, i.Region_Name) END)
			WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.Region_Name
	   END as Region_Name,
	   mi.Measure_Type,
	   CASE WHEN mi.Measure_Type = 'Percentage'
	        THEN SUM(TT.Measure_Value)/100
			ELSE SUM(TT.Measure_Value)
	   END as 'Measure_Value'

  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Master]

  FROM [UKHF_IAPT].[Activity_Data_Qtr1] TT

--Metric info
INNER JOIN [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Metric_Info] mi 
       ON (CASE WHEN TT.Effective_Snapshot_Date >='2020-12-31' THEN TT.Measure_ID 
			    WHEN TT.Effective_Snapshot_Date < '2020-12-31' THEN TT.Measure_Name END)
	    = 
		  (CASE WHEN TT.Effective_Snapshot_Date >='2020-12-31' THEN mi.Published_Measure_ID
			    WHEN TT.Effective_Snapshot_Date < '2020-12-31' THEN mi.Published_Measure_Name_Old END)   
	  AND TT.Variable_Type = mi.Variable_Type COLLATE database_default
	  AND TT.Variable_A = mi.Variable_A COLLATE database_default

--Region names
LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name 
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] ) r 
					    ON TT.STP_Code = r.Region_Code COLLATE database_default
						
--ICB hierarchies
LEFT JOIN (SELECT DISTINCT e.STP_ODS_Code, ch.STP_Code, ch.STP_Name, ch.Region_Code, ch.Region_Name
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]  ch
			     LEFT JOIN [UKHD_ODS].[STP_Names_And_Codes_England_SCD] e ON ch.STP_Code = e.STP_ODS_Code
				     WHERE e.STP_ODS_Code <> 'NULL') s
					    ON TT.STP_Code = s.STP_ODS_Code COLLATE database_default

LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] 
					  WHERE STP_Code NOT IN ('DUM001','DUM002','UNK','X24')) i
					    ON TT.STP_Code = i.STP_Code COLLATE database_default

--SubICB hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [Internal_Reference].[ComCodeChanges] cc 
       ON TT.Commissioner_Code = cc.Org_Code COLLATE database_default

LEFT JOIN [Reporting_UKHD_ODS].[Commissioner_Hierarchies]  ch 
       ON COALESCE(cc.New_Code, TT.Commissioner_Code) = ch.Organisation_Code COLLATE database_default

  WHERE 
	    TT.Effective_Snapshot_Date = @NEWQUARTER
        --TT.Effective_Snapshot_Date BETWEEN '2019-06-30' AND @NEWQUARTER
	AND TT.Group_Type NOT IN ('CCG-Provider', 'SubICB-Provider', 'Provider')
	AND TT.STP_Code NOT IN ('InvalidCode','InvCode','InvRegCode')
	AND NOT (TT.Group_Type='STP' AND TT.STP_Code='NULL')
	AND TT.Commissioner_Code NOT IN ('InvalidCode','InvCode')
	AND NOT (TT.Group_Type='CCG' AND TT.Commissioner_Code='NULL')
	AND TT.Commissioner_Code NOT IN (SELECT DISTINCT Organisation_Code COLLATE database_default
												FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] 
											   WHERE NHSE_Organisation_Type='COMMISSIONING HUB')

GROUP BY
TT.Effective_Snapshot_Date,
mi.CDP_Measure_ID,
mi.CDP_Measure_Name,
CASE WHEN TT.Group_Type = 'England' THEN 'England'
	 WHEN TT.Group_Type = 'CommRegion' THEN 'Region'
	 WHEN TT.Group_Type in ('ICB', 'STP') THEN 'ICB'
	 WHEN TT.Group_Type in ('SubICB', 'CCG') THEN 'SubICB'
END,
CASE WHEN TT.Group_Type = 'England' THEN 'ENG'
	 WHEN TT.Group_Type = 'CommRegion' THEN r.Region_Code
	 WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code ='E54000050' THEN 'QHM'
													 WHEN TT.STP_Code ='E54000051' THEN 'QOQ'
													 WHEN TT.STP_Code ='E54000052' THEN 'QXU'
													 WHEN TT.STP_Code ='E54000053' THEN 'QNX'
													 WHEN TT.STP_Code ='E54000054' THEN 'QWO'
													 ELSE COALESCE(s.STP_Code, i.STP_Code) END)
	 WHEN TT.Group_Type in ('SubICB', 'CCG') THEN COALESCE(cc.New_Code, TT.Commissioner_Code COLLATE database_default)
END,
CASE WHEN TT.Group_Type = 'England' THEN 'England'
	 WHEN TT.Group_Type = 'CommRegion' THEN r.Region_Name
	 WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code ='E54000050' THEN 'NHS NORTH EAST AND NORTH CUMBRIA INTEGRATED CARE BOARD'
													 WHEN TT.STP_Code ='E54000051' THEN 'NHS HUMBER AND NORTH YORKSHIRE INTEGRATED CARE BOARD'
													 WHEN TT.STP_Code ='E54000052' THEN 'NHS SURREY HEARTLANDS INTEGRATED CARE BOARD'
													 WHEN TT.STP_Code ='E54000053' THEN 'NHS SUSSEX INTEGRATED CARE BOARD'
													 WHEN TT.STP_Code ='E54000054' THEN 'NHS WEST YORKSHIRE INTEGRATED CARE BOARD'
													 ELSE COALESCE(s.STP_Name, i.STP_Name) END) 
	 WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.Organisation_Name
END,
CASE WHEN TT.Group_Type = 'England' THEN 'NA' 
	 WHEN TT.Group_Type = 'CommRegion' THEN 'NA'
	 WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code ='E54000050' THEN 'QHM'
													 WHEN TT.STP_Code ='E54000051' THEN 'QOQ'
													 WHEN TT.STP_Code ='E54000052' THEN 'QXU'
													 WHEN TT.STP_Code ='E54000053' THEN 'QNX'
													 WHEN TT.STP_Code ='E54000054' THEN 'QWO'
													 ELSE COALESCE(s.STP_Code, i.STP_Code) END)
	 WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.STP_Code
END,
CASE WHEN TT.Group_Type = 'England' THEN 'NA' 
	 WHEN TT.Group_Type = 'CommRegion' THEN 'NA'
	 WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code ='E54000050' THEN 'NHS NORTH EAST AND NORTH CUMBRIA INTEGRATED CARE BOARD'
												 	 WHEN TT.STP_Code ='E54000051' THEN 'NHS HUMBER AND NORTH YORKSHIRE INTEGRATED CARE BOARD'
													 WHEN TT.STP_Code ='E54000052' THEN 'NHS SURREY HEARTLANDS INTEGRATED CARE BOARD'
													 WHEN TT.STP_Code ='E54000053' THEN 'NHS SUSSEX INTEGRATED CARE BOARD'
													 WHEN TT.STP_Code ='E54000054' THEN 'NHS WEST YORKSHIRE INTEGRATED CARE BOARD'
													 ELSE COALESCE(s.STP_Name, i.STP_Name) END)
	 WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.STP_Name
END,
CASE WHEN TT.Group_Type = 'England' THEN 'NA' 
	 WHEN TT.Group_Type = 'CommRegion' THEN r.Region_Code
	 WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'Y63'
													 WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'Y59'
													 ELSE COALESCE(s.Region_Code, i.Region_Code) END)
	 WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.Region_Code
END,
CASE WHEN TT.Group_Type = 'England' THEN 'NA' 
	 WHEN TT.Group_Type = 'CommRegion' THEN r.Region_Name
	 WHEN TT.Group_Type in ('ICB', 'STP') THEN (CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'NORTH EAST AND YORKSHIRE'
													 WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'SOUTH EAST'
													 ELSE COALESCE(s.Region_Name, i.Region_Name) END)
	 WHEN TT.Group_Type in ('SubICB', 'CCG') THEN ch.Region_Name
END,
mi.Measure_Type

--Region data for < 2023-03-31 when region data didn't exist in the publication table
UNION

SELECT 
	   TT.Effective_Snapshot_Date as Reporting_Period,
	   mi.CDP_Measure_ID,
	   mi.CDP_Measure_Name,
	   'Region' as Org_Type,
	   CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'Y63'
			WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'Y59'
			ELSE COALESCE(s.Region_Code, i.Region_Code) 
	   END as Org_Code,
	   CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'NORTH EAST AND YORKSHIRE'
			WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'SOUTH EAST'
			ELSE COALESCE(s.Region_Name, i.Region_Name) 
	   END as Org_Name,
	   'NA' as ICB_Code,
	   'NA' as ICB_Name,
	   CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'Y63'
			WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'Y59'
			ELSE COALESCE(s.Region_Code, i.Region_Code) 
	   END as Region_Code,
	   CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'NORTH EAST AND YORKSHIRE'
			WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'SOUTH EAST'
			ELSE COALESCE(s.Region_Name, i.Region_Name) 
	   END as Region_Name,
	   mi.Measure_Type,
	   Sum(TT.Measure_Value) as 'Measure_Value'

  FROM [UKHF_IAPT].[Activity_Data_Qtr1] TT

--Metric info
INNER JOIN [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Metric_Info] mi 
       ON CASE WHEN TT.Effective_Snapshot_Date>='2020-12-31' THEN TT.Measure_ID 
			   WHEN TT.Effective_Snapshot_Date< '2020-12-31' THEN TT.Measure_Name END
	    = 
		  CASE WHEN TT.Effective_Snapshot_Date>='2020-12-31' THEN mi.Published_Measure_ID
			   WHEN TT.Effective_Snapshot_Date< '2020-12-31' THEN mi.Published_Measure_Name_Old END	   
	  AND TT.Variable_Type = mi.Variable_Type COLLATE database_default
	  AND TT.Variable_A = mi.Variable_A COLLATE database_default

LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies] ) i
					    ON TT.STP_Code = i.STP_Code COLLATE database_default

LEFT JOIN (SELECT DISTINCT e.STP_Code, ch.Region_Code, ch.Region_Name
					  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]  ch
			     LEFT JOIN [UKHD_ODS].[STP_Names_And_Codes_England_SCD] e ON ch.STP_Code = e.STP_ODS_Code
				     WHERE e.STP_ODS_Code <> 'NULL') s
					    ON TT.STP_Code = s.STP_Code COLLATE database_default

  WHERE 
	    TT.Effective_Snapshot_Date < '2023-03-31'
		AND	TT.Effective_Snapshot_Date = @NEWQUARTER
    --AND	TT.Effective_Snapshot_Date BETWEEN '2019-06-30' AND @NEWQUARTER
	AND TT.Group_Type IN ('STP','ICB')
	AND TT.STP_Code NOT IN ('InvalidCode','InvCode','NULL')
	AND mi.Measure_Type <> 'Percentage'

GROUP BY
TT.Effective_Snapshot_Date,
mi.CDP_Measure_ID,
mi.CDP_Measure_Name,
CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'Y63'
WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'Y59'
ELSE COALESCE(s.Region_Code, i.Region_Code) 
END,
CASE WHEN TT.STP_Code IN ('E54000050','E54000051','E54000054') THEN 'NORTH EAST AND YORKSHIRE'
WHEN TT.STP_Code IN ('E54000052','E54000053') THEN 'SOUTH EAST'
ELSE COALESCE(s.Region_Name, i.Region_Name) 
END,
mi.Measure_Type

--Calculate the Denominator
SELECT m.Reporting_Period,
	   m.CDP_Measure_ID,
	   m.CDP_Measure_Name,
	   m.Org_Type,
	   m.Org_Code,
	   m.Org_Name,
	   m.ICB_Code,
	   m.ICB_Name,
	   m.Region_Code,
	   m.Region_Name,
	   CASE WHEN m.Measure_Type IN ('Denominator1','Denominator2') THEN 'Denominator'
			ELSE m.Measure_Type
	   END as Measure_Type,
	   CASE WHEN m.Measure_Type IN ('Numerator','Count','Percentage') THEN SUM(m.Measure_Value)
            WHEN m.Measure_Type IN ('Denominator1') THEN (SUM(m.Measure_Value) - COALESCE(SUM(d2.Measure_Value),0)) 
	   END as Measure_Value

  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures]

  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Master] m

LEFT JOIN (SELECT *
			 FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Master] 
		    WHERE Measure_Type='Denominator2') d2
       ON m.Reporting_Period = d2.Reporting_Period
      AND m.CDP_Measure_ID = d2.CDP_Measure_ID
      AND m.Org_Code = d2.Org_Code

WHERE m.Measure_Type <> 'Denominator2'

GROUP BY
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
m.Measure_Type

--ADD the calculated percentage for Region data for < 2023-03-31 when region data didn't exist in the publication table (aggregated from ICB)
INSERT INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures]

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
	   COALESCE((SUM(Num.Measure_Value)/SUM(Den.Measure_Value)),0) as Measure_Value

  FROM
  (SELECT *	  
     FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures]
	WHERE Reporting_Period < '2023-03-31'
	  AND Measure_Type='Numerator'
      AND Org_Type='Region') Num

INNER JOIN 
  (SELECT * 
	 FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures]
	WHERE Measure_Type='Denominator'
	  AND Org_Type='Region') Den 
	   ON Num.Reporting_Period = Den.Reporting_Period
	  AND Num.CDP_Measure_ID = Den.CDP_Measure_ID
	  AND Num.Org_Code = Den.Org_Code

GROUP BY
Num.Reporting_Period,
Num.CDP_Measure_ID,
Num.CDP_Measure_Name,
Num.Org_Type,
Num.Org_Code,
Num.Org_Name,
Num.ICB_Code,
Num.ICB_Name,
Num.Region_Code,
Num.Region_Name

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: REALLOCATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--GET LIST OF UNIQUE REALLOCATIONS FOR ALL ORGS
IF OBJECT_ID ('[MHDInternal].[TEMP_CDP_Reallocations_All_Orgs]') IS NOT NULL
DROP TABLE [MHDInternal].[TEMP_CDP_Reallocations_All_Orgs]

SELECT DISTINCT [From] COLLATE database_default as Orgs
  INTO [MHDInternal].[TEMP_CDP_Reallocations_All_Orgs]
  FROM [MHDInternal].[Reference_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 1

UNION

SELECT DISTINCT [Add] COLLATE database_default as Orgs
  FROM [MHDInternal].[Reference_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 1

--Delete the percentage for effected Reallocation orgs (<'2022-07-01') which will need recalculating after reallocations
DELETE FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures]
WHERE (Org_Code IN (SELECT Orgs FROM [MHDInternal].[TEMP_CDP_Reallocations_All_Orgs]) 
  AND Reporting_Period < '2022-07-01'
  AND Measure_Type = 'Percentage')

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside in no change table
-- Use this for if Bassetlaw_Indicator = 1 (bassetlaw has not yet been moved to new location)
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den]
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures]

 WHERE Org_Code IN (SELECT Orgs FROM [MHDInternal].[TEMP_CDP_Reallocations_All_Orgs])
   AND Reporting_Period <'2022-07-01'
   AND Measure_Type <> 'Percentage'

--No change data
-- Use this for if Bassetlaw_Indicator = 1 (bassetlaw has not yet been moved to new location, old data needs changing)
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Count_Num_&_Den_No_Change]
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures] 
 WHERE Reporting_Period >='2022-07-01' 
    OR (Org_Code NOT IN (SELECT Orgs FROM [MHDInternal].[TEMP_CDP_Reallocations_All_Orgs]) 
   AND Reporting_Period <'2022-07-01')
    OR Measure_Type = 'Percentage'

-- Calculate activity movement for donor orgs
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Measure_Type,
	   r.Measure_Value * c.Change as Measure_Value_Change,
	   c.[Add]

  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den_Changes_From]
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den] r

INNER JOIN [MHDInternal].[Reference_CDP_Boundary_Population_Changes] c 
	ON r.Org_Code = c.[From]
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

  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den_Changes_Add] 
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den_Changes_From] r

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
	   r.Measure_Value - c.Measure_Value_Change as Measure_Value

  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated_Count_Num_&_Den] 

  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den] r

INNER JOIN [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den_Changes_From] c 
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
	   r.Measure_Value + c.Measure_Value_Change as Measure_Value

  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den] r

INNER JOIN [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den_Changes_Add]  c 
    ON r.Org_Code = c.Org_Code 
   AND r.Reporting_Period = c.Reporting_Period 
   AND r.Measure_Type = c.Measure_Type 
   AND r.CDP_Measure_Name = c.CDP_Measure_Name

 -- Calculate any percentages needed in the data - for effected orgs 

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
	   COALESCE((SUM(Num.Measure_Value)/SUM(Den.Measure_Value)),0) as Measure_Value

  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated_%]

  FROM
  (SELECT *	  
     FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated_Count_Num_&_Den]
	WHERE Measure_Type='Numerator'
	  AND Org_Code IN (SELECT Orgs FROM [MHDInternal].[TEMP_CDP_Reallocations_All_Orgs]) 
	  AND Reporting_Period <'2022-07-01') Num

INNER JOIN 
  (SELECT * 
	 FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated_Count_Num_&_Den]
	WHERE Measure_Type='Denominator'
	  AND Org_Code IN (SELECT Orgs FROM [MHDInternal].[TEMP_CDP_Reallocations_All_Orgs]) ) Den 
	   ON Num.Reporting_Period = Den.Reporting_Period
	  AND Num.CDP_Measure_ID = Den.CDP_Measure_ID
	  AND Num.Org_Code = Den.Org_Code

GROUP BY
Num.Reporting_Period,
Num.CDP_Measure_ID,
Num.CDP_Measure_Name,
Num.Org_Type,
Num.Org_Code,
Num.Org_Name,
Num.ICB_Code,
Num.ICB_Name,
Num.Region_Code,
Num.Region_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated]
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated_Count_Num_&_Den] 

 UNION

SELECT * 
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated_%]

 UNION

SELECT * 
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Count_Num_&_Den_No_Change]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 3: LOOP IN MISSING ICBs and SubICBs
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

  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Org_List]
  FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]  
 WHERE Effective_To IS NULL 
   AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'
   AND Organisation_Name NOT LIKE '%SUB-ICB REPORTING ENTITY' --To exclude sub-ICB reporting entities being brought through with no data

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
  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Org_List_Dates]
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Org_List]
CROSS JOIN (SELECT DISTINCT 
				   Reporting_Period, 
				   CDP_Measure_ID,
				   CDP_Measure_Name,
				   Measure_Type 
			  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures])_

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

 INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Missing_Orgs]

 FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Org_List_Dates] d

LEFT JOIN [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated] e 
   ON d.Reporting_Period = e.Reporting_Period
  AND d.CDP_Measure_ID = e.CDP_Measure_ID  
  AND d.Org_Type = e.Org_Type
  AND d.Org_Code = e.Org_Code 
  AND d.Measure_Type = e.Measure_Type 
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated]
SELECT * 
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Missing_Orgs]

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
	   f.Measure_Value,
	   s.[Standard],
	   l.[LTP_Trajectory_Rounded] AS [LTP_Trajectory],
	   CAST(NULL as float) as LTP_Trajectory_Percentage_Achieved,
	   p.[Plan_Rounded] AS [Plan],
	   CAST(NULL as float) as Plan_Percentage_Achieved,
	   s.Standard_STR,
	   l.LTP_Trajectory_STR,
	   p.Plan_STR

  INTO [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_&_Targets]
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated] f

--LEFT JOIN [MHDInternal].[Reference_CDP_Trajectories] l                            --UDAL Changes
LEFT JOIN [MHDInternal].[REFERENCE_CDP_LTP_Trajectories] l 
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

---- Set Is_Latest in current table as 0
UPDATE [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]
SET Is_Latest = 0

INSERT INTO [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]

SELECT
	   m.Reporting_Period,
	   1 as Is_Latest,
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
	   CASE WHEN m.Measure_Type IN ('Numerator', 'Denominator', 'Count') THEN CAST(ROUND(m.Measure_Value,0) as FLOAT)
			WHEN m.Measure_Type = 'Percentage' THEN CAST(ROUND(m.Measure_Value,2) as FLOAT)
	   END as Measure_Value,
	   m.[Standard],
	   m.LTP_Trajectory,
	   m.LTP_Trajectory_Percentage_Achieved,
	   m.[Plan],
	   m.Plan_Percentage_Achieved,
	   CASE WHEN e.[Org_Code] IS NOT NULL THEN '-' -- If this row was added in as a missing org then show '-'
			WHEN m.Measure_Type = 'Percentage' THEN FORMAT(m.Measure_Value,'P0')
			WHEN m.Measure_Type IN ('Count','Numerator','Denominator') THEN FORMAT(m.Measure_Value,N'N0') 
	   END as Measure_Value_STR,
	   m.Standard_STR,
	   m.LTP_Trajectory_STR,
	   CAST(NULL as varchar) as LTP_Trajectory_Percentage_Achieved_STR,
	   Plan_STR,
	   CAST(NULL as varchar) as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified

 -- INTO [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]                      --UDAL_Changes
  FROM [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_&_Targets] m

LEFT JOIN [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Missing_Orgs] e
  ON m.Reporting_Period = e.Reporting_Period
 AND m.CDP_Measure_ID = e.CDP_Measure_ID 
 AND m.Org_Type = e.Org_Type
 AND m.Org_Code = e.Org_Code
 AND m.Measure_Type = e.Measure_Type

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 7: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]
 WHERE Org_Code IS NULL

DELETE FROM [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]
 WHERE Region_Code LIKE 'REG%' 
	OR (Org_Type = 'SubICB' 
   AND Org_Code NOT IN (SELECT DISTINCT Organisation_Code FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]  WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))
    OR (Org_Type = 'ICB' AND Org_Code NOT IN (SELECT DISTINCT STP_Code FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]  WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP')) 
	OR (Org_Type = 'Region' AND Org_Code NOT IN (SELECT DISTINCT Region_Code FROM [Reporting_UKHD_ODS].[Commissioner_Hierarchies]  WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

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
		 FROM [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]
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

  FROM [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly] latest

  LEFT JOIN [MHDInternal].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly] previous
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
SELECT Min(Reporting_Period), MAX(Reporting_Period)
 FROM [MHDInternal].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]
WHERE Measure_Value IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 8: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
--PRE-STEPS - METRIC LIST
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Metric_Info]

--STEP 1: WRANGLE THE RAW DATA INTO MASTER DATA TABLE
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Master]
 --Calculate the Denominator, ADD the calculated percentage for Region data for < 2023-03-31 when region data didn't exist in the publication table (aggregated from ICB)
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures]

--STEP 2: REALLOCATIONS
DROP TABLE [MHDInternal].[TEMP_CDP_Reallocations_All_Orgs]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Count_Num_&_Den_No_Change]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den_Changes_From]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocations_Count_Num_&_Den_Changes_Add]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated_Count_Num_&_Den]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated_%]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Reallocated]

--STEP 3: LOOP IN MISSING ICBs and SubICBs
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Org_List]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Org_List_Dates]
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_Missing_Orgs]

--STEP 4: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
DROP TABLE [MHDInternal].[TEMP_CDP_F_NHS_Talking_Therapies_Quarterly_Measures_&_Targets]

