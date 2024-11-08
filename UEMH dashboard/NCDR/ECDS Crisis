/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UECMH DASHBOARD 

ECDS ANALYSIS 

CREATED BY TOM BARDSLEY 11 NOVEMBER 2020
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- SET REPORTING PERIOD VARIABLES 
DECLARE @RP_STARTDATE DATE
SET @RP_STARTDATE = '2019-04-01' 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL ATTENDANCES FROM ECDS IN TYPE 1 EDs
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_ECDS') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_ECDS

SELECT 
	a.Generated_Record_ID
	,a.Der_Pseudo_NHS_Number
	,a.Der_Provider_Code 
	,COALESCE(o1.Organisation_Name,'Missing/Invalid') AS Der_Provider_Name
	,a.Der_Provider_Site_Code 
	,COALESCE(o2.Organisation_Name,'Missing/Invalid') AS Der_Provider_Site_Name
	,COALESCE(o3.Region_Code,'Missing/Invalid') AS Region_Code --- regions taken from CCG of provider rather than CCG of residence
	,COALESCE(o3.Region_Name,'Missing/Invalid') AS Region_Name
	,COALESCE(cc.New_Code,a.Attendance_HES_CCG_From_Treatment_Site_Code,'Missing/Invalid') AS CCGCode
	,COALESCE(o3.Organisation_Name,'Missing/Invalid') AS [CCG name]
	,COALESCE(o3.STP_Code,'Missing/Invalid') AS STPCode
	,COALESCE(o3.STP_Name,'Missing/Invalid') AS [STP name]
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, Arrival_Date), 0) MonthYear
	,a.Arrival_Date 
	,DATEPART(HOUR, a.Arrival_Time) as Arrival_Hour 
	,CASE WHEN a.Arrival_Time >= '17:00:00' OR a.Arrival_Time < '09:00:00' THEN 1 ELSE 0 END as OutofHours -- added out of hours flag (the same for weekdays, weekends or bank holidays)
	,DATEPART(WEEKDAY, a.Arrival_Date) AS Arrival_DW
	,CAST(ISNULL(a.Arrival_Time,'00:00:00') AS datetime) + CAST(a.Arrival_Date AS datetime) AS ArrivalDateTime
	,a.EC_Departure_Date 
	,a.EC_Departure_Time
	,CAST(ISNULL(a.EC_Departure_Time,'00:00:00') AS datetime) + CAST(a.EC_Departure_Date AS datetime) AS DepartureDateTime
	,a.EC_Departure_Time_Since_Arrival
	,a.EC_Initial_Assessment_Time_Since_Arrival
	,a.EC_Chief_Complaint_SNOMED_CT
	,c.ChiefComplaintDescription
	,a.EC_Injury_Intent_SNOMED_CT
	,i.InjuryIntentDescription
	,a.Der_EC_Diagnosis_All
	,COALESCE(LEFT(a.Der_EC_Diagnosis_All, NULLIF(CHARINDEX(',',a.Der_EC_Diagnosis_All),0)-1),a.Der_EC_Diagnosis_All) AS PrimaryDiagnosis
	,d.DiagnosisDescription
	,a.Age_At_Arrival 
	,CASE 
		WHEN a.Age_At_Arrival BETWEEN 0 AND 11 THEN '0-11'  
		WHEN a.Age_At_Arrival BETWEEN 12 AND 17 THEN '12-17'
		WHEN a.Age_At_Arrival BETWEEN 18 AND 25 THEN '18-25'
		WHEN a.Age_At_Arrival BETWEEN 26 AND 64 THEN '26-64' 
		WHEN a.Age_At_Arrival >= 65 THEN '65+' 
		ELSE 'Missing/Invalid' 
	END as AgeCat 
	,CASE WHEN ChiefComplaintDescription IS NOT NULL THEN 1 ELSE 0 END as Val_ChiefComplaint --- NOTE: check these are aligned with other ECDS DQ reporting !!
	,CASE WHEN a.EC_Injury_Date IS NOT NULL THEN 1 ELSE 0 END as InjuryFlag
	,CASE WHEN a.EC_Injury_Date IS NOT NULL AND InjuryIntentDescription IS NOT NULL THEN 1 ELSE 0 END as Val_InjuryIntent
	,CASE WHEN DiagnosisDescription IS NOT NULL THEN 1 ELSE 0 END as Val_Diagnosis
	,CASE 
			WHEN EC_Chief_Complaint_SNOMED_CT IN ('248062006' --- self harm
				,'272022009' --- depressive feelings 
				,'48694002' --- feeling anxious 
				,'248020004' --- behaviour: unsual 
				,'6471006' -- feeling suicidal
				,'7011001') THEN 1  --- hallucinations/delusions 
			WHEN EC_Injury_Intent_SNOMED_CT = '276853009' THEN 1 --- self inflicted injury 
			WHEN COALESCE(LEFT(Der_EC_Diagnosis_All, NULLIF(CHARINDEX(',',Der_EC_Diagnosis_All),0)-1),Der_EC_Diagnosis_All) 
				IN ('52448006' --- dementia
				,'2776000' --- delirium 
				,'33449004' --- personality disorder
				,'72366004' --- eating disorder
				,'197480006' --- anxiety disorder
				,'35489007' --- depressive disorder
				,'13746004' --- bipolar affective disorder
				,'58214004' --- schizophrenia
				,'69322001' --- psychotic disorder
				,'397923000' --- somatisation disorder
				,'30077003' --- somatoform pain disorder
				,'44376007' --- dissociative disorder
				,'17226007' ---- adjustment disorder
				,'50705009') THEN 1 ---- factitious disorder
		ELSE 0 
		END as MH_Flag 
	,CASE 
		WHEN EC_Injury_Intent_SNOMED_CT = '276853009' THEN 1
		WHEN EC_Chief_Complaint_SNOMED_CT = '248062006' THEN 1
		ELSE 0 
	END as SelfHarm_Flag
	,a.Discharge_Destination_SNOMED_CT
	,a.EC_Arrival_Mode_SNOMED_CT
	
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_ECDS

FROM [NHSE_SUSPlus_Live].[dbo].[tbl_Data_SUS_EC] a

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_DataDic_ECDS_Chief_Complaint] c ON c.ChiefComplaintCode = a.EC_Chief_Complaint_SNOMED_CT

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_DataDic_ECDS_Injury_Intent] i ON i.InjuryIntentCode = a.EC_Injury_Intent_SNOMED_CT

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_DataDic_ECDS_Diagnosis] d ON COALESCE(LEFT(a.Der_EC_Diagnosis_All, NULLIF(CHARINDEX(',',a.Der_EC_Diagnosis_All),0)-1),a.Der_EC_Diagnosis_All) = d.DiagnosisCode 

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o1 ON a.Der_Provider_Code = o1.Organisation_Code --- providers 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o2 ON a.Der_Provider_Site_Code = o2.Organisation_Code --- sites
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON a.Attendance_HES_CCG_From_Treatment_Site_Code = cc.Org_Code 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies o3 ON COALESCE(cc.New_Code,a.Attendance_HES_CCG_From_Treatment_Site_Code) = o3.Organisation_Code --- CCG / STP / Region 

WHERE Der_Dupe_Flag = 0 
AND a.EC_Department_Type = '01' --- Type 1 EDs only 
AND a.Arrival_Date >= @RP_STARTDATE

AND (EC_Discharge_Status_SNOMED_CT IS NULL OR EC_Discharge_Status_SNOMED_CT  NOT IN ('1077031000000103','1077781000000101', '63238001')) --exclude streamed and Dead on arrival
AND ([EC_AttendanceCategory] IS NULL OR [EC_AttendanceCategory] in ('1','2','3'))   --exclude follow ups and Dead on arrival

AND  o3.Region_Name <> 'WALES' 

AND a.EC_Departure_Date < GetDate() -- remove attendances that depart in the future


 /*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 IDENTIFIER MH ATTENDANCES FOR FREQUENT ATTENDERS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_FA') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_FA

SELECT 
	a.Der_Pseudo_NHS_Number
	,a.Generated_Record_ID
	,COUNT(*) AS PrevAttendances 

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_FA

FROM  NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_ECDS a 

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_ECDS b ON a.Der_Pseudo_NHS_Number = b.Der_Pseudo_NHS_Number -- same person 
	AND b.ArrivalDateTime < a.ArrivalDateTime -- previous attendances 
	AND DATEDIFF(DD, b.ArrivalDateTime, a.ArrivalDateTime) BETWEEN 0 AND 364  --- last 12 months 

WHERE a.Der_Pseudo_NHS_Number IS NOT NULL 
AND a.MH_Flag = 1 

GROUP BY a.Der_Pseudo_NHS_Number, a.Generated_Record_ID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 IDENTIFY ATTENDANCES FOR 'KNOWN' TO MH SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_MHSDS') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_MHSDS

SELECT 
	e.Generated_Record_ID
	,MAX(a.Der_ContactDate)AS LatestContact 

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_MHSDS

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_ECDS e  

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r ON e.Der_Pseudo_NHS_Number = r.Der_Pseudo_NHS_Number
INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON a.RecordNumber = r.RecordNumber AND a.Der_Contact = 1 

WHERE a.Der_Contact < e.Arrival_Date
AND DATEDIFF(DD, a.Der_ContactDate, e.Arrival_Date) BETWEEN 0 AND 179 -- in last 6 months 

GROUP BY e.Generated_Record_ID


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CLEAN PROVIDER SITE NAMES 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Sites') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Sites

SELECT
	e.Generated_Record_ID
	,e.Der_Pseudo_NHS_Number
	,e.Der_Provider_Code 
	,e.Der_Provider_Name
	,e.Der_Provider_Site_Code 
	,CASE 
		WHEN e.Der_Provider_Site_Name = 'Missing/Invalid' THEN 'Missing/Invalid' 
		ELSE e.Der_Provider_Site_Code
	END as Der_Provider_Site_Code_cleaned
	,e.Der_Provider_Site_Name
	,CASE 
		WHEN Der_Provider_Site_Name = 'Missing/Invalid' THEN CONCAT(Der_Provider_Name,':',' ','missing site name') 
		ELSE Der_Provider_Site_Name 
	END as Der_Provider_Site_Name_cleaned
	,e.Region_Code --- regions taken from CCG rather than provider 
	,e.Region_Name
	,CCGCode
	,[CCG name]
	,STPCode
	,[STP name]
	,MonthYear
	,e.Arrival_Date 
	,ArrivalDateTime
	,Arrival_Hour
	,OutofHours
	,Arrival_DW
	,EC_Departure_Date 
	,EC_Departure_Time
	,DepartureDateTime
	,EC_Departure_Time_Since_Arrival
	,EC_Initial_Assessment_Time_Since_Arrival
	,EC_Chief_Complaint_SNOMED_CT
	,ChiefComplaintDescription
	,EC_Injury_Intent_SNOMED_CT
	,InjuryIntentDescription
	,Der_EC_Diagnosis_All
	,PrimaryDiagnosis
	,DiagnosisDescription
	,Age_At_Arrival 
	,AgeCat 
	,Val_ChiefComplaint
	,InjuryFlag
	,Val_InjuryIntent
	,Val_Diagnosis
	,MH_Flag 
	,SelfHarm_Flag 
	,CASE 
		WHEN Discharge_Destination_SNOMED_CT IN ('306689006','306691003','306694006','306705005','50861005') THEN 'Discharged'
		WHEN Discharge_Destination_SNOMED_CT IN ('1066331000000109','1066341000000100','1066351000000102') THEN 'Ambulatory/short stay' 
		WHEN Discharge_Destination_SNOMED_CT IN ('306706006','1066361000000104','1066371000000106','1066381000000108','1066391000000105','1066401000000108') THEN 'Admitted' 
		WHEN Discharge_Destination_SNOMED_CT IN ('19712007','183919006') THEN 'Transfered'
		WHEN Discharge_Destination_SNOMED_CT = '305398007' THEN 'Died' 
		ELSE 'Missing/invalid' 
	END AS Der_DischargeDestination 
	,CASE 
		WHEN EC_Arrival_Mode_SNOMED_CT IN ('1048071000000103','1048061000000105') THEN 'Own/public transport' 
		WHEN EC_Arrival_Mode_SNOMED_CT IN ('1048031000000100','1048041000000109','1048021000000102','1048051000000107','1048081000000101') THEN 'Ambulance' 
		WHEN EC_Arrival_Mode_SNOMED_CT IN ('1047991000000102','1048001000000106') THEN 'Police/justice' 
		ELSE 'Missing/invalid'
	END AS Der_ArrivalMode
	,ISNULL(f.PrevAttendances,0) AS PrevAttendances --- in past 12 months 
	,m.LatestContact AS Latest_MH_Contact --- in past 6 months 

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Sites

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_ECDS e 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_FA f ON e.Generated_Record_ID = f.Generated_Record_ID 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_MHSDS m ON e.Generated_Record_ID = m.Generated_Record_ID 



 /*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE TO GET ACCESS AND WAITING TIME METRICS
NB: EXCLUDE THOSE OVER 24HRS FROM WAITING TIMES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Agg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Agg

SELECT 
	MonthYear
	,Der_Provider_Site_Code_cleaned
	,Der_Provider_Site_Name_cleaned
	,Der_Provider_Code
	,Der_Provider_Name
	,CCGCode
	,[CCG name]
	,STPCode
	,[STP name]
	,Region_Code
	,Region_Name
	,AgeCat
	,OutOfHours
	,Der_ArrivalMode
	,Der_DischargeDestination
	,COUNT(*) as ED_Attendances
	,SUM(Val_ChiefComplaint) as Val_ChiefComplaint
	,SUM(Val_Diagnosis) as Val_Diagnosis
	,SUM(InjuryFlag) as InjuryFlag
	,SUM(Val_InjuryIntent) as Val_InjuryIntent
	,SUM(MH_Flag) as MH_attendances
	,SUM(SelfHarm_Flag) as SelfHarm_Attendances
	,SUM(CASE WHEN MH_Flag = 1 AND EC_Departure_Time_Since_Arrival > (60*6) THEN 1 ELSE 0 END) as MH_Breach6hrs 
	,SUM(CASE WHEN MH_Flag = 1 AND EC_Departure_Time_Since_Arrival > (60*6) THEN EC_Departure_Time_Since_Arrival - (60*6) ELSE 0 END) AS MH_APD_6hrs
	,SUM(CASE WHEN MH_Flag = 1 AND EC_Departure_Time_Since_Arrival > (60*12) THEN 1 ELSE 0 END) as MH_Breach12hrs 
	,SUM(CASE WHEN MH_Flag = 1 AND EC_Departure_Time_Since_Arrival > (60*12) THEN EC_Departure_Time_Since_Arrival - (60*12) ELSE 0 END) AS MH_APD_12hrs

	,SUM(CASE WHEN EC_Departure_Time_Since_Arrival > (60*12) THEN 1 ELSE 0 END) as All_Breach12hrs 
	
	--- New measures 
	,SUM(CASE WHEN PrevAttendances >= 4 THEN 1 ELSE 0 END) AS MH_FrequentAttendance
	,SUM(CASE WHEN Latest_MH_Contact IS NOT NULL THEN MH_Flag ELSE 0 END) AS Known_to_MH

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Agg 

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Sites 

GROUP BY MonthYear, Der_Provider_Site_Code_cleaned, Der_Provider_Site_Name_cleaned, Der_Provider_Code, Der_Provider_Name, CCGCode, [CCG name], STPCode, [STP name], Region_Code, Region_Name, AgeCat, OutOfHours, Der_DischargeDestination, Der_ArrivalMode


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ADD RELEVANT DENOMINATORS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Denoms') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Denoms

SELECT 
	MonthYear
	,Der_Provider_Site_Code_cleaned
	,Der_Provider_Site_Name_cleaned
	,Der_Provider_Code
	,Der_Provider_Name
	,CCGCode
	,[CCG name]
	,STPCode
	,[STP name]
	,Region_Code
	,Region_Name
	,AgeCat
	,OutOfHours
	,Der_ArrivalMode
	,Der_DischargeDestination
	,ED_Attendances
	,ED_Attendances AS ED_Attendances_denom --- to be used as denom for ALL mean time, % over 6hrs, % over 12hrs
	,Val_ChiefComplaint
	,Val_Diagnosis
	,Val_InjuryIntent
	,MH_attendances
	,MH_attendances AS MH_attendances_denom --- to be used as denom for mean time, % over 6hrs, % over 12 hrs
	,SelfHarm_Attendances
	,MH_Breach6hrs
	,MH_Breach12hrs
	,All_Breach12hrs
	,CAST(MH_APD_6hrs as INT) as MH_APD_6hrs
	,CAST(MH_APD_12hrs as INT) as MH_APD_12hrs
	,MH_FrequentAttendance
	,Known_to_MH
	,InjuryFlag AS Denom_InjuryFlag ---- for % injury intent
	,MH_Breach6hrs AS Denom_MH_Breach6hrs --- for MH 6hr APD
	,MH_Breach12hrs AS Denom_MH_Breach12hrs --- for MH 12hr APD
	
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Denoms

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Agg a



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT FOR FINAL OUTPUT 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Output') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Output
 
SELECT 
	MonthYear
	,Der_Provider_Site_Code_cleaned
	,Der_Provider_Site_Name_cleaned
	,Der_Provider_Code
	,Der_Provider_Name
	,CCGCode
	,[CCG name]
	,STPCode
	,[STP name]
	,Region_Code
	,Region_Name
	,AgeCat
	,OutOfHours
	,Der_ArrivalMode
	,Der_DischargeDestination
	,MeasureName 
	,MeasureValue 
	,CASE 
		WHEN MeasureName IN ('MH_attendances','SelfHarm_Attendances','Val_ChiefComplaint','Val_Diagnosis','All_Breach12hrs') THEN ED_Attendances_denom 
		WHEN MeasureName = 'Val_InjuryIntent' THEN Denom_InjuryFlag
		WHEN MeasureName IN ('MH_Breach6hrs','MH_Breach12hrs','MH_FrequentAttendance','Known_to_MH') THEN MH_attendances_denom 
		WHEN MeasureName = 'MH_APD_6hrs' THEN Denom_MH_Breach6hrs
		WHEN MeasureName = 'MH_APD_12hrs' THEN Denom_MH_Breach12hrs
	END as Denominator 

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Output

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Denoms 

UNPIVOT (MeasureValue FOR MeasureName IN 
		(ED_Attendances, MH_attendances, SelfHarm_Attendances, Val_ChiefComplaint, Val_Diagnosis, All_Breach12hrs,
		Val_InjuryIntent,
		MH_Breach6hrs, MH_Breach12hrs, MH_FrequentAttendance, Known_to_MH,
		MH_APD_6hrs,
		MH_APD_12hrs)) u 






DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Dashboard_UEC_ECDS 
SELECT * 
INTO  NHSE_Sandbox_MentalHealth.dbo.Dashboard_UEC_ECDS 
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Output


--SELECT 'DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo]."' + TABLE_NAME + '"'
--FROM INFORMATION_SCHEMA.TABLES
--WHERE TABLE_NAME LIKE 'Temp_UEMH%'




