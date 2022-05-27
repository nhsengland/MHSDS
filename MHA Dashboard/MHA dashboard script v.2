/* 

Summary of script:

MHA Episodes: creates an extract of measures looking at, for example, the number of MHA episodes, duration of episodes, data quality of MHA fields, and CTOs/Recalls/Conditional discharges
-- Get list of all open MHA episodes in the reporting period
-- Create series of episodes by joining episodes together for the same person (if they start/end within 1 day of each other)
-- Join series information back to list of all open MHA episodes
-- Obtain similar information for CTOs, CTO recalls, and Conditional Discharges and union to MHA episodes info into one big table
-- Obtain and add population and specialised commissioning info
-- Create flags (i.e. StartedInMonthFlag) used to help create metrics
-- Create metrics for each month/geography/section type grouping
-- Pivot into long table ready for Tableau

Admissions: creates an extract of measures looking at admissions and admissions associated with MHA episodes
-- Get list of all admissions in the reporting period
-- Join and bring in MHA episode info for each admission and create flags
-- Create metrics for each month/geography/section type grouping
-- Pivot into long table ready for Tableau

People: create an extract of measures looking at the number of people subject to the MHA
-- Use list of MHA episodes created earlier, add som extract demographic info and create flags used to help create metrics
-- Create metrics in separate tables (to avoid double counting people) for each geography for all sections of the MHA and for each section of the MHA individually
-- Pivot into table ready for Tableau

Demographics: create an extract of number of people subject to the MHA split by demographics
-- Create LDA flag using NHS Digital's logic, flagging anyone with a suspected learning disability or autism
-- Use people master created earlier and convert into 12-month rolling data 
-- Edit section type groupings so section 136 is separate from other STOs
-- Create metric in separate tables (to avoid double counting) for each geography and demographic grouping, for all sections of the MHA and for each section of the MHA individually

Data quality: create an extract of providers who are submitting to the MHA tables in the MHSDS and ECDS, and how complete this data is
-- Identify providers with data in ECDS MHA staging table
-- Identify providers with open MHA episodes in MHSDS
-- Create padded table of MHSDS DQ informaton for each month/provider that should be submitting data
-- Union ECDS and MHSDS DQ data together
-- Save into table ready for Tableau

Drop all temporary tables

*/

---------------------------------
--------- MHA EPISODES ----------
---------------------------------

---------- Declare start of reporting period and end date

DECLARE @STARTDP INT
SET @STARTDP = 1423 -- October 2018 (get data for 6 months earlier than reporting period for repeat detention in last 6 months measure)

DECLARE @STARTRP INT
SET @STARTRP = 1429 -- April 2019 (reporting period - display data from this date in the dashboard)

DECLARE @ENDRP INT
SET @ENDRP = (SELECT (MAX(UniqMonthID)) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE Der_MostRecentFlag = 'P') -- Performance data

DECLARE @ENDRPDATE DATE
SET @ENDRPDATE = (SELECT MAX(ReportingPeriodEndDate) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE UniqMonthID = @ENDRP)

---------- Create a table of all MHA episodes in the reporting period, called #Cases

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cases') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cases

SELECT
m.Der_Person_ID, -- New Der_Person_ID due to NHSD changes to the Person_ID field
m.RecordNumber,
m.UniqMonthID,
s.ReportingPeriodStartDate AS ReportingPeriodStart,
s.ReportingPeriodEndDate AS ReportingPeriodEnd,
m.OrgIDProv,
m.UniqMHActEpisodeID, -- Unique episode ID
m.NHSDLegalStatus AS SectionType, -- Section type
m.StartDateMHActLegalStatusClass AS StartDate, -- Start date of episode
m.EndDateMHActLegalStatusClass AS EndDate, -- End date of episode
m.StartTimeMHActLegalStatusClass AS StartTime, -- Start time of episode
m.EndTimeMHActLegalStatusClass AS EndTime, -- End time of episode
ROW_NUMBER()OVER(PARTITION BY m.Der_Person_ID, m.UniqMHActEpisodeID ORDER BY m.UniqMonthID DESC) AS MostRecentFlagSpells, -- Identifies most recent month an episode is flowed
m.MHS401UniqID AS UniqID -- Unique ID used later to distinguish duplicate episodes in the same detention spell
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cases
FROM [NHSE_MHSDS].[dbo].[MHS401MHActPeriod] m -- Uses of the Act / episodes
LEFT JOIN NHSE_MHSDS.dbo.MHS001MPI mp on mp.RecordNumber = m.RecordNumber -- for WHERE clause, ensure only England data
INNER JOIN [NHSE_MHSDS].[dbo].[MHSDS_SubmissionFlags] s ON m.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y' -- Ensure data is latest submission
LEFT JOIN (SELECT DISTINCT c.UniqMHActEpisodeID, c.UniqMonthID, MAX(c.StartDateCommTreatOrd) AS StartDateCommTreatOrd FROM [NHSE_MHSDS].[dbo].[MHS404CommTreatOrder] c GROUP BY c.UniqMHActEpisodeID, c.UniqMonthID) c ON c.UniqMHActEpisodeID = m.UniqMHActEpisodeID AND c.UniqMonthID = m.UniqMonthID -- Join onto CTOs/Recalls/CDs to remove any MHA episodes that have a CTO/Recall/CD record flowed at the same time (as these episodes are inactive) - MAX used as a handful of cases of multiple StartDates per CTO
LEFT JOIN (SELECT DISTINCT cr.UniqMHActEpisodeID, cr.UniqMonthID, MAX(cr.StartDateCommTreatOrdRecall) AS StartDateCommTreatOrdRecall FROM [NHSE_MHSDS].[dbo].[MHS405CommTreatOrderRecall] cr GROUP BY cr.UniqMHActEpisodeID, cr.UniqMonthID) cr ON cr.UniqMHActEpisodeID = m.UniqMHActEpisodeID AND cr.UniqMonthID = m.UniqMonthID 
LEFT JOIN (SELECT DISTINCT cd.UniqMHActEpisodeID, cd.UniqMonthID, MAX(cd.StartDateMHCondDisch) AS StartDateMHCondDisch FROM [NHSE_MHSDS].[dbo].[MHS403ConditionalDischarge] cd GROUP BY cd.UniqMHActEpisodeID, cd.UniqMonthID) cd ON cd.UniqMHActEpisodeID = m.UniqMHActEpisodeID AND cd.UniqMonthID = m.UniqMonthID
WHERE m.UniqMonthID >= @STARTDP AND m.UniqMonthID <= @ENDRP -- Ensure data is only from October 2018
AND (mp.LADistrictAuth lIKE 'E%' OR mp.LADistrictAuth IS NULL) -- Ensure data is for England
AND c.UniqMHActEpisodeID IS NULL -- Remove MHS401 episodes if MHS404 data is being flowed for that episode 
AND cr.UniqMHActEpisodeID IS NULL -- Remove MHS401 episodes if MHS405 data is being flowed for that episode
AND cd.UniqMHActEpisodeID IS NULL -- Remove MHS401 episodes if MHS403 data is being flowed for that episode

--------- Join up episodes into series of episodes

--DECLARE @ENDRP INT
--SET @ENDRP = (SELECT (MAX(UniqMonthID)) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE Der_MostRecentFlag = 'P') -- Performance data

----- Take the latest record of an episode (1 row per episode), identify episodes which are open, closed or inactive (no longer flowed but no end date) at the end of the most recent reporting period, and recode any without an end date

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesCat') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesCat

SELECT
c.*,
CASE WHEN c.EndDate IS NULL THEN c.ReportingPeriodEnd
	ELSE c.EndDate END AS RecodedEndDate, -- Some episodes have no end date but also stopped being reported. The spell method here give will us the reporting period end date of the last month the episode appeared as the end date.
CASE WHEN c.EndDate IS NOT NULL THEN 'Closed'
	WHEN c.EndDate IS NULL AND c.UniqMonthID = @ENDRP THEN 'Open'
	WHEN c.EndDate IS NULL AND c.UniqMonthID <@ENDRP THEN 'Inactive'
	END AS EpisodeCat
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesCat
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cases c
WHERE c.MostRecentFlagSpells = 1 -- Ensure there is only 1 row per episode

----- Duplicate episodes and create 'date': one set with the start date, one set with the end date

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Dates') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Dates

SELECT 
c.*,
c.StartDate AS [Date],
1 AS inc -- Code all episodes with the StartDate as the Date as 1 (1 = episode starts)
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Dates
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesCat c

UNION ALL 

SELECT
c.*,
DATEADD(DAY, 1, c.RecodedEndDate) AS [Date], -- Add a day on to later count episodes starting the day after another episode closes as part of the series of episodes
-1 AS inc -- Code all episodes with the EndDate as the Date as -1 (-1 = episode ends)
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesCat c

----- Order episodes by person and start date (chronological ascending), and calculate a cumulative total of inc: 0 marks the end of a continuous period

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cumf') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cumf

SELECT 
d.Der_Person_ID,
d.[Date],
SUM(SUM(inc)) OVER (ORDER BY d.Der_Person_ID, [Date]) AS cume_inc -- Cumulative inc is calculated for each person
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cumf
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Dates d
GROUP BY d.Der_Person_ID, d.[Date] -- Grouping by person/date
ORDER BY d.Der_Person_ID, d.[Date]

----- Create a collection of episodes across a continuous period into a spell

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Groups') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Groups

SELECT
c.Der_Person_ID, 
c.Grp,
MIN([Date]) AS StartDate, -- The start date of the spell (first episode in the spell)
DATEADD(DAY, -1, MAX([Date])) AS EndDate -- The end date of the spell (last episode in the spell)
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Groups
FROM (SELECT *, SUM(CASE WHEN cume_inc = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY c.Der_Person_ID ORDER BY [Date] DESC) AS Grp FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cumf c) c -- Create a group of episodes (in a series) for each person where cume_inc 0 (when the spells closes by a final -1 without a new +1 starting)
GROUP BY c.Der_Person_ID, Grp
ORDER BY c.Der_Person_ID

----- Join a series of episodes back onto itself to find the end date of the last episode in a previous series and thus whether the current series of episodes is 'repeat' or not (i.e. starting within 180 days of a previous series)

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_GroupsRepeat') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_GroupsRepeat

SELECT
g.*,
h.EndDate AS EndDatePrevSeries,
DATEDIFF(DAY, h.EndDate, g.StartDate) AS DaysSincePrevSeries,
CASE WHEN (DATEDIFF(DAY, h.EndDate, g.StartDate)) <= 180 THEN 1 ELSE 0 END AS RepeatSeriesIn180DaysFlag
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_GroupsRepeat
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Groups g
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Groups h ON g.Der_Person_ID = h.Der_Person_ID AND g.Grp = h.Grp-1 -- Join each series to the previous series
ORDER BY der_person_ID, Grp

----- Explode series: create Series_ID and add spell info back to episodes

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries

SELECT 
C.Der_Person_ID,
c.OrgIDProv,
c.UniqMHActEpisodeID,
c.SectionType,
c.StartDate,
c.StartTime,
c.EndDate,
c.EndTime,
c.RecodedEndDate,
c.EpisodeCat,
CONCAT(g.Der_Person_ID, g.grp) AS Series_ID, -- Create unique series ID
g.StartDate AS StartDateSeries,
g.EndDate AS EndDateSeries,
g.Grp,
g.RepeatSeriesIn180DaysFlag,
ROW_NUMBER()OVER(PARTITION BY g.Der_Person_ID, g.grp ORDER BY c.StartDate ASC, c.StartTime ASC, c.RecodedEndDate ASC, c.EndTime ASC, c.RecordNumber ASC, c.UniqID ASC) AS RN_asc_dr, -- Rank/order episodes in a series ascending
ROW_NUMBER()OVER(PARTITION BY g.Der_Person_ID, g.grp ORDER BY c.StartDate DESC, c.StartTime DESC, c.RecodedEndDate DESC, c.EndTime DESC, c.RecordNumber DESC, c.UniqID DESC) AS RN_desc_dr -- Rank/order episodes in a series descending (recoded end date for episodes that start on the same date but where at least one has a NULL end date)
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesCat c
INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_GroupsRepeat g ON c.Der_Person_ID = g.Der_Person_ID AND c.StartDate BETWEEN g.Startdate and g.Enddate -- Bring series info for each episode

----- Bring in information on previous, first, next and last episode in the spell

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_BeforeAfter') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_BeforeAfter

SELECT 
e.*, 
b.SectionType AS Prev_SectionType, -- For identifying renewals and repeat series
b.OrgIDProv AS Prev_OrgIDProv, -- For identifying transfers
c.SectionType AS Next_SectionType, -- For identifying if S2s go to S3s and if S136s go to S2s/S3s
d.StartDate AS First_MHA_StartDate, -- For calculating duration of series and repeat series
d.StartTime AS First_MHA_StartTime, -- For calculating duration of series and repeat series
f.EndDate AS Last_MHA_EndDate, -- For calculating duration of series and repeat series
f.EndTime AS Last_MHA_EndTime -- For calculating duration of series and repeat series
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_BeforeAfter
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries e 
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries b on e.Series_ID = b.Series_ID AND e.RN_asc_dr = b.RN_asc_dr+1 -- Bring in info on prev episode
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries c on e.Series_ID = c.Series_ID AND e.RN_desc_dr = c.RN_desc_dr+1 -- Bring in info on next episode
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries d on e.Series_ID = d.Series_ID AND d.RN_asc_dr = 1 -- Bring in info on first episode
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries f on e.Series_ID = f.Series_ID AND f.RN_desc_dr = 1 -- Bring in info on last episode

---------- Join all series info back to original #Cases table

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfo') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfo

SELECT
c.*,
b.RecodedEndDate,
b.EpisodeCat,
b.Series_ID,
b.StartDateSeries,
b.RepeatSeriesIn180DaysFlag,
b.Prev_SectionType,
b.Next_SectionType,
b.First_MHA_StartDate,
b.First_MHA_StartTime,
b.Last_MHA_EndDate,
b.Last_MHA_EndTime,
b.RN_asc_dr,
b.RN_desc_dr,
CASE WHEN c.SectionType = b.Prev_SectionType AND c.OrgIDProv = b.Prev_OrgIDProv THEN 1 ELSE 0 END AS RenewalFlag, -- Flag when a renewal occurs (same section type) (changed to be not the same provider because renewal figure showing on dashboard was inflated)
CASE WHEN c.OrgIDProv <> b.Prev_OrgIDProv THEN 1 ELSE 0 END AS TransferFlag, -- Flag when a transfer occurs (change of provider)
-- CASE WHEN c.OrgIDProv <> b.Prev_OrgIDProv AND c.SectionType = b.Prev_SectionType THEN 1 ELSE 0 END AS TransferSameSectionTypeFlag, -- Flag when a transfer occurs where the section type stays the same
-- CASE WHEN c.OrgIDProv <> b.Prev_OrgIDProv AND c.SectionType <> b.Prev_SectionType THEN 1 ELSE 0 END AS TransferDiffSectionTypeFlag, -- Flag when a transfer occurs where the section type changes
CAST(NULL AS INT) AS AssociatedMHA
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfo
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cases c
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_BeforeAfter b ON c.UniqMHActEpisodeID = b.UniqMHActEpisodeID AND c.Der_Person_ID = b.Der_Person_ID

---------- Get similar info for CTOs, CTO recalls, and Conditional discharges (not including spell info)

--DECLARE @STARTDP INT
--SET @STARTDP = 1429 -- October 2018

--DECLARE @ENDRP INT
--SET @ENDRP = (SELECT (MAX(UniqMonthID)) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE Der_MostRecentFlag = 'P') -- Performance data

----- Join MHA episodes, CTOs, CTORecalls and CDs together into one table

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All

SELECT 
c.*
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfo c

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All

SELECT 
t.Der_Person_ID,
t.RecordNumber,
t.UniqMonthID,
h.ReportingPeriodStartDate AS ReportingPeriodStart,
h.ReportingPeriodEndDate AS ReportingPeriodEnd,
t.OrgIDProv,
t.UniqMHActEpisodeID,
'CTO' AS SectionType, 
t.StartDateCommTreatOrd AS StartDate,
t.EndDateCommTreatOrd AS EndDate,
NULL AS StartTime, -- Some info not available for CTOs, CTO Recalls and Conditional discharges
NULL AS EndTime,
NULL AS MostRecentFlagSpells,
t.MHS404UniqID AS UniqID,
NULL AS RecodedEndDate,
NULL AS EpisodeCat,
NULL AS Series_ID, -- We don't have series info for CTOs, CTO Recalls or Conditional discharge
NULL AS StartDateSeries,
NULL AS RepeatSeriesIn180DaysFlag,
NULL AS Prev_SectionType,
NULL AS Next_SectionType,
NULL AS First_MHA_StartDate,
NULL AS First_MHA_StartTime,
NULL AS Last_MHA_EndDate,
NULL AS Last_MHA_EndTime,
NULL AS RN_asc_dr,
NULL AS RN_desc_dr,
0 AS RenewalFlag, -- NULL not allowed, flags not used on CTO/Recall/Conditional Discharge page anyway
0 AS TransferFlag,
m.NHSDLegalStatus AS AssociatedMHA -- Get the MHA status flowed to MHS401 table
FROM [NHSE_MHSDS].[dbo].[MHS404CommTreatOrder] t -- CTOs
LEFT JOIN NHSE_MHSDS.dbo.MHS001MPI mp on mp.RecordNumber = t.RecordNumber
INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] h ON t.UniqMonthID = h.UniqMonthID
INNER JOIN [NHSE_MHSDS].[dbo].[MHSDS_SubmissionFlags] s ON t.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'
INNER JOIN [NHSE_MHSDS].[dbo].[MHS401MHActPeriod] m ON t.MHActLegalStatusClassPeriodId = m.MHActLegalStatusClassPeriodId AND t.RecordNumber = m.RecordNumber -- Join on to 401 table to get the MHA status flowed
WHERE t.UniqMonthID BETWEEN @STARTDP AND @ENDRP
AND (mp.LADistrictAuth lIKE 'E%' OR mp.LADistrictAuth IS NULL) 

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All

SELECT 
t.Der_Person_ID,
t.RecordNumber,
t.UniqMonthID,
h.ReportingPeriodStartDate AS ReportingPeriodStart,
h.ReportingPeriodEndDate AS ReportingPeriodEnd,
t.OrgIDProv,
t.UniqMHActEpisodeID,
'CTO Recall' AS SectionType, 
t.StartDateCommTreatOrdRecall AS StartDate,
t.EndDateCommTreatOrdRecall AS EndDate,
NULL AS StartTime,
NULL AS EndTime,
NULL AS MostRecentFlagSpells,
t.MHS405UniqID AS UniqID, 
NULL AS RecodedEndDate,
NULL AS EpisodeCat,
NULL AS Series_ID, -- We don't have series info for CTOs, CTO Recalls or Conditional discharge
NULL AS StartDateSeries,
NULL AS RepeatSeriesIn180DaysFlag,
NULL AS Prev_SectionType,
NULL AS Next_SectionType,
NULL AS First_MHA_StartDate,
NULL AS First_MHA_StartTime,
NULL AS Last_MHA_EndDate,
NULL AS Last_MHA_EndTime,
NULL AS RN_asc_dr,
NULL AS RN_desc_dr,
0 AS RenewalFlag, -- NULL not allowed, flags not used on CTO/Recall/Conditional Discharge page anyway
0 AS TransferFlag,
m.NHSDLegalStatus AS AssociatedMHA
FROM [NHSE_MHSDS].[dbo].[MHS405CommTreatOrderRecall] t -- CTO Recalls
LEFT JOIN NHSE_MHSDS.dbo.MHS001MPI mp on mp.RecordNumber = t.RecordNumber
INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] h ON t.UniqMonthID = h.UniqMonthID
INNER JOIN [NHSE_MHSDS].[dbo].[MHSDS_SubmissionFlags] s ON t.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'
INNER JOIN [NHSE_MHSDS].[dbo].[MHS401MHActPeriod] m ON t.MHActLegalStatusClassPeriodId = m.MHActLegalStatusClassPeriodId AND t.RecordNumber = m.RecordNumber
WHERE t.UniqMonthID BETWEEN @STARTDP AND @ENDRP
AND (mp.LADistrictAuth lIKE 'E%' OR mp.LADistrictAuth IS NULL) 

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All

SELECT  
t.Der_Person_ID,
t.RecordNumber,
t.UniqMonthID,
h.ReportingPeriodStartDate AS ReportingPeriodStart,
h.ReportingPeriodEndDate AS ReportingPeriodEnd,
t.OrgIDProv,
t.UniqMHActEpisodeID,
'CD' AS SectionType, 
t.StartDateMHCondDisch AS StartDate,
t.EndDateMHCondDisch AS EndDate,
NULL AS StartTime,
NULL AS EndTime,
NULL AS MostRecentFlagSpells,
t.MHS403UniqID AS UniqID, 
NULL AS RecodedEndDate,
NULL AS EpisodeCat,
NULL AS Series_ID, -- We don't have series info for CTOs, CTO Recalls or Conditional discharge
NULL AS StartDateSeries,
NULL AS RepeatSeriesIn180DaysFlag,
NULL AS Prev_SectionType,
NULL AS Next_SectionType,
NULL AS First_MHA_StartDate,
NULL AS First_MHA_StartTime,
NULL AS Last_MHA_EndDate,
NULL AS Last_MHA_EndTime,
NULL AS RN_asc_dr,
NULL AS RN_desc_dr,
0 AS RenewalFlag, -- NULL not allowed, flags not used on CTO/Recall/Conditional Discharge page anyway
0 AS TransferFlag,
m.NHSDLegalStatus AS AssociatedMHA
FROM [NHSE_MHSDS].[dbo].[MHS403ConditionalDischarge] t -- Conditional discharges
LEFT JOIN NHSE_MHSDS.dbo.MHS001MPI mp on mp.RecordNumber = t.RecordNumber
INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] h ON t.UniqMonthID = h.UniqMonthID
INNER JOIN [NHSE_MHSDS].[dbo].[MHSDS_SubmissionFlags] s ON t.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'
INNER JOIN [NHSE_MHSDS].[dbo].[MHS401MHActPeriod] m ON t.MHActLegalStatusClassPeriodId = m.MHActLegalStatusClassPeriodId AND t.RecordNumber = m.RecordNumber
WHERE t.UniqMonthID BETWEEN @STARTDP AND @ENDRP
AND (mp.LADistrictAuth lIKE 'E%' OR mp.LADistrictAuth IS NULL) 

---------- Get CCG / STP / Region / England population for denominator for rates

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Population') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Population

SELECT 
d.Area_Code,
SUM(d.Size) AS [Population]
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Population
FROM [NHSE_UKHF].[Demography].[vw_ONS_Population_Estimates_For_CCGs_By_Year_Of_Age1] d -- ONS population estimates at CCG level
WHERE d.Effective_Snapshot_Date = '2020-07-01'-- Most recent estimates
GROUP BY d.Area_Code

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGCodes') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGCodes

SELECT
COALESCE(cc.New_Code, c.CCG_Code) AS CCG_Code,
map.Organisation_Name AS CCG_Name,
c.CCG_Code2,
c.Created_Date
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGCodes
FROM [NHSE_UKHF].[ODS].[vw_CCG_Names_And_Codes_England_SCD] c -- Get CCG codes in correct format
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON c.CCG_Code = cc.Org_Code -- Get new codes for any boundary changes
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies map ON COALESCE(cc.New_Code, c.CCG_Code) = map.Organisation_Code -- Get CCG name
WHERE c.Is_Latest = 1
ORDER BY CCG_Name

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGPop') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGPop

SELECT 
c.CCG_Code, 
SUM(p.[Population]) AS CCGPopulation -- Sum population at CCG level
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGPop
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Population p
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGCodes c ON p.Area_Code = c.CCG_Code2 COLLATE Latin1_General_CI_AS -- Ensure data type is the same to join (using Collate)
GROUP BY c.CCG_Code

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_STPPop') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_STPPop

SELECT 
map.STP_Code,
SUM(c.CCGPopulation) AS STPPopulation -- Sum population at STP level
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_STPPop
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGPop c
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies map ON c.CCG_Code = map.Organisation_Code -- Get STP codes
GROUP BY STP_Code

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RegionPop') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RegionPop

SELECT 
map.Region_Code, 
SUM(c.CCGPopulation) AS RegionPopulation -- Sum population at region level
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RegionPop
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGPop c
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies map ON c.CCG_Code = map.Organisation_Code -- Get region codes
GROUP BY Region_Code

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_EnglandPop') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_EnglandPop

SELECT 
SUM(c.CCGPopulation) AS EnglandPopulation -- Get total population for England (hard code this in #Master)
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_EnglandPop
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGPop c

---------- Obtain specialised commissioning MH activity information 

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpec') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpec

SELECT 
a.*,
i.SpecialisedMHServiceCode, -- Obtain code
ROW_NUMBER()OVER(PARTITION BY a.RecordNumber, a.UniqMHActEpisodeID ORDER BY i.EndDateWardStay DESC) AS MostRecentFlag -- Last ward stay record where bed type is completed
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpec
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All a
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Inpatients i ON a.RecordNumber = i.RecordNumber
WHERE i.StartDateWardStay <= (CASE WHEN a.EndDate IS NOT NULL THEN a.EndDate ELSE a.ReportingPeriodEnd END) -- Only obtain code if ward stay is before episode ends
AND i.SpecialisedMHServiceCode IS NOT NULL -- Sometimes code isn't filled in - removed NULLs and create new 'MostRecentFlag' which is essentially last stay ward record where code is completed

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpec') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpec

SELECT a.*,
s.SpecialisedServiceCodeDescription, -- Obtain corresponding description
s.SpecialisedMentalHealthServiceCategoryDescription
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpec
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpec a
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_SpecialisedMHServiceCatCodes s ON a.SpecialisedMHServiceCode = s.SpecialisedMentalHealthServiceCategoryCode
WHERE a.MostRecentFlag = 1 -- For latest ward stay record

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpecComm') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpecComm

SELECT 
a.*,
CASE WHEN h.OrgIDComm IN ('13N', '13R', '13V', '13X', '13Y', '14C', '14D', '14E', '14F', '14G', '85J', '27T', '14A', '14E', '14G', '14F', '13R','L5H9Q',
'N8S0C','Q7O8U','X8H3R','P7L6U','F3I2L','S7T0C','Z1U2L','C9Z7X','F9H5S','K5B5Y','S6Z6H','J3T7D','I0H0N','O5V1Z','E2S1E','A8R9E','S5L0S','N5T4E','O6H3T',
'I2T5F','K4Z4O','Z0X9Q','B9Q0L','I3Q3V','X4I1M','N9S3D','D8D1G','Z4P6N','D4U5V','P9W2J','L4H0W','B5S8O','G1U9X','X6C7V','C8S2X','R7G8O','H3F5A','I4B8X',
'X4L0A','B0N9F','N5E8H','M4X2K','A3Y0R','W6B3O','O1N4A','Z0B3G') THEN 'Yes'
ELSE 'No' END AS SpecCommCode, -- Obtain code
ROW_NUMBER()OVER(PARTITION BY a.RecordNumber, a.UniqMHActEpisodeID ORDER BY i.EndDateWardStay DESC) AS MostRecentFlag -- Last ward stay record where bed type is completed
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpecComm
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All a
LEFT JOIN NHSE_MHSDS.dbo.MHS502WardStay i ON a.RecordNumber = i.RecordNumber
LEFT JOIN NHSE_MHSDS.dbo.MHS512HospSpellComm h ON a.RecordNumber = h.RecordNumber
WHERE i.StartDateWardStay <= (CASE WHEN a.EndDate IS NOT NULL THEN a.EndDate ELSE a.ReportingPeriodEnd END) -- Only obtain code if ward stay is before episode ends
AND h.OrgIDComm IS NOT NULL -- Sometimes code isn't filled in - removed NULLs and create new 'MostRecentFlag' which is essentially last stay ward record where code is completed

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpecComm') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpecComm

SELECT a.*
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpecComm
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpecComm a
WHERE a.MostRecentFlag = 1 -- For latest ward stay record

---------- Create Master table of all information

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMaster') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMaster

SELECT 
a.*, -- Everything from combined cases / CTOs / CTO recalls / CDs table
f.Fin_Year_Start AS FY_Reporting_Period_Start, -- Add financial year start date for reporting period
COALESCE(cc.New_Code, mp.OrgIDCCGRes) AS OrgIDCCGRes, -- Use new CCG code if recently changed / merged to bring in CCG code
o.Organisation_Name AS ProvName, -- Provider name
map.Organisation_Name AS CCGName, -- CCG name
map.STP_Code, -- Bring in other geographical fields
map.STP_Name,
map.Region_Code,
map.Region_Name,
f2.Fin_Year_Start AS FY_Episode_StartDate, -- Add financial year start date for episode start date
CASE WHEN a.SectionType = '01' THEN 'Informal' 
	WHEN a.SectionType = '02' THEN 'Section 2'
	WHEN a.SectionType = '03' THEN 'Section 3'
	WHEN a.SectionType = '04' THEN 'Section 4'
	WHEN a.SectionType = '05' THEN 'Section 5(2)'
	WHEN a.SectionType = '06' THEN 'Section 5(4)'
	WHEN a.SectionType = '07' THEN 'Section 35'
	WHEN a.SectionType = '08' THEN 'Section 36'
	WHEN a.SectionType = '09' THEN 'Section 37 w 41'
	WHEN a.SectionType = '10' THEN 'Section 37'
	WHEN a.SectionType = '12' THEN 'Section 38'
	WHEN a.SectionType = '13' THEN 'Section 44'
	WHEN a.SectionType = '14' THEN 'Section 46'
	WHEN a.SectionType = '15' THEN 'Section 47 w 49'
	WHEN a.SectionType = '16' THEN 'Section 47'
	WHEN a.SectionType = '17' THEN 'Section 48 w 49'
	WHEN a.SectionType = '18' THEN 'Section 48'
	WHEN a.SectionType = '19' THEN 'Section 135'
	WHEN a.SectionType = '20' THEN 'Section 136'
	WHEN a.SectionType = '31' THEN 'Criminal Procedure (Insanity) Act 1964'
	WHEN a.SectionType = '32' THEN 'Other acts'
	WHEN a.SectionType = '35' THEN 'Section 7 - guardianship'
	WHEN a.SectionType = '36' THEN 'Section 37 - guardianship'
	WHEN a.SectionType = '37' THEN '45a - limited direction in force'
	WHEN a.SectionType = '38' THEN '45a - limited direction ended'
	WHEN a.SectionType = 'CD' THEN 'Conditional discharge'
	WHEN a.SectionType = 'CTO' THEN 'Community Treatment Order'
	WHEN a.SectionType = 'CTO Recall' THEN 'Community Treatment Order Recall'
	ELSE 'Missing/Invalid' END AS SectionName, -- Add in section names (could use [NHSE_Reference].[dbo].[tbl_Ref_DataDic_ZZZ_MHALegalStatusClassCode] but some names aren't up to date in the desired format)
CASE WHEN a.SectionType IN ('07', '08', '09', '10', '12', '13', '37', '38', '14', '15', '16', '17', '18', '31', '36') THEN 'Part 3' -- 35, 36, 37, 37 with 41 restrictions, 38, 44, 45A, 46, 47, 47 with 49 restrictions, 48, 48 with 49 restrictions, The Criminal Procedure (Insanity) Act 1964 as amended by the Criminal Procedures (Insanity and Unfitness to Plead) Act 1991; guardianship under Section 37
	WHEN a.SectionType IN ('04', '05', '06', '19', '20') THEN 'STO' -- Section 4, 5(2), 5(4), 135, 136
	WHEN a.SectionType = '01' THEN 'Informal'
	WHEN a.SectionType = '02' THEN 'Section 2' 
	WHEN a.SectionType = '03' THEN 'Section 3'
	WHEN a.SectionType = '32' THEN 'Other cases'
	WHEN a.SectionType = '35' THEN 'Section 7 - guardianship'
	WHEN a.SectionType = 'CD' THEN 'Conditional discharge'
	WHEN a.SectionType = 'CTO' THEN 'Community Treatment Order'
	WHEN a.SectionType = 'CTO Recall' THEN 'Community Treatment Order Recall'
	ELSE 'Missing/Invalid' END AS SectionGroup, -- Create MHA section groups
CASE WHEN mp.AgeRepPeriodEnd < 18 THEN '0-17'
	WHEN mp.AgeRepPeriodEnd BETWEEN 18 AND 24 THEN '18-24'
	WHEN mp.AgeRepPeriodEnd BETWEEN 25 AND 34 THEN '25-34'
	WHEN mp.AgeRepPeriodEnd BETWEEN 35 AND 44 THEN '35-44'
	WHEN mp.AgeRepPeriodEnd BETWEEN 45 AND 54 THEN '45-54'
	WHEN mp.AgeRepPeriodEnd BETWEEN 55 AND 64 THEN '55-64'
	WHEN mp.AgeRepPeriodEnd > 64 THEN '65+' 
	ELSE 'Missing/Invalid' END AS AgeBand, -- Add in age groups
CASE WHEN o.NHSE_Organisation_Type IN ('COMMUNITY TRUST', 'ACUTE TRUST', 'CARE TRUST', 'MENTAL HEALTH AND LEARNING DISABILITY') THEN 'NHS'
	WHEN o.NHSE_Organisation_Type IN ('NON-NHS ORGANISATION', 'INDEPENDENT SECTOR HEALTHCARE PROVIDER') THEN 'NON-NHS'
	WHEN o.NHSE_Organisation_Type IS NULL OR o.NHSE_Organisation_Type = 'UNKNOWN' THEN 'UNKNOWN'
	ELSE 'OTHER' END AS NHSE_Organisation_Type, -- Group organisations into NHS and non-NHS
mp.EthnicCategory, -- Add in ethnic category 
c.CCGPopulation, -- Bring in calculated population totals
s.STPPopulation,
r.RegionPopulation,
CAST('56550138' AS INT) AS EnglandPopulation, -- Manually add in England population
CASE WHEN a.AssociatedMHA = '01' THEN 'Informal' 
	WHEN a.AssociatedMHA = '02' THEN 'Section 2'
	WHEN a.AssociatedMHA = '03' THEN 'Section 3'
	WHEN a.AssociatedMHA = '04' THEN 'Section 4'
	WHEN a.AssociatedMHA = '05' THEN 'Section 5(2)'
	WHEN a.AssociatedMHA = '06' THEN 'Section 5(4)'
	WHEN a.AssociatedMHA = '07' THEN 'Section 35'
	WHEN a.AssociatedMHA = '08' THEN 'Section 36'
	WHEN a.AssociatedMHA = '09' THEN 'Section 37 w 41'
	WHEN a.AssociatedMHA = '10' THEN 'Section 37'
	WHEN a.AssociatedMHA = '12' THEN 'Section 38'
	WHEN a.AssociatedMHA = '13' THEN 'Section 44'
	WHEN a.AssociatedMHA = '14' THEN 'Section 46'
	WHEN a.AssociatedMHA = '15' THEN 'Section 47 w 49'
	WHEN a.AssociatedMHA = '16' THEN 'Section 47'
	WHEN a.AssociatedMHA = '17' THEN 'Section 48 w 49'
	WHEN a.AssociatedMHA = '18' THEN 'Section 48'
	WHEN a.AssociatedMHA = '19' THEN 'Section 135'
	WHEN a.AssociatedMHA = '20' THEN 'Section 136'
	WHEN a.AssociatedMHA = '31' THEN 'Criminal Procedure (Insanity) Act 1964'
	WHEN a.AssociatedMHA = '32' THEN 'Other acts'
	WHEN a.AssociatedMHA = '35' THEN 'Section 7 - guardianship'
	WHEN a.AssociatedMHA = '36' THEN 'Section 37 - guardianship'
	WHEN a.AssociatedMHA = '37' THEN '45a - limited direction in force'
	WHEN a.AssociatedMHA = '38' THEN '45a - limited direction ended'
	ELSE 'Missing/Invalid' END AS AssociatedMHAName, -- Add in section names for episode associated with CTO
ISNULL(CASE WHEN wsc.SpecCommCode = 'YES' THEN ws.SpecialisedServiceCodeDescription ELSE 'Non Specialised Service' END, 'Non Specialised Service') AS SpecialisedServiceCodeDescription, -- Bring in specialised commissing information
ISNULL(CASE WHEN wsc.SpecCommCode = 'YES' THEN ws.SpecialisedMentalHealthServiceCategoryDescription ELSE 'Non Specialised Service' END, 'Non Specialised Service') AS SpecialisedMentalHealthServiceCategoryDescription,

-- Create episode flags for metric creation below
CASE WHEN a.StartDate BETWEEN a.ReportingPeriodStart AND a.ReportingPeriodEnd THEN 1 ELSE 0 END AS StartedInMonthFlag, -- New episode starting in the month flag
ROW_NUMBER()OVER(PARTITION BY a.UniqMHActEpisodeID, f.Fin_Year_Start ORDER BY a.UniqMonthID ASC) AS ActiveInYearFlag, -- Active episode in the year flag. To count episode only once per financial year for FY active uses
CASE WHEN a.EndDate BETWEEN a.ReportingPeriodStart AND a.ReportingPeriodEnd THEN 1 ELSE 0 END AS EndedInMonthFlag, -- Episode ended (with EndDate) in the month flag

-- Create flag used later to count people in people extract
CASE WHEN f.Fin_Year_Start = f2.Fin_Year_Start THEN 1 ELSE 0 END AS StartedInYearFlag, -- New episode starting in the year flag. Used later in people extract to count people only once per financial year

-- Calculate the duration of episodes
DATEDIFF(MINUTE, CAST(a.StartDate AS DATETIME) + CAST(a.StartTime AS DATETIME), CAST(a.EndDate AS DATETIME) + CAST(a.EndTime AS DATETIME)) AS DurationOfEpisodeMins, -- Calculate the difference between the start and end of each episode, in minutes

-- Calculate the duration of a series of episodes
DATEDIFF(MINUTE, CAST(a.First_MHA_StartDate AS DATETIME) + CAST(a.First_MHA_StartTime AS DATETIME), CAST(a.Last_MHA_EndDate AS DATETIME) + CAST(a.Last_MHA_EndTime AS DATETIME)) AS DurationOfSeriesEpisodeMins -- Calculate the difference between the start and end of each series of episode, in minutes

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMaster
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All a
LEFT JOIN NHSE_MHSDS.dbo.MHS001MPI mp on mp.RecordNumber = a.RecordNumber -- Obtain age and ethnicity information
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Dates_Full] f ON a.ReportingPeriodStart = f.Full_Date -- Obtain FY start info for reporting period start 
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Dates_Full] f2 ON a.StartDate = f2.Full_Date -- Obtain FY start info for episode start date 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o ON a.OrgIDProv = o.Organisation_Code -- Obtain provider name
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON mp.OrgIDCCGRes = cc.Org_Code -- Obtain new CCG codes
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies map ON COALESCE(cc.New_Code, mp.OrgIDCCGRes) = map.Organisation_Code -- Obtain provider to CCG / STP / region mappings
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGPop c ON c.CCG_Code = COALESCE(cc.New_Code, mp.OrgIDCCGRes) -- Add in CCG populations
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_STPPop s ON s.STP_Code = map.STP_Code -- Add in STP populations
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RegionPop r ON r.Region_Code = map.Region_Code -- Add in Region populations
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpec ws ON a.RecordNumber = ws.RecordNumber AND a.UniqMHActEpisodeID = ws.UniqMHActEpisodeID -- Add in Speciailised MH category description
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpecComm wsc ON a.RecordNumber = wsc.RecordNumber AND a.UniqMHActEpisodeID = wsc.UniqMHActEpisodeID -- Add in Speciailised MH Comm code

----- Create metrics from Cases Master

--DECLARE @STARTRP INT
--SET @STARTRP = 1429 -- April 2019 (reporting period - display data from this date in the dashboard)

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMetric') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMetric

SELECT

-- Group by these: calculate i.e. SUM for each combination of groupings
c.UniqMonthID,
c.ReportingPeriodEnd,
c.OrgIDProv,
c.ProvName,
c.OrgIDCCGRes,
c.CCGName,
c.STP_Code,
c.STP_Name,
c.Region_Code,
c.Region_Name,
c.SectionType,
c.SectionName,
c.SectionGroup,
c.NHSE_Organisation_Type,
c.RenewalFlag,
c.TransferFlag,
c.AgeBand,
c.SpecialisedServiceCodeDescription,
c.SpecialisedMentalHealthServiceCategoryDescription,
c.AssociatedMHAName,

-- Standard counts of episodes
COUNT(*) AS ActiveUses, -- Total episodes open in the reporting period (didn't necessarily start in it)
SUM(c.StartedInMonthFlag) AS NewUses, -- Total episodes open AND started in the reporting period
SUM(CASE WHEN c.ActiveInYearFlag = 1 THEN 1 ELSE 0 END) AS ActiveUsesInYear, -- Total episodes open at some stage in the financial year (used to create total FY active cases as cases only appear once - can't just cumulate ActiveUses like NewUses)

-- Duration of episodes ending
SUM(CASE WHEN c.EndedInMonthFlag = 1 THEN c.DurationOfEpisodeMins ELSE 0 END) AS DurationEpisodeNumerator, 
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.RenewalFlag <> 1 THEN 1 ELSE 0 END) AS DurationEpisodeDenominator, 

-- Duration of series of episodes ending (series ending identified by end of current episode and no new episode)
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.Next_SectionType IS NULL AND c.SectionGroup IN ('Section 2', 'Section 3') AND c.DurationOfSeriesEpisodeMins IS NOT NULL THEN c.DurationOfSeriesEpisodeMins ELSE 0 END) AS DurationSeriesEpisodesPart2Numerator, -- Series of Part 2 episodes (only those ending NOT with an STO)
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.Next_SectionType IS NULL AND c.SectionGroup IN ('Section 2', 'Section 3') AND c.DurationOfSeriesEpisodeMins IS NOT NULL THEN 1 ELSE 0 END) AS DurationSeriesEpisodesPart2Denominator, 
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.Next_SectionType IS NULL AND c.SectionGroup IN ('Part 3') AND c.DurationOfSeriesEpisodeMins IS NOT NULL THEN c.DurationOfSeriesEpisodeMins ELSE 0 END) AS DurationSeriesEpisodesPart3Numerator, -- Series of Part 3 episodes
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.Next_SectionType IS NULL AND c.SectionGroup IN ('Part 3') AND c.DurationOfSeriesEpisodeMins IS NOT NULL THEN 1 ELSE 0 END) AS DurationSeriesEpisodesPart3Denominator,

-- AND c.SectionGroup IN ('STO', 'Section 2', 'Section 3', 'Part 3')

-- S2s to S3s
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.SectionType = '02' AND c.Next_SectionType = '03' THEN 1 ELSE 0 END) AS S2toS3Numerator, 
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.SectionType = '02' AND (c.Next_SectionType <> '02' OR c.Next_SectionType IS NULL) THEN 1 ELSE 0 END) AS S2toS3Denominator, -- S2s starting that aren't renewals/transfers. Shouldn't use most recent month in dashboard.

-- S136s to S2/3s
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.SectionType = '20' AND c.Next_SectionType IN ('02', '03') THEN 1 ELSE 0 END) AS S136toS2S3Numerator, 
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.SectionType = '20' AND (c.Next_SectionType <> '20' OR c.Next_SectionType IS NULL) THEN 1 ELSE 0 END) AS S136toS2S3Denominator, -- S136s starting that aren't renewals/transfers. Shouldn't use most recent month in dashboard.

-- Repeat series of episodes (series starting identfied by no previous episode)
SUM(CASE WHEN c.StartedInMonthFlag = 1 AND c.Prev_SectionType IS NULL AND c.RepeatSeriesIn180DaysFlag = 1 THEN 1 ELSE 0 END) AS NewEpisodeRepeatNumerator, 
SUM(CASE WHEN c.StartedInMonthFlag = 1 AND c.Prev_SectionType IS NULL THEN 1 ELSE 0 END) AS NewEpisodeRepeatDenominator,

-- Episodes breaching over 72 hours (haven't yet figured out how to take into acccount renewals and transfers in this calculation)
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.SectionType = '19' AND c.DurationOfEpisodeMins > 1440 THEN 1 ELSE 0 END) AS S135sBreachingNumerator,
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.SectionType = '19' AND c.DurationOfEpisodeMins IS NOT NULL THEN 1 ELSE 0 END) AS S135sBreachingDenominator,
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.SectionType = '20' AND c.DurationOfEpisodeMins > 1440 THEN 1 ELSE 0 END) AS S136sBreachingNumerator,
SUM(CASE WHEN c.EndedInMonthFlag = 1 AND c.SectionType = '20' AND c.DurationOfEpisodeMins IS NOT NULL THEN 1 ELSE 0 END) AS S136sBreachingDenominator,

-- Population figures as denominator for rates
MAX(c.CCGPopulation) AS CCGPopulation,
MAX(STPPopulation) AS STPPopulation, 
MAX(RegionPopulation) AS RegionPopulation,
MAX(EnglandPopulation) AS EnglandPopulation,

-- MHA data quality fields
SUM(CASE WHEN c.EthnicCategory IN ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'R', 'S') THEN 1 ELSE 0 END) AS ValidEthnicity, -- Episodes flowed with valid ethnicity
SUM(CASE WHEN c.EthnicCategory NOT IN ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'R', 'S') THEN 1 ELSE 0 END) AS NoValidEthnicity, -- w/o
SUM(CASE WHEN c.StartTime IN ('00:00:00', '12:00:00') THEN 1 ELSE 0 END) AS StartAtMidnightOrMidday, -- Episodes flowed at midnight or midday
SUM(CASE WHEN c.StartTime NOT IN ('00:00:00', '12:00:00') THEN 1 ELSE 0 END) AS DidntStartAtMidnightOrMidday, -- Other times
SUM(CASE WHEN c.StartTime IN ('00:00:00', '01:00:00', '02:00:00', '03:00:00', '04:00:00', '05:00:00', '06:00:00', '07:00:00', '08:00:00', '09:00:00', '10:00:00', '11:00:00', '12:00:00', '13:00:00', '14:00:00', '15:00:00', '16:00:00', '17:00:00', '18:00:00', '19:00:00', '20:00:00', '21:00:00', '22:00:00', '23:00:00') THEN 1 ELSE 0 END) AS StartOnTheHour, -- Episodes starting on the hour
SUM(CASE WHEN c.StartTime NOT IN ('00:00:00', '01:00:00', '02:00:00', '03:00:00', '04:00:00', '05:00:00', '06:00:00', '07:00:00', '08:00:00', '09:00:00', '10:00:00', '11:00:00', '12:00:00', '13:00:00', '14:00:00', '15:00:00', '16:00:00', '17:00:00', '18:00:00', '19:00:00', '20:00:00', '21:00:00', '22:00:00', '23:00:00') THEN 1 ELSE 0 END) AS DidntStartOnTheHour, -- Other times
SUM(CASE WHEN c.SectionType IN ('02', '03', '04', '05', '06', '07', '08', '09', '10', '12', '13', '14', '15', '16', '17', '18', '19', '20', '31', '35', '36', '37', '38') THEN 1 ELSE 0 END) AS ValidSectionType,-- Episodes flowed with a valid section type
SUM(CASE WHEN c.SectionType NOT IN ('01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '12', '13', '14', '15', '16', '17', '18', '19', '20', '31', '32', '35', '36', '37', '38') THEN 1 ELSE 0 END) AS NoValidSectionType, -- w/o
SUM(CASE WHEN c.SectionType IN ('32', '01') THEN 1 ELSE 0 END) AS OtherActsOrInformalSectionType, --  Episodes flowed as an Other Act of Informal
SUM(CASE WHEN c.EpisodeCat = 'Inactive' AND c.RecodedEndDate = c.ReportingPeriodEnd THEN 1 ELSE 0 END) AS LastFlowedNoEndDate, -- Last time episode flowed without EndDate
SUM(CASE WHEN c.EpisodeCat = 'Closed' AND c.EndDate BETWEEN c.ReportingPeriodStart AND c.ReportingPeriodEnd THEN 1 ELSE 0 END) AS ClosedWithEndDate -- Last time episode flowed with EndDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMetric
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMaster c
WHERE C.UniqMonthID >= @STARTRP 
GROUP BY c.UniqMonthID, c.ReportingPeriodEnd, c.OrgIDProv, c.ProvName, c.OrgIDCCGRes, c.CCGName, c.STP_Code, c.STP_Name, c.Region_Code, c.Region_Name, c.SectionType, c.SectionName, c.SectionGroup, c.RenewalFlag, c.TransferFlag, c.AgeBand, c.SpecialisedServiceCodeDescription, c.SpecialisedMentalHealthServiceCategoryDescription, c.NHSE_Organisation_Type, c.AssociatedMHAName

----- Pivot final table into long format and refresh 'Dashboard_MHA'

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA
 
SELECT 
c.UniqMonthID,
c.ReportingPeriodEnd,
c.OrgIDProv,
c.ProvName,
c.OrgIDCCGRes,
c.CCGName,
c.STP_Code,
c.STP_Name,
c.Region_Code,
c.Region_Name,
c.SectionType,
c.SectionGroup,
c.SectionName,
c.NHSE_Organisation_Type, 
c.AssociatedMHAName,
CASE WHEN MeasureName = 'ActiveUses' THEN 0 ELSE c.RenewalFlag END AS RenewalFlag,
CASE WHEN MeasureName = 'ActiveUses' THEN 0 ELSE c.TransferFlag END AS TransferFlag,
c.AgeBand,
c.SpecialisedMentalHealthServiceCategoryDescription,
c.SpecialisedServiceCodeDescription,
MeasureName, -- MeasureName now includes all measures calculated above / included in the unpivot below
MeasureValue, -- MeasureValue will change depending on the MeasureName
CASE WHEN MeasureName = 'DurationEpisodeNumerator' THEN c.DurationEpisodeDenominator
	WHEN MeasureName = 'DurationSeriesEpisodesPart2Numerator' THEN c.DurationSeriesEpisodesPart2Denominator
	WHEN MeasureName = 'DurationSeriesEpisodesPart3Numerator' THEN c.DurationSeriesEpisodesPart3Denominator
	WHEN MeasureName = 'S2toS3Numerator' THEN c.S2toS3Denominator
	WHEN MeasureName = 'S136toS2S3Numerator' THEN c.S136toS2S3Denominator
	WHEN MeasureName = 'NewEpisodeRepeatNumerator' THEN c.NewEpisodeRepeatDenominator
	WHEN MeasureName = 'S135sBreachingNumerator' THEN c.S135sBreachingDenominator
	WHEN MeasureName = 'S136sBreachingNumerator' THEN c.S136sBreachingDenominator
	ELSE NULL END AS MeasureDenominator, -- The relevant denominator (changes depending on the measure name) is provided alongside the measure value, and both are used to calculate rates & proportions in Tableau
c.CCGPopulation AS CCGPopDenom,
c.STPPopulation AS STPPopDenom,
c.RegionPopulation AS RegionPopDenom,
c.EnglandPopulation AS EnglandPopulation

INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMetric c

UNPIVOT (MeasureValue FOR MeasureName IN (
	c.ActiveUses, 
	c.NewUses, 
	c.ActiveUsesInYear, 
	c.DurationEpisodeNumerator,
	c.DurationSeriesEpisodesPart2Numerator,
	c.DurationSeriesEpisodesPart3Numerator,
	c.S2toS3Numerator,
	c.S136toS2S3Numerator,
	c.NewEpisodeRepeatNumerator,
	c.S135sBreachingNumerator,
	c.S136sBreachingNumerator,
	c.ValidEthnicity, 
	c.NoValidEthnicity,
	c.StartAtMidnightOrMidday,
	c.DidntStartAtMidnightOrMidday,
	c.StartOnTheHour,
	c.DidntStartOnTheHour,
	c.ValidSectionType, 
	c.NoValidSectionType,
	c.OtherActsOrInformalSectionType,
	c.LastFlowedNoEndDate,
	c.ClosedWithEndDate)) c
	   
---------- ADMISSIONS -----------
---------------------------------

----- Create a table of all admissions in the reporting period

--DECLARE @STARTRP INT
--SET @STARTRP = 1429 -- April 2019 (display data from this date in the dashboard)

--DECLARE @ENDRP INT
--SET @ENDRP = (SELECT (MAX(UniqMonthID)) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE Der_MostRecentFlag = 'P') -- Performance

--DECLARE @ENDRPDATE DATE
--SET @ENDRPDATE = (SELECT MAX(ReportingPeriodEndDate) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE UniqMonthID = @ENDRP)

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Admissions') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Admissions

SELECT 
r.Der_Person_ID,
r.RecordNumber,
r.UniqMonthID,
r.OrgIDProv,
o.Organisation_Name as ProvName,
CASE WHEN o.NHSE_Organisation_Type IN ('COMMUNITY TRUST', 'ACUTE TRUST', 'CARE TRUST', 'MENTAL HEALTH AND LEARNING DISABILITY') THEN 'NHS'
	WHEN o.NHSE_Organisation_Type IN ('NON-NHS ORGANISATION', 'INDEPENDENT SECTOR HEALTHCARE PROVIDER') THEN 'NON-NHS'
	WHEN o.NHSE_Organisation_Type IS NULL THEN 'UNKNOWN'
	WHEN o.NHSE_Organisation_Type = 'UNKNOWN' THEN 'UNKNOWN'
	ELSE 'OTHER' END AS NHSE_Organisation_Type, -- Categorise organisations into NHS vs Non-NHS
COALESCE(cc.New_Code, m.OrgIDCCGRes) AS OrgIDCCGRes, -- Obtain geographic information
map.Organisation_Name AS CCGName,
map.STP_Code,
map.STP_Name,
map.Region_Code,
map.Region_Name,
r.UniqServReqID,
r.UniqHospProvSpellID,
r.StartDateHospProvSpell AS StartDateAd, -- Start and end date and times for the admissions
r.StartTimeHospProvSpell AS StartTimeAd, 
r.DischDateHospProvSpell AS EndDateAd,
r.DischTimeHospProvSpell AS EndTimeAd, 
f.Month_End AS ReportingPeriodEndAd, -- Get the reporting period related to the start of the hospital spell / the admission
CASE WHEN r.SourceAdmMHHospProvSpell = '19' THEN 'Usual place of residence'
	WHEN r.SourceAdmMHHospProvSpell = '29' THEN 'Temporary place of residence'
	WHEN r.SourceAdmMHHospProvSpell IN ('37', '40', '42') THEN 'Criminal setting'
	WHEN r.SourceAdmMHHospProvSpell IN ('49', '51', '52', '53') THEN 'NHS healthcare provider'
	WHEN r.SourceAdmMHHospProvSpell = '87' THEN 'Independent sector healthcare provider' 
	WHEN r.SourceAdmMHHospProvSpell IN ('55', '56', '66', '88') THEN 'Other'
	WHEN r.SourceAdmMHHospProvSpell = NULL THEN 'Null'
	ELSE 'Missing/Invalid' END AS SourceOfAdmission, -- Create source of admission groups
--CASE WHEN r.DestOfDischHospProvSpell = '19' THEN 'Usual place of residence'
--	WHEN r.DestOfDischHospProvSpell = '29' THEN 'Temporary place of residence'
--	WHEN r.DestOfDischHospProvSpell IN ('37', '40', '42') THEN 'Criminal setting'
--	WHEN r.DestOfDischHospProvSpell IN ('49', '51', '52', '53', '30', '50') THEN 'NHS healthcare provider'
--	WHEN r.DestOfDischHospProvSpell IN ('87', '84') THEN 'Independent sector healthcare provider' 
--	WHEN r.DestOfDischHospProvSpell = '79' THEN 'Died'
--	WHEN r.DestOfDischHospProvSpell IN ('55', '56', '66', '88', '48', '89') THEN 'Other'
--	WHEN r.DestOfDischHospProvSpell = NULL THEN 'Null'
--	ELSE 'Missing/Invalid' END AS DischargeDestination, -- Create place discharged to groups
CASE WHEN m.AgeRepPeriodStart < 18 THEN '0-17'
	WHEN m.AgeRepPeriodStart BETWEEN 18 AND 24 THEN '18-24'
	WHEN m.AgeRepPeriodStart BETWEEN 25 AND 34 THEN '25-34'
	WHEN m.AgeRepPeriodStart BETWEEN 35 AND 44 THEN '35-44'
	WHEN m.AgeRepPeriodStart BETWEEN 45 AND 54 THEN '45-54'
	WHEN m.AgeRepPeriodStart BETWEEN 55 AND 64 THEN '55-64'
	WHEN m.AgeRepPeriodStart > 64 THEN '65+' 
	ELSE 'Missing/Invalid' END AS AgeBand, -- Create age bands
ISNULL(i.SpecialisedMHServiceCode, 'Non Specialised Service') AS SpecialisedMHServiceCode, -- Identify if and what specialised activity the spell relates to
CASE WHEN hs.OrgIDComm IN ('13N', '13R', '13V', '13X', '13Y', '14C', '14D', '14E', '14F', '14G', '85J', '27T', '14A', '14E', '14G', '14F', '13R','L5H9Q',
	'N8S0C','Q7O8U','X8H3R','P7L6U','F3I2L','S7T0C','Z1U2L','C9Z7X','F9H5S','K5B5Y','S6Z6H','J3T7D','I0H0N','O5V1Z','E2S1E','A8R9E','S5L0S','N5T4E','O6H3T',
	'I2T5F','K4Z4O','Z0X9Q','B9Q0L','I3Q3V','X4I1M','N9S3D','D8D1G','Z4P6N','D4U5V','P9W2J','L4H0W','B5S8O','G1U9X','X6C7V','C8S2X','R7G8O','H3F5A','I4B8X',
	'X4L0A','B0N9F','N5E8H','M4X2K','A3Y0R','W6B3O','O1N4A','Z0B3G') THEN 'Yes'
	ELSE 'No' END AS SpecCommCode, 
ROW_NUMBER()OVER(PARTITION BY r.Der_Person_ID, r.UniqHospProvSpellID ORDER BY r.UniqMonthID DESC) AS MostRecentFlagSpells -- Identifies most recent month a hospital spell is flowed
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Admissions
FROM [NHSE_MHSDS].[dbo].[MHS501HospProvSpell] r -- Get all hospital spells in the reporting period
LEFT JOIN NHSE_MHSDS.dbo.MHS001MPI m on r.RecordNumber = m.RecordNumber -- Obtain age information
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o ON m.OrgIDProv = o.Organisation_Code -- Obtain geographic information 
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON m.OrgIDCCGRes = cc.Org_Code
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies map ON COALESCE(cc.New_Code, m.OrgIDCCGRes) = map.Organisation_Code -- Join to map to obtain provider to CCG / STP / region mappings
LEFT JOIN NHSE_MHSDS.dbo.MHS502WardStay i ON i.RecordNumber = r.RecordNumber AND i.UniqHospProvSpellID = r.UniqHospProvSpellID -- Get specialised activity information for each admission / hospital spell, for each month. May be bringing in duplicates via multiple ward stays, but 'duplicates' flag and select distinct in metrics will void these.
LEFT JOIN NHSE_MHSDS.dbo.MHS512HospSpellComm hs ON hs.RecordNumber = r.RecordNumber AND hs.UniqHospProvSpellID = r.UniqHospProvSpellID -- Get specialised activity information for each admission / hospital spell, for each month. May be bringing in duplicates via multiple ward stays, but 'duplicates' flag and select distinct in metrics will void these.
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Dates_Full] f ON r.StartDateHospProvSpell = f.Full_Date -- Obtain date info for start date of hospital spell 
INNER JOIN [NHSE_MHSDS].[dbo].[MHSDS_SubmissionFlags] s ON r.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y' -- Obtain only the latest submitted data via the MSM
WHERE m.UniqMonthID >= @STARTRP AND m.UniqMonthID <= @ENDRP
AND (m.LADistrictAuth lIKE 'E%' OR m.LADistrictAuth IS NULL) 

--DECLARE @ENDRP INT
--SET @ENDRP = (SELECT (MAX(UniqMonthID)) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE Der_MostRecentFlag = 'P') -- Performance

----- Get one row per admissions and identify whether the hospital spell is open, closed or inactive

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsCat') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsCat

SELECT
a.*,
CASE WHEN a.EndDateAd IS NOT NULL THEN 'Closed'
	WHEN a.EndDateAd IS NULL AND a.UniqMonthID = @ENDRP THEN 'Open'
	WHEN a.EndDateAd IS NULL AND a.UniqMonthID <@ENDRP THEN 'Inactive'
	END AS AdmissionCat
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsCat
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Admissions a
WHERE a.MostRecentFlagSpells = 1 -- Ensure there is only 1 row per admission

----- Get one for per MHA episode, with spell information

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfoOneRow') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfoOneRow

SELECT
c.*
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfoOneRow
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfo c
WHERE c.MostRecentFlagSpells = 1 -- Ensure there is only 1 row per episode

----- Create admissions master

--DECLARE @ENDRP INT
--SET @ENDRP = (SELECT (MAX(UniqMonthID)) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE Der_MostRecentFlag = 'P') -- Performance

--DECLARE @ENDRPDATE DATE
--SET @ENDRPDATE = (SELECT MAX(ReportingPeriodEndDate) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE UniqMonthID = @ENDRP)

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMaster') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMaster

SELECT 
a.*,
CASE WHEN a.SpecCommCode = 'Yes' THEN s.SpecialisedServiceCodeDescription ELSE 'Non Specialised Service' END AS SpecialisedServiceCodeDescription,
CASE WHEN a.SpecCommCode = 'Yes' THEN s.SpecialisedMentalHealthServiceCategoryDescription ELSE 'Non Specialised Service' END AS SpecialisedMentalHealthServiceCategoryDescription,

-- Flag when an admission has an episode related to it
CASE WHEN DATEDIFF(minute, CAST(a.StartDateAd AS DATETIME) + CAST(a.StartTimeAd AS DATETIME), CAST(b.StartDate AS DATETIME) + CAST(b.StartTime AS DATETIME)) BETWEEN -1440 and 1440 AND b.Prev_SectionType IS NULL THEN 1 ELSE 0 END AS AdmissionWithin24HourssOfDetentionFlag, -- Flag if an admission is within 24 hours of an episode starting
CASE WHEN DATEDIFF(minute, CAST(a.StartDateAd AS DATETIME) + CAST(a.StartTimeAd AS DATETIME), CAST(b.StartDate AS DATETIME) + CAST(b.StartTime AS DATETIME)) > 1440 
AND ((a.AdmissionCat <> 'Open' AND  CAST(b.StartDate AS DATETIME) + CAST(b.StartTime AS DATETIME) <= CAST(a.EndDateAd AS DATETIME) + CAST(a.EndTimeAd AS DATETIME)) 
OR (a.AdmissionCat = 'Open' AND CAST(b.StartDate AS DATETIME) + CAST(b.StartTime AS DATETIME) <= @ENDRPDate)) 
AND b.Prev_SectionType IS NULL THEN 1 ELSE 0 END AS AdmissionsWithDetention24HoursAfterFlag, -- Flag if an admission has an episode start over 24 hours after but during the hospital spell (or the reporting period if the spell is still open), and only count the first episode in a series of episodes (the point of detention)
-- ^ possible to tidy up with an ISNULL? May not be given we don't want to use @ENDRPDate for Inactive eps (which will have a NULL end date)
ROW_NUMBER()OVER(PARTITION BY a.UniqHospProvSpellID ORDER BY b.StartDate, b.StartDate ASC) AS FirstEpRelatedToAdmission -- Only keep the first episode related to the admission
-- DATEDIFF(minute, CAST(a.StartDateAd AS DATETIME) + CAST(a.StartTimeAd AS DATETIME), CAST(b.StartDate AS DATETIME) + CAST(b.StartTime AS DATETIME)) AS TimeBetween -- For one off analysis (not for the dashboard)
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMaster
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsCat a
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfoOneRow b ON a.Der_Person_ID = b.Der_Person_ID AND a.OrgIDProv = b.OrgIDProv 
AND (CAST(b.StartDate AS DATETIME) + CAST(b.StartTime AS DATETIME)) BETWEEN DATEADD(HOUR,-24, CAST(a.StartDateAd AS DATETIME) + CAST(a.StartTimeAd AS DATETIME)) AND (CASE WHEN a.AdmissionCat = 'Open' THEN @ENDRPDate ELSE CAST(a.EndDateAd AS DATETIME) + CAST(a.EndTimeAd AS DATETIME) END) -- Only bring in episodes related to an admission
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_SpecialisedMHServiceCatCodes s ON a.SpecialisedMHServiceCode = s.SpecialisedMentalHealthServiceCategoryCode

----- Create admission metrics

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMetrics') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMetrics

SELECT
h.ReportingPeriodEndAd,
h.OrgIDProv,
h.ProvName,
h.NHSE_Organisation_Type,
h.OrgIDCCGRes,
h.CCGName,
h.STP_Code,
h.STP_Name,
h.Region_Code,
h.Region_Name,
h.AgeBand,
h.SourceOfAdmission,
--h.DischargeDestination,
ISNULL (h.SpecialisedServiceCodeDescription, 'Non Specialised Service') AS SpecialisedServiceCodeDescription,
ISNULL (h.SpecialisedMentalHealthServiceCategoryDescription, 'Non Specialised Service') AS SpecialisedMentalHealthServiceCategoryDescription,

-- Counting distinct admissions because a single admission can have multiple episodes associated with it

-- New admissions (spells that started in that month) 
COUNT (DISTINCT (h.UniqHospProvSpellID)) AS NewAdmissions,

-- New admissions where a detention occured within 24 hours or the admission (either side)
COUNT (DISTINCT (CASE WHEN AdmissionWithin24HourssOfDetentionFlag = 1 THEN h.UniqHospProvSpellID ELSE NULL END)) AS AdmissionWithin24HourssOfDetention,

-- New admissions where a detention occured more than 24 hours after admission
COUNT (DISTINCT (CASE WHEN AdmissionsWithDetention24HoursAfterFlag = 1 THEN h.UniqHospProvSpellID ELSE NULL END)) AS AdmissionsWithDetention24HoursAfter,

-- New admission where a detention occured (combined both above)
--COUNT (DISTINCT (CASE WHEN ((h.TimeToDetentionMinutes > 1440 AND h.MHAStartDateTime <= ISNULL(h.AdEndDateTime,@ENDRPDATE))
--OR ((h.TimeToDetentionMinutes <= 1440 AND h.TimeToDetentionMinutes >= 0) 
--OR (h.TimeToAdmissionMinutes <= 1440 AND h.TimeToAdmissionMinutes >= 0))) THEN h.UniqHospProvSpellID  ELSE NULL END)) AS AnyUnderTheAct,

-- Replicate new admissions for denominator, to produce percentages in Tableau
COUNT (DISTINCT (h.UniqHospProvSpellID)) AS NewAdmissionsDenom -- Denom

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMetrics
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMaster h
WHERE FirstEpRelatedToAdmission = 1
GROUP BY h.ReportingPeriodEndAd, h.OrgIDProv, h.ProvName, h.OrgIDCCGRes, h.CCGName, h.STP_Code, h.STP_Name, h.Region_Code, h.Region_Name, h.NHSE_Organisation_Type, h.AgeBand, h.SourceOfAdmission, h.SpecialisedServiceCodeDescription, h.SpecialisedMentalHealthServiceCategoryDescription -- h.DischargeDestination

----- Pivot into long format into Dashboard_MHA_Admissions

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA_Admissions
 
SELECT 
a.ReportingPeriodEndAd AS ReportingPeriodEnd,
a.OrgIDProv,
a.ProvName,
a.NHSE_Organisation_Type,
a.OrgIDCCGRes,
a.CCGName,
a.STP_Code,
a.STP_Name,
a.Region_Code,
a.Region_Name,
a.AgeBand,
a.SourceOfAdmission,
-- a.DischargeDestination,
a.SpecialisedServiceCodeDescription,
a.SpecialisedMentalHealthServiceCategoryDescription,
MeasureName, -- MeasureName now includes all measures calculated above / included in the unpivot below
MeasureValue, -- MeasureValue will change depending on the MeasureName
CASE WHEN MeasureName IN ('AdmissionWithin24HourssOfDetention', 'AdmissionsWithDetention24HoursAfter', 'AnyUnderTheAct') THEN a.NewAdmissionsDenom
	ELSE NULL END AS Denominator -- The relevant denominator (given the measure name) is provided alongside the measure value, both are used to calculate proportions in Tableau
INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA_Admissions
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMetrics a 

UNPIVOT (MeasureValue FOR MeasureName IN (
	a.NewAdmissions, 
	a.AdmissionWithin24HourssOfDetention, 
	a.AdmissionsWithDetention24HoursAfter
	-- a.AnyUnderTheAct
	)) a 

---------------------
----- PEOPLE --------
---------------------

--DECLARE @STARTRP INT
--SET @STARTRP = 1429 -- April 2019 (reporting period - display data from this date in the dashboard)

---------- Create people master using cases master

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster

SELECT
c.Der_Person_ID,
c.UniqMonthID,
c.ReportingPeriodEnd,
c.ReportingPeriodStart,
c.FY_Reporting_Period_Start,
c.OrgIDProv,
c.ProvName,
c.NHSE_Organisation_Type,
c.OrgIDCCGRes,
c.CCGName,
c.STP_Code,
c.STP_Name,
c.Region_Code,
c.Region_Name,
c.SectionType,
c.SectionName,
c.SectionGroup,
c.AgeBand,
mp.EthnicCategory,
CASE WHEN mp.EthnicCategory = 'A' THEN 'White British' 
	WHEN mp.EthnicCategory IN ('B', 'C') THEN 'White Other' 
	WHEN mp.EthnicCategory IN ('D', 'E', 'F', 'G') THEN 'Mixed' 
	WHEN mp.EthnicCategory IN ('H', 'J', 'K', 'L') THEN 'Asian' 
	WHEN mp.EthnicCategory IN ('M', 'N', 'P') THEN 'Black' 
	WHEN mp.EthnicCategory IN ('R', 'S') THEN 'Other' 
	ELSE 'Missing/Invalid' END AS EthnicityCat, -- Create/assign ethnicity groups
CASE WHEN mp.EthnicCategory = 'A' THEN 'White British' 
	WHEN mp.EthnicCategory = 'B' THEN 'White Irish'
	WHEN mp.EthnicCategory = 'C' THEN 'Any other White background'
	WHEN mp.EthnicCategory = 'D' THEN 'White and Black Caribbean'
	WHEN mp.EthnicCategory = 'E' THEN 'White and Black African'
	WHEN mp.EthnicCategory = 'F' THEN 'White and Asian'
	WHEN mp.EthnicCategory = 'G' THEN 'Any other mixed background'
	WHEN mp.EthnicCategory = 'H' THEN 'Indian'
	WHEN mp.EthnicCategory = 'J' THEN 'Pakistani'
	WHEN mp.EthnicCategory = 'K' THEN 'Bangladeshi'
	WHEN mp.EthnicCategory = 'L' THEN 'Any other Asian background'
	WHEN mp.EthnicCategory = 'M' THEN 'Caribbean'
	WHEN mp.EthnicCategory = 'N' THEN 'African'
	WHEN mp.EthnicCategory = 'P' THEN 'Any other Black background'
	WHEN mp.EthnicCategory = 'L' THEN 'Chinese'
	WHEN mp.EthnicCategory = 'M' THEN 'Any other ethnic group'
	ELSE 'Missing/Invalid' END AS EthnicityCatGran, -- Create/assign granular ethnicity groups
CASE WHEN mp.Gender = '1' THEN 'Male' 
	WHEN mp.Gender = '2' THEN 'Female' 
	WHEN mp.Gender IN ('3', '4', '9') THEN 'Other' 
	ELSE 'Missing/Invalid' END AS GenderCat, -- Create/assign gender groups
CASE WHEN d.IMD_Decile IN ('1', '2') THEN 'Quintile 1' 
	WHEN d.IMD_Decile IN ('3', '4') THEN 'Quintile 2' 
	WHEN d.IMD_Decile IN ('5', '6') THEN 'Quintile 3' 
	WHEN d.IMD_Decile IN ('7', '8') THEN 'Quintile 4' 
	WHEN d.IMD_Decile IN ('9', '10') THEN 'Quintile 5' 
	ELSE 'Missing/Invalid' END AS DeprivationQuintile, -- Create/assign deprivation quintiles
c.CCGPopulation,
c.STPPopulation,
c.RegionPopulation,
c.SpecialisedServiceCodeDescription,
c.SpecialisedMentalHealthServiceCategoryDescription,
c.StartedInMonthFlag, -- Use the started in month flag from cases
c.StartedInYearFlag, -- Use the started in year flag created specifically for use here
c.RepeatSeriesIn180DaysFlag,
ROW_NUMBER()OVER(PARTITION BY c.Der_Person_ID, c.FY_Reporting_Period_Start ORDER BY c.UniqMonthID ASC) AS UniqPersonInYearFlag, -- A flag so a person is not counted more than once in a year
ROW_NUMBER()OVER(PARTITION BY c.Der_Person_ID, c.FY_Reporting_Period_Start, c.SectionType ORDER BY c.UniqMonthID ASC) AS UniqPersonSectionTypeInYearFlag -- A flag so a person is not counted more than once in a year, for each section type
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMaster c -- Get all information on uses of the MHA
LEFT JOIN NHSE_MHSDS.dbo.MHS001MPI mp on mp.RecordNumber = c.RecordNumber -- Add in demographic information
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Deprivation_By_LSOA] d ON mp.LSOA2011 = d.LSOA_Code AND d.Effective_Snapshot_Date = '2019-12-31' -- And obtain IMD decile from LSOA code of residence
WHERE C.UniqMonthID >= @STARTRP 

---------- Create metrics from People Master

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMetric') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMetric

-- ENGLAND, SECTION BREAKDOWN, all groupings
SELECT
'England' AS GeographyType,
'ENGLAND' AS [Geography],
p.SectionGroup AS SectionGroup,
p.SectionName AS SectionType, 
p.ReportingPeriodEnd AS ReportingPeriodEnd,
NULL AS CCGDenom,
NULL AS STPDenom,
NULL AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
NULL AS PeopleWithNewCasesInRepeatSeries,
NULL AS PeopleWithNewCasesDenom
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMetric
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.SectionName, p.SectionGroup

UNION ALL

-- ENGLAND, all sections, all groupings
SELECT
'England' AS GeographyType,
'ENGLAND' AS [Geography],
'All sections' AS SectionGroup,
'All sections' AS SectionType, 
p.ReportingPeriodEnd AS ReportingPeriodEnd,
NULL AS CCGDenom,
NULL AS STPDenom,
NULL AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 AND p.RepeatSeriesIn180DaysFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInRepeatSeries,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd

UNION ALL

-- REGIONS, SECTION BREAKDOWN, all groupings
SELECT
'Region' AS GeographyType,
p.Region_Name AS [Geography],
p.SectionGroup AS SectionGroup,
p.SectionName AS SectionType, -- For all Sections first
p.ReportingPeriodEnd AS ReportingPeriodEnd,
NULL AS CCGDenom,
NULL AS STPDenom,
MAX(p.RegionPopulation) AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
NULL AS PeopleWithNewCasesInRepeatSeries,
NULL AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.SectionName, p.Region_Name, p.SectionGroup

UNION ALL

-- REGIONS, all sections, all groupings
SELECT
'Region' AS GeographyType,
p.Region_Name AS [Geography],
'All sections' AS SectionGroup,
'All sections' AS SectionType, 
p.ReportingPeriodEnd AS ReportingPeriodEnd,
NULL AS CCGDenom,
NULL AS STPDenom,
MAX(p.RegionPopulation) AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 AND p.RepeatSeriesIn180DaysFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInRepeatSeries,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.Region_Name

UNION ALL

-- STPS, SECTION BREAKDOWN, all groupings
SELECT
'STP' AS GeographyType,
p.STP_Name AS [Geography],
p.SectionGroup AS SectionGroup,
p.SectionName AS SectionType, -- For all Sections first
p.ReportingPeriodEnd AS ReportingPeriodEnd,
NULL AS CCGDenom,
MAX(p.STPPopulation) AS STPDenom,
NULL AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
NULL AS PeopleWithNewCasesInRepeatSeries,
NULL AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.SectionName, p.STP_Name, p.SectionGroup

UNION ALL

-- STPS, all sections, all groupings
SELECT
'STP' AS GeographyType,
p.STP_Name AS [Geography],
'All sections' AS SectionGroup,
'All sections' AS SectionType, 
p.ReportingPeriodEnd AS ReportingPeriodEnd,
NULL AS CCGDenom,
MAX(p.STPPopulation) AS STPDenom,
NULL AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 AND p.RepeatSeriesIn180DaysFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInRepeatSeries,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.STP_Name

UNION ALL

-- CCGS, SECTION BREAKDOWN, all groupings
SELECT
'CCG' AS GeographyType,
p.CCGName AS [Geography],
p.SectionGroup AS SectionGroup,
p.SectionName AS SectionType, -- For all Sections first
p.ReportingPeriodEnd AS ReportingPeriodEnd,
MAX(p.CCGPopulation) AS CCGDenom,
NULL AS STPDenom,
NULL AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
NULL AS PeopleWithNewCasesInRepeatSeries,
NULL AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.SectionName, p.CCGName, p.SectionGroup

UNION ALL

-- CCGS, all sections, all groupings
SELECT
'CCG' AS GeographyType,
p.CCGName AS [Geography],
'All sections' AS SectionGroup,
'All sections' AS SectionType, 
p.ReportingPeriodEnd AS ReportingPeriodEnd,
MAX(p.CCGPopulation) AS CCGDenom,
NULL AS STPDenom,
NULL AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 AND p.RepeatSeriesIn180DaysFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInRepeatSeries,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.SectionName, p.CCGName, p.SectionGroup

UNION ALL

-- PROVIDERS, SECTION BREAKDOWN, all groupings
SELECT
'Provider' AS GeographyType,
p.ProvName AS [Geography],
p.SectionGroup AS SectionGroup,
p.SectionName AS SectionType, -- For all Sections first
p.ReportingPeriodEnd AS ReportingPeriodEnd,
NULL AS CCGDenom,
NULL AS STPDenom,
NULL AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonSectionTypeInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
NULL AS PeopleWithNewCasesInRepeatSeries,
NULL AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.SectionName, p.ProvName, p.SectionGroup

UNION ALL

-- PROVIDERS, all sections, all groupings
SELECT
'Provider' AS GeographyType,
p.ProvName AS [Geography],
'All sections' AS SectionGroup,
'All sections' AS SectionType, 
p.ReportingPeriodEnd AS ReportingPeriodEnd,
NULL AS CCGDenom,
NULL AS STPDenom,
NULL AS RegionDenom,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCases,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases,
COUNT (DISTINCT (CASE WHEN p.StartedInYearFlag = 1 AND p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInYear,
COUNT (DISTINCT (CASE WHEN p.UniqPersonInYearFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithActiveCasesInYear,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 AND p.RepeatSeriesIn180DaysFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesInRepeatSeries,
COUNT (DISTINCT (CASE WHEN p.StartedInMonthFlag = 1 THEN p.Der_Person_ID ELSE NULL END)) AS PeopleWithNewCasesDenom
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p
GROUP BY p.ReportingPeriodEnd, p.SectionName, p.ProvName, p.SectionGroup 

---------- Pivot final table into long format and refresh 'Dashboard_MHA_People'

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA_People
 
SELECT 
p.GeographyType,
p.[Geography],
p.SectionGroup,
p.SectionType,
p.ReportingPeriodEnd, 
p.CCGDenom,
p.STPDenom,
p.RegionDenom,
MeasureName, -- MeasureName now includes all measures calculated above / included in the unpivot below
MeasureValue, -- MeasureValue will change depending on the MeasureName
CASE WHEN MeasureName = 'PeopleWithNewCasesInRepeatSeries' THEN p.PeopleWithNewCasesDenom
	ELSE NULL END AS MeasureDenominator -- The relevant denominator (changes depending on the measure name) is provided alongside the measure value, and both are used to calculate rates & proportions in Tableau

INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA_People
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMetric p

UNPIVOT (MeasureValue FOR MeasureName IN (
	p.PeopleWithNewCases,
	p.PeopleWithActiveCases,
	p.PeopleWithNewCasesInYear,
	p.PeopleWithActiveCasesInYear,
	p.PeopleWithNewCasesInRepeatSeries)) p
	   	 
---------------------
--- Demographics ----
---------------------

--DECLARE @ENDRP INT
--SET @ENDRP = (SELECT (MAX(UniqMonthID)) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE Der_MostRecentFlag = 'P') -- Performance

---------- Create LDA flag (whether someone has a suspected learning disability or autism)

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeople') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeople

SELECT 
DISTINCT d.Der_Person_ID, d.UniqMonthID
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeople
FROM [NHSE_MHSDS].[dbo].[MHS007DisabilityType] d
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = d.Der_Person_ID AND p.UniqMonthID = d.UniqMonthID
WHERE d.DisabCode = '04'

UNION -- Not UNION ALL, so that if a person fits under multiple criteria they are only recorded once

SELECT 
DISTINCT w.Der_Person_ID, w.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS502WardStay] w
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID, p.ReportingPeriodStart FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = w.Der_Person_ID AND p.UniqMonthID = w.UniqMonthID
WHERE (w.WardType = '05' AND (w.EndDateWardStay IS NULL OR w.EndDateWardStay >= p.ReportingPeriodStart)) 
OR (w.IntendClinCareIntenCodeMH IN ('61', '62', '63') AND (w.EndDateWardStay IS NULL OR w.EndDateWardStay >= p.ReportingPeriodStart))

UNION

SELECT 
DISTINCT c.Der_Person_ID, c.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS006MHCareCoord] c
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID, p.ReportingPeriodStart FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = c.Der_Person_ID AND p.UniqMonthID = c.UniqMonthID
WHERE c.CareProfServOrTeamTypeAssoc IN ('B02', 'C01', 'E01', 'EO2', 'E03') AND (c.EndDateAssCareCoord IS NULL OR c.EndDateAssCareCoord >= p.ReportingPeriodStart) 

UNION

SELECT 
DISTINCT m.Der_Person_ID, m.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS401MHActPeriod] m
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID, p.ReportingPeriodStart FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = m.Der_Person_ID AND p.UniqMonthID = m.UniqMonthID
WHERE m.MentalCat = 'B' AND (m.EndDateMHActLegalStatusClass IS NULL OR m.ExpiryDateMHActLegalStatusClass IS NULL OR m.EndDateMHActLegalStatusClass >= p.ReportingPeriodStart OR m.ExpiryDateMHActLegalStatusClass >= p.ReportingPeriodStart)

UNION

SELECT 
DISTINCT a.Der_Person_ID, a.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS503AssignedCareProf] a
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID, p.ReportingPeriodStart FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = a.Der_Person_ID AND p.UniqMonthID = a.UniqMonthID
WHERE a.TreatFuncCodeMH = '700' AND (a.EndDateAssCareProf IS NULL OR a.EndDateAssCareProf >= p.ReportingPeriodStart) 

UNION

SELECT 
DISTINCT pr.Der_Person_ID, pr.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS603ProvDiag] pr
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = pr.Der_Person_ID AND p.UniqMonthID = pr.UniqMonthID
WHERE (pr.DiagSchemeInUse = '02' AND pr.ProvDiag like 'F7%') OR (pr.DiagSchemeInUse = '02' AND pr.ProvDiag like 'F84%')

UNION

SELECT 
DISTINCT pm.Der_Person_ID, pm.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS604PrimDiag] pm
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = pm.Der_Person_ID AND p.UniqMonthID = pm.UniqMonthID
WHERE (pm.DiagSchemeInUse = '02' AND pm.PrimDiag like 'F7%') OR (pm.DiagSchemeInUse = '02' AND pm.PrimDiag like 'F84%')

UNION

SELECT 
DISTINCT s.Der_Person_ID, s.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS605SecDiag] s
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = s.Der_Person_ID AND p.UniqMonthID = s.UniqMonthID
WHERE (s.DiagSchemeInUse = '02' AND s.SecDiag like 'F7%') OR (s.DiagSchemeInUse = '02' AND s.SecDiag like 'F84%')

UNION

SELECT 
DISTINCT c.Der_Person_ID, c.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS801ClusterTool] c
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = c.Der_Person_ID AND p.UniqMonthID = c.UniqMonthID
WHERE c.ClustCat IN ('03', '05')

UNION

SELECT 
DISTINCT s.Der_Person_ID, s.UniqMonthID
FROM [NHSE_MHSDS].[dbo].[MHS102ServiceTypeReferredTo] s
INNER JOIN (SELECT DISTINCT p.Der_Person_ID, p.UniqMonthID, p.ReportingPeriodStart FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p) p ON p.Der_Person_ID = s.Der_Person_ID AND p.UniqMonthID = s.UniqMonthID
WHERE s.ServTeamTypeRefToMH IN ('B02', 'C01', 'E01', 'E02', 'E03') AND ((s.ReferClosureDate IS NULL OR s.ReferClosureDate >= p.ReportingPeriodStart) AND (s.ReferRejectionDate IS NULL OR s.ReferRejectionDate >= p.ReportingPeriodStart)) -- do I also need to add AND (ReferClosureDate IS NULL OR ReferClosureDate >= ReportingPeriodStart) AND (ReferRejectionDate IS NULL OR ReferRejectionDate >= ReportingPeriodStart)

----- Flag anyone identified above as suspected LDA

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeopleflag') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeopleflag

SELECT l.*,
'LDA' AS LDAFlag -- Give everyone identified as LDA the label 'LDA'
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeopleFlag
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeople l

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMasterLDA') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMasterLDA

SELECT p.*, 
CASE WHEN l.LDAFlag = 'LDA' THEN 'LDA' ELSE 'Not LDA' END AS LDAFlag
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMasterLDA
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster p 
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeopleflag l ON p.Der_Person_ID = l.Der_Person_ID AND p.UniqMonthID = l.UniqMonthID -- Join LDA labels to people master

---------- Create a 12 month rolling people master. For each month, anyone who had an episode in that month and the prior 11 months will be recorded.

--DECLARE @ENDRP INT
--SET @ENDRP = (SELECT (MAX(UniqMonthID)) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header WHERE Der_MostRecentFlag = 'P') -- Performance

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemo') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemo

SELECT
a.*,
a.UniqMonthID + (ROW_NUMBER() OVER(PARTITION BY a.Der_Person_ID, a.UniqMonthID ORDER BY a.UniqMonthID ASC) -1) AS Der_MonthID -- Add digit to UniqMonth to ensure it is recorded under past months
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemo
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMasterLDA a
CROSS JOIN MASTER..spt_values AS n WHERE n.type = 'p' AND n.number BETWEEN a.UniqMonthID AND a.UniqMonthID + 11 -- Join 11 times onto reference data to duplicate data

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemoWDate') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemoWDate

SELECT r.*,
h.ReportingPeriodEndDate -- Obtain reporting period for derived UniqMonth
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemoWDate
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemo r
LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] h ON r.Der_MonthID = h.UniqMonthID WHERE r.Der_MonthID <= @ENDRP

---------- Change groupings so 136 is separate from other STOs so we can look at it separately in Tableau

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster

SELECT
r.*,
CASE WHEN r.SectionType IN ('07', '08', '09', '10', '12', '13', '37', '38', '14', '15', '16', '17', '18', '31', '36') THEN 'Part 3' -- 35, 36, 37, 37 with 41 restrictions, 38, 44, 45A, 46, 47, 47 with 49 restrictions, 48, 48 with 49 restrictions, The Criminal Procedure (Insanity) Act 1964 as amended by the Criminal Procedures (Insanity and Unfitness to Plead) Act 1991; guardianship under Section 37
	WHEN r.SectionType IN ('04', '05', '06') THEN 'Other STO' -- Section 4, 5(2), 5(4)
	WHEN r.SectionType = '01' THEN 'Informal'
	WHEN r.SectionType = '02' THEN 'Section 2' 
	WHEN r.SectionType = '03' THEN 'Section 3'
	WHEN r.SectionType = '19' THEN 'Section 135'
	WHEN r.SectionType = '20' THEN 'Section 136'
	WHEN r.SectionType = '32' THEN 'Other cases'
	WHEN r.SectionType = '35' THEN 'Section 7 - guardianship'
	WHEN r.SectionType = 'CTO' THEN 'Community Treatment Order'
	WHEN r.SectionType = 'CTO Recall' THEN 'Community Treatment Order Recall'
	WHEN r.SectionType = 'CD' THEN 'Conditional Discharge'
	ELSE 'Missing/Invalid' END AS SectionGroupNew -- Create MHA groups
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemoWDate r

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleDemoMetric') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleDemoMetric

---------- Create metrics at each geographic and demographic level, for all sections and section groupings

-- ENGLAND, all sections, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleDemoMetric
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.AgeBand

UNION ALL

-- ENGLAND, all sections, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.GenderCat

UNION ALL

-- ENGLAND, all sections, ETHNICITY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCat

UNION ALL

-- ENGLAND, all sections, ETHNICITY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCatGran

UNION ALL

-- ENGLAND, all sections, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.DeprivationQuintile

UNION ALL

-- ENGLAND, all sections, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.LDAFlag

UNION ALL

-- ENGLAND, SECTION GROUPINGS BREAKDOWN, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
p.SectionGroupNew AS SectionGroupNew,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.AgeBand

UNION ALL

-- ENGLAND, SECTION GROUPINGS BREAKDOWN, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.GenderCat

UNION ALL

-- ENGLAND, SECTION GROUPINGS BREAKDOWN, ETHNICTY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCat

UNION ALL

-- ENGLAND, SECTION GROUPINGS BREAKDOWN, ETHNICTY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCatGran

UNION ALL

-- ENGLAND, SECTION GROUPINGS BREAKDOWN, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.DeprivationQuintile

UNION ALL

-- ENGLAND, SECTION GROUPINGS BREAKDOWN, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'England' AS GeographyType,
'ENG' AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.LDAFlag

UNION ALL

-- REGIONS, all sections, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.AgeBand, p.Region_Name

UNION ALL

-- REGIONS, all sections, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.GenderCat, p.Region_Name

UNION ALL

-- REGIONS, all sections, ETHNICITY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCat, p.Region_Name

UNION ALL

-- REGIONS, all sections, ETHNICITY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
'All' AS SectionGroupNew,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCatGran, p.Region_Name

UNION ALL

-- REGIONS, all sections, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.DeprivationQuintile, p.Region_Name

UNION ALL

-- REGIONS, all sections, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.LDAFlag, p.Region_Name

UNION ALL

-- REGIONS, SECTION GROUPINGS BREAKDOWN, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.AgeBand, p.Region_Name

UNION ALL

-- REGIONS, SECTION GROUPINGS BREAKDOWN, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.GenderCat, p.Region_Name

UNION ALL

-- REGIONS, SECTION GROUPINGS BREAKDOWN, ETHNICTY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCat, p.Region_Name

UNION ALL

-- REGIONS, SECTION GROUPINGS BREAKDOWN, ETHNICTY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCatGran, p.Region_Name

UNION ALL

-- REGIONS, SECTION GROUPINGS BREAKDOWN, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.DeprivationQuintile, p.Region_Name

UNION ALL

-- REGIONS, SECTION GROUPINGS BREAKDOWN, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'Region' AS GeographyType,
p.Region_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.LDAFlag, p.Region_Name

UNION ALL

-- STP, all sections, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.AgeBand, p.STP_Name

UNION ALL

-- STP, all sections, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.GenderCat, p.STP_Name

UNION ALL

-- STP, all sections, ETHNICITY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCat, p.STP_Name

UNION ALL

-- STP, all sections, ETHNICITY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
'All' AS SectionGroupNew,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCatGran, p.STP_Name

UNION ALL

-- STP, all sections, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.DeprivationQuintile, p.STP_Name

UNION ALL

-- STP, all sections, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.LDAFlag, p.STP_Name

UNION ALL

-- STP, SECTION GROUPINGS BREAKDOWN, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.AgeBand, p.STP_Name

UNION ALL

-- STP, SECTION GROUPINGS BREAKDOWN, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.GenderCat, p.STP_Name

UNION ALL

-- STP, SECTION GROUPINGS BREAKDOWN, ETHNICTY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCat, p.STP_Name

UNION ALL

-- STP, SECTION GROUPINGS BREAKDOWN, ETHNICTY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCatGran, p.STP_Name

UNION ALL

-- STP, SECTION GROUPINGS BREAKDOWN, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.DeprivationQuintile, p.STP_Name

UNION ALL

-- STP, SECTION GROUPINGS BREAKDOWN, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'STP' AS GeographyType,
p.STP_Name AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.LDAFlag, p.STP_Name

UNION ALL

-- CCG, all sections, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.AgeBand, p.CCGName

UNION ALL

-- CCG, all sections, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.GenderCat, p.CCGName

UNION ALL

-- CCG, all sections, ETHNICITY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCat, p.CCGName

UNION ALL

-- CCG, all sections, ETHNICITY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
'All' AS SectionGroupNew,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCatGran, p.CCGName

UNION ALL

-- CCG, all sections, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.DeprivationQuintile, p.CCGName

UNION ALL

-- CCG, all sections, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.LDAFlag, p.CCGName

UNION ALL

-- CCG, SECTION GROUPINGS BREAKDOWN, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.AgeBand, p.CCGName

UNION ALL

-- CCG, SECTION GROUPINGS BREAKDOWN, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.GenderCat, p.CCGName

UNION ALL

-- CCG, SECTION GROUPINGS BREAKDOWN, ETHNICTY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCat, p.CCGName

UNION ALL

-- CCG, SECTION GROUPINGS BREAKDOWN, ETHNICTY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCatGran, p.CCGName

UNION ALL

-- CCG, SECTION GROUPINGS BREAKDOWN, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.DeprivationQuintile, p.CCGName

UNION ALL

-- CCG, SECTION GROUPINGS BREAKDOWN, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'CCG' AS GeographyType,
p.CCGName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.LDAFlag, p.CCGName

UNION ALL

-- PROVIDERS, all sections, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.AgeBand, p.ProvName

UNION ALL

-- PROVIDER, all sections, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.GenderCat, p.ProvName

UNION ALL

-- PROIDER, all sections, ETHNICITY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCat, p.ProvName

UNION ALL

-- PROVIDER, all sections, ETHNICITY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
'All' AS SectionGroupNew,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.EthnicityCatGran, p.ProvName

UNION ALL

-- PROVIDER, all sections, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.DeprivationQuintile, p.ProvName

UNION ALL

--PROVIDER, all sections, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
'All' AS SectionGroup,
'All' AS SectionType,
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.LDAFlag, p.ProvName

UNION ALL

-- PROVIDER, SECTION GROUPINGS BREAKDOWN, AGE
SELECT
'Age' AS [Grouping],
p.AgeBand AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.AgeBand, p.ProvName

UNION ALL

-- PROVIDER, SECTION GROUPINGS BREAKDOWN, GENDER
SELECT
'Gender' AS [Grouping],
p.GenderCat AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.GenderCat, p.ProvName

UNION ALL

-- PROVIDER, SECTION GROUPINGS BREAKDOWN, ETHNICTY
SELECT
'Ethnicity' AS [Grouping],
p.EthnicityCat AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCat, p.ProvName

UNION ALL

-- PROVIDER, SECTION GROUPINGS BREAKDOWN, ETHNICTY GRAN
SELECT
'Ethnicity Granular' AS [Grouping],
p.EthnicityCatGran AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.EthnicityCatGran, p.ProvName

UNION ALL

-- PROVIDER, SECTION GROUPINGS BREAKDOWN, DEPRIVATION
SELECT
'Deprivation' AS [Grouping],
p.DeprivationQuintile AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.DeprivationQuintile, p.ProvName

UNION ALL

-- PROVIDER, SECTION GROUPINGS BREAKDOWN, LDA
SELECT
'LDA' AS [Grouping],
p.LDAFlag AS [Group],
'Provider' AS GeographyType,
p.ProvName AS [Geography],
p.SectionGroupNew AS SectionGroup,
'All' AS SectionType, -- For all Sections first
p.ReportingPeriodEndDate AS ReportingPeriodEnd,
COUNT (DISTINCT p.Der_Person_ID) AS PeopleWithActiveCases
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster p
GROUP BY p.ReportingPeriodEndDate, p.SectionGroupNew, p.LDAFlag, p.ProvName

---------- Select into Dashboard_MHA_Demo_People

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA_Demo_People
 
SELECT *
INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA_Demo_People
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleDemoMetric p
ORDER BY p.[Geography], p.SectionType, p.ReportingPeriodEnd

---------------------
--- DATA QUALITY ----
---------------------

---------- ECDS DQ

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ECDSDQ') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ECDSDQ

SELECT 
e.Der_Provider_Name,
e.MonthYear,
CASE WHEN e.Attendances_w_MHA > 0 THEN 1 ELSE 0 END AS ProvSubmittingMHAData,-- Idenfity if provider is submitting data
CASE WHEN e.Attendances_w_MHA = 0 THEN 1 ELSE 0 END AS ProvNOTSubmittingMHAData, -- Identify if provider is not submitting data
e.Attendances, 
e.Attendances_w_MHA, -- How many attendaces have MHA information?
e.MHA_records, 
e.MHA_records_val, -- How much MHA information is valid?
'ECDS' AS Dataset
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ECDSDQ
FROM [NHSE_Sandbox_MentalHealth].[dbo].[Staging_ECDS_MHA] e

---------- MHSDS DQ

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQ') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQ

SELECT 
o.Organisation_Name AS ProvName, -- Provider name,
ReportingPeriodStart,
CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS ProvSubmittingMHAData, -- Idenfity if provider is submitting data
CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS ProvNOTSubmittingMHAData, -- Identify if provider is not submitting data
NULL AS Attendances,
NULL AS Attendances_w_MHA,
NULL AS MHA_records, 
NULL AS MHA_records_val,
'MHSDS' AS Dataset
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQ
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfo c
LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o ON c.OrgIDProv = o.Organisation_Code -- Obtain provider name
GROUP BY Organisation_Name, ReportingPeriodStart

----- Created padded table of MHSDSDQ info for each provider/month combination using list of providers who should be submitting information

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_FullDates') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_FullDates

SELECT 
DISTINCT(c.ReportingPeriodStart) -- Get list of all possible month start dates
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_FullDates
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfo c

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Base') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Base

SELECT
s.ProvName,
s.OrgIDProv, -- Get list of all providers who should be submitting data, from MHA_Expected_Submitting_Provs staging table
f.ReportingPeriodStart
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Base
FROM NHSE_Sandbox_MentalHealth.dbo.Staging_MHA_Expected_Submitting_Provs s, NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_FullDates f

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQPadded') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQPadded

SELECT 
b.ProvName,
b.ReportingPeriodStart,
ISNULL(e.ProvSubmittingMHAData, 0) AS ProvSubmittingMHAData,
ISNULL(e.ProvNOTSubmittingMHAData, 0) AS ProvNOTSubmittingMHAData,
e.Attendances,
e.Attendances_w_MHA,
e.MHA_records, 
e.MHA_records_val,
ISNULL(e.Dataset, 'MHSDS') AS Dataset
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQPadded
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Base b
LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQ e ON b.ProvName = e.ProvName AND b.ReportingPeriodStart = e.ReportingPeriodStart

------------  Add into Dashboard_MHA_DQ tableS

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA_DQ

SELECT * 
INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_MHA_DQ
FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ECDSDQ

UNION 
SELECT * FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQPadded

------------ Drop all temporary tables in the Sandbox

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cases
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesCat
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Dates
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Cumf
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Groups
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_GroupsRepeat
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ExplodedSeries
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_BeforeAfter
-- DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfo -- keep
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_All
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Population
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGCodes
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CCGPop
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_STPPop
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RegionPop
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_EnglandPop
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpec
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpec
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllSpecComm
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AllWSpecComm
-- DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMaster -- keep
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesMetric
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Admissions
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsCat
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_CasesWSeriesInfoOneRow
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMaster
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMetrics
-- DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMaster -- keep
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMetric
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeople
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_LDAPeopleflag
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleMasterLDA
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemo
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_RollingForDemoWDate
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_DemoMaster
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_PeopleDemoMetric
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_ECDSDQ
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQ
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_FullDates
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_Base
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_MHSDSDQPadded

----- Investigate DQ

--SELECT TOP 1000 * FROM NHSE_Sandbox_MentalHealth.dbo.temp_MHA_CasesWSeriesInfo c
--WHERE c.RenewalFlag = 1 OR c.Next_SectionType = c.SectionType
--ORDER BY c.Der_Person_ID, c.UniqMonthID, c.UniqMHActEpisodeID

--SELECT a.TimeBetween FROM NHSE_Sandbox_MentalHealth.dbo.Temp_MHA_AdmissionsMaster a
--WHERE a.AdmissionsWithDetention24HoursAfterFlag = 1 AND a.UniqMonthID = 1463
