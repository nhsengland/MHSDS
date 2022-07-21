USE [NHSE_Sandbox_MentalHealth]
GO

/****** Object:  Table [dbo].[PreProc_Inpatients]    Script Date: 21/06/2021 10:38:48 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PreProc_Inpatients](
	-- core bits
	[Der_RecordID] [int] IDENTITY(1,1) NOT NULL,
	[ReportingPeriodStartDate] [date] NULL,
	[ReportingPeriodEndDate] [date] NULL,
	[Der_FY] [varchar](10) NULL,
	[UniqSubmissionID] [bigint] NULL, 
	[NHSEUniqSubmissionID] [varchar] (30) NULL,
	[UniqMonthID] [bigint] NULL,
	[OrgIDProv] [varchar](6) NULL,
	[Person_ID] [varchar](100) NULL,	
	[RecordNumber] [bigint] NULL,
	--hospital spell	
	[MHS501UniqID] [bigint] NOT NULL,
	[UniqHospProvSpellNum] [varchar](30) NULL,
	[UniqServReqID] [varchar](30) NULL,
	[DecidedToAdmitDate] [date] NULL,
	[DecidedToAdmitTime] [varchar](8) NULL,
	[StartDateHospProvSpell] [date] NULL,
	[StartTimeHospProvSpell] [varchar](8) NULL,
	[SourceAdmCodeHospProvSpell] [varchar](2) NULL,
	[AdmMethCodeHospProvSpell] [varchar](2) NULL,
	[EstimatedDischDateHospProvSpell] [date] NULL,
	[PlannedDischDateHospProvSpell] [date] NULL,
	[PlannedDischDestCode] [varchar](2) NULL,
	[DischDateHospProvSpell] [date] NULL,
	[DischTimeHospProvSpell] [varchar](8) NULL,
	[DischMethCodeHospProvSpell] [varchar](1) NULL,
	[DischDestCodeHospProvSpell] [varchar](2) NULL,
	[PostcodeDistrictMainVisitor] [varchar](4) NULL,
	[PostcodeDistrictDischDest] [varchar](4) NULL,
	--ward stay
	[MHS502UniqID] [bigint] NULL,
	[UniqWardStayID] [varchar](30) NULL,
	[StartDateWardStay] [date] NULL,
	[StartTimeWardStay] [varchar](8) NULL,
	[EndDateMHTrialLeave] [date] NULL,
	[EndDateWardStay] [date] NULL,
	[EndTimeWardStay] [varchar](8) NULL,
	[SiteIDOfTreat] [varchar](10) NULL,
	[WardType] [varchar](2) NULL,
	[WardAge] [varchar](2) NULL,
	[WardSexTypeCode] [varchar](1) NULL,
	[IntendClinCareIntenCodeMH] [varchar](2) NULL,
	[WardSecLevel] [varchar](1) NULL,
	[LockedWardInd] [varchar](1) NULL,
	[HospitalBedTypeMH] [varchar](2) NULL,
	[SpecialisedMHServiceCode] [varchar](50) NULL,
	[WardCode] [varchar](12) NULL,
	[WardLocDistanceHome] [int] NULL,
	--derivations
	[Der_HospSpellStatus] [varchar](8) NULL,
	[Der_HospSpellRecordOrder] [bigint] NULL,
	[Der_FirstWardStayRecord] [bigint] NULL,
	[Der_LastWardStayRecord] [bigint] NULL,

PRIMARY KEY CLUSTERED 
(
	[Der_RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO