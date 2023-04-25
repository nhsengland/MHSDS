/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UECMH DASHBOARD 

COMMUNITY CRISIS, 24/7 TELEPHONE LINES, PSYCH LIAISON REFERRALS

CREATED BY TOM BARDSLEY 10 NOVEMBER 2020
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- SET REPORTING PERIOD VARIABLES 

DECLARE @RP_START INT
DECLARE @RP_END INT
DECLARE @RP_STARTDATE DATE
DECLARE @RP_ENDDATE DATE
DECLARE @RP_ENDDATE_START DATE

SET @RP_START = 1405 
--SET @RP_START = 1459 -- for testing only 
SET @RP_END = (SELECT MAX(UniqMonthID) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header) 

SET @RP_STARTDATE = (SELECT MIN(ReportingPeriodStartDate) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE UniqMonthID = @RP_START)
SET @RP_ENDDATE = (SELECT MAX(ReportingPeriodEndDate) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE UniqMonthID = @RP_END)
SET @RP_ENDDATE_START = (SELECT MIN(ReportingPeriodStartDate) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE UniqMonthID = @RP_END)



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL REFERRALS TO CRISIS AND LIAISON SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Refs') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Refs

SELECT 
	r.UniqServReqID 
	,r.UniqCareProfTeamID
	,r.Person_ID 
	,r.Der_Pseudo_NHS_Number
	,r.UniqMonthID
	,CASE WHEN r.ReferralRequestReceivedDate >= @RP_ENDDATE_START THEN 'Primary' ELSE NULL END as PrimaryFlag
	,h.ReportingPeriodStartDate
	,h.ReportingPeriodEndDate
	,r.ReferralRequestReceivedDate 
	,r.ReferralRequestReceivedTime 
	,CAST(ISNULL(r.ReferralRequestReceivedTime,'00:00:00') AS datetime) + CAST(r.ReferralRequestReceivedDate AS datetime) AS ReferralRequestReceivedDateTime 
	,CASE WHEN r.ReferralRequestReceivedDate >= @RP_STARTDATE THEN 1 ELSE 0 END as NewRef
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, r.ReferralRequestReceivedDate), 0) AS Ref_MonthYear
	,r.ServDischDate
	,r.OrgIDPRov as Provider_Code 
	,o1.Organisation_Name AS Provider_Name
	,COALESCE(o2.Region_Code,'Missing/Invalid') AS Region_Code  --- regions taken from CCG rather than provider 
	,COALESCE(o2.Region_Name,'Missing/Invalid') AS Region_Name 
	,COALESCE(cc.New_Code,r.OrgIDCCGRes,'Missing/Invalid') AS CCGCode
	,COALESCE(o2.Organisation_Name,'Missing/Invalid') AS [CCG name]
	,COALESCE(o2.STP_Code,'Missing/Invalid') AS STPCode
	,COALESCE(o2.STP_Name,'Missing/Invalid') AS [STP name]
	,CASE 
		WHEN r.ClinRespPriorityType = '1' THEN 'Emergency' 
		WHEN r.ClinRespPriorityType = '2' THEN 'Urgent/Serious' 
		WHEN r.ClinRespPriorityType = '3' THEN 'Routine' 
		WHEN r.ClinRespPriorityType = '4' THEN 'Very Urgent' --- NEW
	ELSE 'Missing/Invalid' END as ClinRespPriority
	,r.ClinRespPriorityType --- (to check v5 changes) 
	,CASE 
		WHEN r.SourceOfReferralMH = 'H1' THEN 'Emergency Department'
		WHEN r.SourceOfReferralMH = 'H2' THEN 'Acute Secondary Care' 
		WHEN r.SourceOfReferralMH IN ('A1','A2','A3','A4') THEN 'Primary Care' 
		WHEN r.SourceOfReferralMH IN ('B1','B2') THEN 'Self' 
		WHEN r.SourceOfReferralMH IN ('E1','E2','E3','E4','E5','E6') THEN 'Justice' 
		WHEN r.SourceOfReferralMH IN ('F1','F2','F3','G1','G2','G3','G4','I1','I2','M1','M2','M3','M4','M5','M6','M7','C1','C2','C3','D1','D2','N3') THEN 'Other'
		WHEN r.SourceOfReferralMH = 'P1' THEN 'Internal' 
		ELSE 'Missing/Invalid'
	END as RefSource
	,CASE 
		WHEN r.SourceOfReferralMH = 'H1' THEN 'Emergency Department'
		WHEN r.SourceOfReferralMH = 'H2' THEN 'Acute Secondary Care' 
		ELSE 'Other' 
	END as RefSourceSimplified
	,CASE 
		WHEN r.AgeServReferRecDate BETWEEN 0 AND 17 THEN '0-17'
		WHEN r.AgeServReferRecDate BETWEEN 18 AND 64 THEN '18-64' 
		WHEN r.AgeServReferRecDate >=65 THEN '65+' 
		ELSE 'Missing/Invalid' 
	END as AgeCat
	,r.ServTeamTypeRefToMH
	,ISNULL(o5.Main_Description,'Missing/Invalid') AS TeamType
	,CASE 
		WHEN r.ServTeamTypeRefToMH IN ('A02','A03','A04','A19','A18') THEN 'NHS Crisis Services' --- CRT, HTT, CR/HTT, 24/7 response line, SPA
		WHEN r.ServTeamTypeRefToMH IN ('A20','A21','A24','A25','A23') THEN 'Other Crisis Services' --- HBPoS, Crisis Cafes, Acute Day Service, Crisis Houses, Psychiatric Decision Unit
		WHEN r.ServTeamTypeRefToMH IN ('A11','C05') THEN 'Liaison Psychiatry' --- Liaison Psych, Paed Liaison Psych
		WHEN r.ServTeamTypeRefToMH IN ('A22') THEN 'Other Hospital-Based Crisis Services' -- Walk-in Crisis Assessment Unit
	END as TeamTypeCat
	,r.PrimReasonReferralMH
	,ROW_NUMBER()OVER(PARTITION BY r.Person_ID, r.UniqServreqID ORDER BY r.UniqMonthID DESC) AS Ref_RN

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Refs

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r 

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o1 ON r.OrgIDProv = o1.Organisation_Code 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON r.OrgIDCCGRes = cc.Org_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies o2 ON COALESCE(cc.New_Code,r.OrgIDCCGRes) = o2.Organisation_Code

LEFT JOIN NHSE_UKHF.Data_Dictionary.vw_Service_Or_Team_Type_For_Mental_Health_SCD o5 ON r.ServTeamTypeRefToMH COLLATE DATABASE_DEFAULT = o5.Main_Code_Text COLLATE DATABASE_DEFAULT AND o5.Effective_To IS NULL AND o5.Valid_To IS NULL 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON r.UniqMonthID = h.UniqMonthID 

WHERE  r.UniqMonthID BETWEEN @RP_START AND @RP_END --- get referrals for each Month ID to calculate active refs per month
AND r.ReferralRequestReceivedDate >= @RP_STARTDATE
AND r.ReferRejectionDate IS NULL --- only accpeted referrals 
AND r.ServTeamTypeRefToMH IN ('A02','A03','A04','A11','A18','A19','A20','A21','A22','A23','A24','A25','C05') --- relevant crisis teams
AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL)  --- English pts only 




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET FIRST F2F AND FIRST DIRECT CONTACT FOR NEW REFERRALS AND CALCULATE RESPONSE TIME 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_FirstCont') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_FirstCont

SELECT
	r.UniqServReqID
	,r.Person_ID
	,r.Provider_Name
	,r.ReferralRequestReceivedDate
	,r.ReferralRequestReceivedDateTime
	,MIN(CAST(ISNULL(a1.Der_ContactTime,'00:00:00') AS datetime) + CAST(a1.Der_ContactDate  AS datetime)) AS F2F_ContactDateTime
	,MIN(CAST(ISNULL(a2.Der_ContactTime,'00:00:00') AS datetime) + CAST(a2.Der_ContactDate  AS datetime)) AS DirectF_ContactDateTime

INTO  NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_FirstCont

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Refs r 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a1 ON r.Person_ID = a1.Person_ID AND r.UniqServReqID = a1.UniqServReqID AND a1.Der_FacetoFaceContact = 1 --- F2F contacts
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a2 ON r.Person_ID = a2.Person_ID AND r.UniqServReqID = a2.UniqServReqID AND a2.Der_DirectContact = 1 --- direct care contacts
	
WHERE r.Ref_RN = 1 

GROUP BY r.UniqServReqID, r.Person_ID, r.Provider_Name, r.ReferralRequestReceivedDate, r.ReferralRequestReceivedDateTime 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
SUMMARISE ADMISSIONS AND ATTENDANCES FOR ACTIVE REFERRALS,
FLAG NEW REFERRALS AND ADD RESPONSE TIMES 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Master') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Master

SELECT 
	r.UniqServReqID 
	,r.Person_ID 
	,r.Der_Pseudo_NHS_Number
	,r.UniqMonthID
	,r.PrimaryFlag
	,r.ReportingPeriodStartDate
	,r.ReportingPeriodEndDate
	,r.ReferralRequestReceivedDate 
	,r.ReferralRequestReceivedTime 
	,r.ReferralRequestReceivedDateTime 
	,r.NewRef
	,r.Ref_MonthYear
	,r.Provider_Code 
	,r.Provider_Name
	,r.Region_Code 
	,r.Region_Name 
	,r.CCGCode
	,r.[CCG name]
	,r.STPCode
	,r.[STP name]
	,o.Region_Code AS Prov_Region_Code --- add in STP and region derived from provider (for regional summary) 
	,o.Region_Name AS Prov_Region_Name
	,o.STP_Code AS Prov_STP_Code
	,o.STP_Name AS Prov_STP_Name
	,r.ClinRespPriority
	,r.RefSource 
	,r.RefSourceSimplified
	,r.AgeCat
	,r.TeamType
	,r.TeamTypeCat
	,f.DirectF_ContactDateTime
	,DATEDIFF(MINUTE, r.ReferralRequestReceivedDateTime, f.DirectF_ContactDateTime) AS Direct_RespTime
	,f.F2F_ContactDateTime
	,DATEDIFF(MINUTE, r.ReferralRequestReceivedDateTime, f.F2F_ContactDateTime) AS F2F_RespTime

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Master

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Refs r 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_FirstCont f ON r.UniqServReqID = f.UniqServReqID AND r.Person_ID = f.Person_ID 

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o ON r.Provider_Code = o.Organisation_Code
		
WHERE  r.Ref_RN = 1 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET NEW DROP-IN CONTACTS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#DropInContacts') IS NOT NULL
DROP TABLE #DropInContacts

SELECT 
	d.MHS302UniqID
	,d.UniqMonthID
	,d.CareContactDateMHDropInContact
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, d.CareContactDateMHDropInContact), 0) AS Activity_MonthYear
	,CASE WHEN d.UniqMonthID = @RP_END THEN 'Y' ELSE NULL END AS PrimaryFlag
	,d.StartTimeDropInContact
	,d.EndTimeDropInContact
	,d.OrgIDProv
	,o1.Organisation_Name AS Provider_Name
	,o1.STP_Code AS Prov_STPCode 
	,o1.STP_Name AS Prov_STPName 
	,o1.Region_Code AS Prov_RegionCode 
	,o1.Region_Name AS Prov_RegionName
	,d.Der_Age_at_CareContactDateMHDropInContact 
	,CASE 
		WHEN d.Der_Age_at_CareContactDateMHDropInContact BETWEEN 0 AND 17 THEN '0-17'
		WHEN d.Der_Age_at_CareContactDateMHDropInContact BETWEEN 18 AND 64 THEN '18-64' 
		WHEN d.Der_Age_at_CareContactDateMHDropInContact >=65 THEN '65+' 
		ELSE 'Missing/Invalid' 
	END as AgeCat
	,d.MHDropInContactServiceType
	,CASE WHEN d.MHDropInContactServiceType = 'A19' THEN 'NHS Crisis Services' WHEN d.MHDropInContactServiceType = 'A21' THEN 'Other Crisis Services' END AS TeamTypeCat 
	,CASE WHEN d.MHDropInContactServiceType = 'A19' THEN '24/7 Crisis Response Line'  WHEN d.MHDropInContactServiceType = 'A21' THEN 'Crisis Café/Safe Haven/Sanctuary Service'  END AS TeamType
	,d.ConsMechanismMH
	,CASE 
		WHEN d.ConsMechanismMH = '01' THEN 'Face to face' 
		WHEN d.ConsMechanismMH = '02' THEN 'Telephone' 
		WHEN d.ConsMechanismMH IN ('03','11') THEN 'Video consultation / telemedicine' 
		WHEN d.ConsMechanismMH IN ('04','05','06','09','10','12','13','98') THEN 'Other' 
		ELSE 'Missing/invalid' 
	END AS Cons_mechanism_type

