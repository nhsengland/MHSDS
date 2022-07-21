USE [NHSE_Sandbox_MentalHealth]
GO

/****** Object:  Table [dbo].[PreProc_Activity]    Script Date: 14/06/2021 19:22:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PreProc_Activity](
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
	-- contacts and indirect activity
	[UniqServReqID] [varchar](30) NULL,
	[UniqCareContID] [varchar](30) NULL,
	[OrgIDComm] [varchar](6) NULL,
	[AdminCatCode] [varchar](2) NULL,
	[SpecialisedMHServiceCode] [varchar](50) NULL,
	[ConsType] [varchar](2) NULL,
	[CareContSubj] [varchar](2) NULL,
	[ConsMediumUsed] [varchar](2) NULL,
	[ActLocTypeCode] [varchar](3) NULL,
	[PlaceOfSafetyInd] [varchar](1) NULL,	
	[SiteIDOfTreat] [varchar](10) NULL,
	[ComPeriMHPartAssessOfferInd] [varchar](1) NULL,
	[PlannedCareContIndicator] [varchar](1) NULL,
	[CareContPatientTherMode] [varchar](1) NULL,
	[AttendOrDNACode] [varchar](1) NULL,
	[EarliestReasonOfferDate] [date] NULL,
	[EarliestClinAppDate] [date] NULL,
	[CareContCancelDate] [date] NULL,
	[CareContCancelReas] [varchar](2) NULL,
	[ReasonableAdjustmentMade] [varchar](1) NULL,
	[AgeCareContDate] [int] NULL,
	[ContLocDistanceHome] [int] NULL,
	[TimeReferAndCareContact] [varchar](6) NULL,
	-- derivations
	[Der_UniqCareProfTeamID] [varchar](30) NULL,
	[Der_ContactDate] [date] NULL,	
	[Der_ContactTime] [varchar](8) NULL,	
	[Der_ContactDuration] [int] NULL,	
	[Der_ActivityType] [varchar](10) NULL,
	[Der_ActivityUniqID] [bigint] NOT NULL,
	[Der_ContactOrder] [int] NULL,
	[Der_FYContactOrder] [int] NULL,
	[Der_DirectContactOrder] [int] NULL,
	[Der_FYDirectContactOrder] [int] NULL,
	[Der_FacetoFaceContactOrder] [int] NULL,
	[Der_FYFacetoFaceContactOrder] [int] NULL,
 CONSTRAINT [pk_Activity] PRIMARY KEY CLUSTERED 
(
	[Der_RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO