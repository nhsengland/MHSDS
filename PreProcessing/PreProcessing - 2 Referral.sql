
DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @ReportingPeriodEnd = (SELECT MAX(ReportingPeriodEndDate) FROM NHSE_MH_PrePublication.dbo.V4_MHS000Header WHERE UniqMonthID = @EndRP) 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP TWO - REFERRALS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - DROP EXISTING INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Drop Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DROP INDEXES

DROP INDEX ix_Referral ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral]

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Drop Index End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - DELETE PRIMARY DATA FROM LAST MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Delete Primary Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] WHERE UniqMonthID = @EndRP

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Delete Primary Data End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - JOIN MHS001 AND MHS102 TO MHS101 						
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - PERFORMANCE AND PRIMARY DATA

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] 

SELECT
	r.[MHS101UniqID],
    r.[Person_ID],
    r.[OrgIDProv],
    r.[UniqMonthID],
    r.[RecordNumber],
    r.[UniqServReqID],
    r.[OrgIDComm],
    r.[ReferralRequestReceivedDate],
    r.[ReferralRequestReceivedTime],
    r.[NHSServAgreeLineNum],
    r.[SpecialisedMHServiceCode],
    r.[SourceOfReferralMH],
    r.[OrgIDReferring],
    r.[ReferringCareProfessionalStaffGroup],
    r.[ClinRespPriorityType],
    r.[PrimReasonReferralMH],
    r.[ReasonOAT],
    r.[DischPlanCreationDate],
    r.[DischPlanCreationTime],
    r.[DischPlanLastUpdatedDate],
    r.[DischPlanLastUpdatedTime],
    r.[ServDischDate],
    r.[ServDischTime],
    r.[DischLetterIssDate],
    r.[AgeServReferRecDate],
    r.[AgeServReferDischDate],
    r.[RecordStartDate],
    r.[RecordEndDate],
    r.[InactTimeRef],
    m.[MHS001UniqID],
    m.[OrgIDCCGRes],
    m.[OrgIDEduEstab],
    m.[EthnicCategory],
    m.[NHSDEthnicity],
    m.[Gender],
    m.[MaritalStatus],
    m.[PersDeathDate],
    m.[AgeDeath],
    m.[LanguageCodePreferred],
    m.[ElectoralWard],
    m.[LADistrictAuth],
    m.[LSOA2011],
    m.[County],
    m.[NHSNumberStatus],
    m.[OrgIDLocalPatientId],
    m.[OrgIDResidenceResp],
    m.[PostcodeDistrict],
    m.[DefaultPostcode],
    m.[AgeRepPeriodStart],
    m.[AgeRepPeriodEnd],
    m.[Der_Pseudo_NHS_Number],
    s.[MHS102UniqID],
    s.[UniqCareProfTeamID],
    s.[ServTeamTypeRefToMH],
    s.[CAMHSTier],
    s.[ReferRejectionDate],
    s.[ReferRejectionTime],
    s.[ReferRejectReason],
    s.[ReferClosureDate],
    s.[ReferClosureTime],
    s.[ReferClosReason],
    s.[AgeServReferClosure],
    s.[AgeServReferRejection],
	CASE WHEN r.ServDischDate IS NOT NULL THEN 'CLOSED' ELSE 'OPEN' END AS Der_ReferralStatus,
	NULL AS Der_RefRecordOrder,
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate,
	h.Der_FY

FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS101Referral] r

INNER JOIN NHSE_MH_PrePublication.dbo.V4_MHS001MPI m ON r.RecordNumber = m.RecordNumber AND m.Der_Use_Submission_Flag = 'Y' 

LEFT JOIN NHSE_MH_PrePublication.dbo.V4_MHS102ServiceTypeReferredTo s ON r.UniqServReqID = s.UniqServReqID AND r.RecordNumber = s.RecordNumber AND s.Der_Use_Submission_Flag = 'Y' 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = r.UniqMonthID

WHERE r.UniqMonthID >= @EndRP AND r.Der_Use_Submission_Flag = 'Y' 

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Insert End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - BUILD DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Derivations Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

SELECT
	r.Der_RecordID,
	DENSE_RANK () OVER (PARTITION BY r.Person_ID, r.UniqServReqID ORDER BY r.UniqMonthID DESC) AS Der_RefRecordOrder

INTO #RefTemp

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] r

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Derivations End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - UPDATE DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Update Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

UPDATE r

SET 
	r.Der_RefRecordOrder = t.Der_RefRecordOrder

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] r

INNER JOIN #Reftemp t ON t.Der_RecordID = r.Der_RecordID

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Update End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'	
	
/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS - RECREATE INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Create Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - CREATE INDEXES

CREATE INDEX ix_Referral ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] ([UniqMonthID], [RecordNumber], [OrgIDProv], [Person_ID], [UniqServReqID])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Create Index End' AS Step,
	GETDATE() AS [TimeStamp]