INTO #DropInContacts 

FROM NHSE_MHSDS.dbo.MHS302MHDropInContact d 
INNER JOIN NHSE_MHSDS.dbo.MHSDS_SubmissionFlags f ON d.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_Use_Submission_Flag = 'Y' 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o1 ON d.OrgIDProv = o1.Organisation_Code
WHERE d.MHDropInContactServiceType IN ('A19','A21')  
AND d.UniqMonthID BETWEEN @RP_START AND @RP_END 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL CRISIS CONTACTS - INCLUDING DROP-IN CONTACTS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Contacts') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Contacts

SELECT 
	a.ReportingPeriodStartDate AS ReportingPeriod
	,CASE WHEN a.UniqMonthID = @RP_END THEN 'Y' ELSE NULL END AS PrimaryFlag 
	,r.Provider_Code
	,r.Provider_Name
	,r.CCGCode
	,r.[CCG name]
	,r.STPCode
	,r.[STP name]
	,r.Region_Code
	,r.Region_Name
	,o.Region_Code AS Prov_Region_Code --- add in STP and region derived from provider (for regional summary) 
	,o.Region_Name AS Prov_Region_Name
	,o.STP_Code AS Prov_STP_Code
	,o.STP_Name AS Prov_STP_Name
	,r.TeamTypeCat
	,r.TeamType
	,r.AgeCat
	,a.Der_ActivityType
	,CASE 
		WHEN a.ConsMediumUsed = '01' THEN 'Face to face' 
		WHEN a.ConsMediumUsed = '02' THEN 'Telephone' 
		WHEN a.ConsMediumUsed IN ('03','11') THEN 'Video consultation / telemedicine' 
		WHEN a.ConsMediumUsed IN ('04','05','06','09','10','12','13','98') THEN 'Other' 
		ELSE 'Missing/invalid' 
	END AS Cons_mechanism_type
	,COUNT(*) AS Contacts 

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Contacts

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a 

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Refs r ON a.UniqServReqID = r.UniqServReqID AND a.Person_ID = r.Person_ID AND a.Der_UniqCareProfTeamID = r.UniqCareProfTeamID 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o ON r.Provider_Code = o.Organisation_Code

WHERE r.Ref_RN = 1 AND a.Der_ActivityType = 'DIRECT' AND a.AttendOrDNACode IN ('5','6') --- only attended, direct contacts (any cons medium)

GROUP BY a.UniqMonthID, a.ReportingPeriodStartDate, 
r.Provider_Code, r.Provider_Name, r.CCGCode, r.[CCG name], r.STPCode, r.[STP name], r.Region_Code, r.Region_Name, 
o.Region_Code, o.Region_Name, o.STP_Code, o.STP_Name,
r.TeamTypeCat, r.TeamType, r.AgeCat, a.Der_ActivityType, a.ConsMediumUsed 

UNION ALL 

SELECT 
	d.Activity_MonthYear AS ReportingPeriod 
	,d.PrimaryFlag
	,d.OrgIDProv AS Provider_Code 
	,d.Provider_Name
	,'Missing/invalid' AS CCGCode --- not linked to people so can't get CCG/STP/Region of residence 
	,'Missing/invalid' AS [CCG name] 
	,'Missing/invalid' AS STPCode 
	,'Missing/invalid' AS [STP Name] 
	,'Missing/invalid' AS Region_Code 
	,'Missing/invalid' AS Region_Name 
	,d.Prov_RegionCode 
	,d.Prov_RegionName
	,d.Prov_STPCode
	,d.Prov_STPName
	,d.TeamTypeCat
	,d.TeamType
	,d.AgeCat
	,'DROP-IN' AS Der_Activity_Type 
	,d.Cons_mechanism_type
	,COUNT(*) AS Contacts 
FROM #DropInContacts d 
GROUP BY d.Activity_MonthYear, d.PrimaryFlag, d.OrgIDProv, d.Provider_Name, d.Prov_RegionCode, d.Prov_RegionName, d.Prov_STPCode, d.Prov_STPName, d.TeamTypeCat, d.TeamType, d.AgeCat, d.Cons_mechanism_type 




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE FOR NEW REFERRALS (BASED ON REF START MONTH)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_AggNewRefs') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_AggNewRefs

SELECT 
	Ref_MonthYear AS ReportingPeriod 
	,PrimaryFlag
	,Provider_Code
	,Provider_Name
	,CCGCode
	,[CCG name]
	,STPCode
	,[STP name]
	,Region_Code
	,Region_Name
	,Prov_Region_Code
	,Prov_Region_Name
	,Prov_STP_Code
	,Prov_STP_Name
	,TeamTypeCat
	,TeamType
	,ClinRespPriority 
	,RefSourceSimplified --- used to reduce number of rows 
	,AgeCat
	,SUM(NewRef) AS NewRefs 
	,SUM(CASE WHEN Direct_RespTime IS NOT NULL THEN 1 ELSE 0 END) as Direct_Contact 
	,SUM(CASE WHEN F2F_RespTime IS NOT NULL THEN 1 ELSE 0 END) as F2F_Contact 
	,SUM(CASE WHEN F2F_RespTime IS NOT NULL AND F2F_RespTime <= 60 THEN 1 ELSE 0 END) F2F_1hr
	,SUM(CASE WHEN F2F_RespTime IS NOT NULL AND F2F_RespTime <= (60*4) THEN 1 ELSE 0 END) F2F_4hr
	,SUM(CASE WHEN F2F_RespTime IS NOT NULL AND F2F_RespTime <= (60*24) THEN 1 ELSE 0 END) F2F_24hr

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_AggNewRefs

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Master

GROUP BY Ref_MonthYear, PrimaryFlag, Provider_Code, Provider_Name, CCGCode, [CCG name], STPCode, [STP name], Region_Code, Region_Name, TeamTypeCat, TeamType, ClinRespPriority, RefSourceSimplified, AgeCat,
Prov_Region_Code, Prov_Region_Name, Prov_STP_Code, Prov_STP_Name


 
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ADD RELEVANT DENOMINATORS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Denom_NewRefs') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Denom_NewRefs

SELECT 
	ReportingPeriod
	,PrimaryFlag
	,Provider_Code
	,Provider_Name
	,CCGCode
	,[CCG name]
	,STPCode
	,[STP name]
	,Region_Code
	,Region_Name
	,Prov_Region_Code
	,Prov_Region_Name
	,Prov_STP_Code
	,Prov_STP_Name
	,TeamTypeCat
	,TeamType
	,ClinRespPriority
	,RefSourceSimplified
	,AgeCat
	,NewRefs
	,F2F_Contact  
	,Direct_Contact
	,F2F_1hr
	,F2F_4hr
	,F2F_24hr
	-- denominators
	,NewRefs as Denom_contact
	,F2F_Contact as Denom_resp_times

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Denom_NewRefs

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_AggNewRefs a


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT TO PRODUCE FINAL OUTPUT 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Output') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Output

SELECT 
	ReportingPeriod
	,PrimaryFlag
	,Provider_Code
	,Provider_Name
	,CCGCode
	,[CCG name]
	,STPCode
	,[STP name]
	,Region_Code
	,Region_Name
	,Prov_Region_Code
	,Prov_Region_Name
	,Prov_STP_Code
	,Prov_STP_Name
	,TeamTypeCat
	,TeamType
	,ClinRespPriority
	,RefSourceSimplified
	,AgeCat
	,MeasureName
	,MeasureValue
	,CASE
		WHEN MeasureName IN ('F2F_Contact', 'Direct_Contact') THEN Denom_contact 
		WHEN MeasureName IN ('F2F_RespTime','F2F_1hr','F2F_4hr','F2F_24hr') THEN Denom_resp_times
	END as Denominator 

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Output

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Denom_NewRefs

UNPIVOT (MeasureValue FOR MeasureName IN 
		(NewRefs, F2F_Contact, Direct_Contact, F2F_1hr, F2F_4hr, F2F_24hr)) u 


--DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Dashboard_UEC_MHSDS
--SELECT * 
--INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_UEC_MHSDS
--FROM NHSE_Sandbox_MentalHealth.dbo.Temp_UEMH_Output 


