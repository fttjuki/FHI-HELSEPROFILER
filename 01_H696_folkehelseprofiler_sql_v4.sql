
-- H-696 Folkehelseprofiler
-- Ailin Falkmo Hansen
-- 14.05.25 (fjerner F og G-kodene sammenliknet med tidligere utkast)

-- 1) henter ut aktivitetsdata
-- 2) henter ut bostedsopplysninger
-- 3) tilrettelegger tabeller i R

USE NPRNasjonaltDatagrunnlag; 

-- 1) uttrekk
----------------------------------------------------------------------------

DROP TABLE IF EXISTS tmp.H696_folkehelseprofiler_uttrekk;

SELECT * INTO tmp.H696_folkehelseprofiler_uttrekk
FROM
(
SELECT 
NPRId, nokkel, alder, kjonn, komnrhjem2, aar, inndato, utdato, 
--kodeverdi, pros, 
	MAX("I00_I99") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "I00_I99",
	MAX("I20_I25") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "I20_I25",
	MAX("J440_J449") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "J440_J449",
	MAX("M00_M99") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "M00_M99",
	MAX("S00_T78") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "S00_T78",
	MAX("S720_S722") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "S720_S722",
	MAX("S720_S722_pros") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "S720_S722_pros",
	MAX("T36_T65") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "T36_T65",
	MAX("S00_S09") OVER (PARTITION BY nokkel ORDER BY nokkel) AS "S00_S09",
	ROW_NUMBER() OVER (PARTITION BY nokkel ORDER BY nokkel) AS episoderad 
FROM
(
SELECT a.NPRId
, a.aar
, CONCAT('SOM', a.som_k) AS nokkel
, alder = a.aar-d.fodtAar
, a.komnrhjem2
, kjonn = CASE WHEN d.kjonn = '1' THEN 'Menn'
				WHEN d.kjonn = '2' THEN 'Kvinner'
				WHEN d.kjonn = '0' THEN 'ikke kjent'
				WHEN d.kjonn = '9' THEN 'ikke spesifisert' END
, a.inndato
, a.utdato ,
--, b.kodeverdi AS kodeverdi
--, c.kodeverdi AS pros,
		"I00_I99" = CASE WHEN LEFT(b.KodeVerdi,3) BETWEEN 'I00' AND 'I99' THEN 1 ELSE 0 END,
		"I20_I25" = CASE WHEN LEFT(b.KodeVerdi,3) BETWEEN 'I20' AND 'I25' THEN 1 ELSE 0 END,
		"J440_J449" = CASE WHEN LEFT(b.KodeVerdi,3) = 'J44' THEN 1 ELSE 0 END, 
		"M00_M99" = CASE WHEN LEFT(b.KodeVerdi,3) BETWEEN 'M00' AND 'M99' THEN 1 ELSE 0 END, 
		"S00_T78" = CASE WHEN LEFT(b.KodeVerdi,3) BETWEEN 'S00' AND 'T78' THEN 1 ELSE 0 END,
		"S720_S722" = CASE WHEN LEFT(b.KodeVerdi,4) BETWEEN ('S720') AND ('S722') THEN 1 ELSE 0 END,
		"S720_S722_pros" = CASE WHEN LEFT(b.KodeVerdi,4) BETWEEN ('S720') AND ('S722') AND LEFT(c.KodeVerdi,3) IN ('NFJ','NFB') AND SUBSTRING(c.KodeVerdi,5,1) BETWEEN '0' AND '2' THEN 1 ELSE 0 END,
		"T36_T65"=	CASE WHEN LEFT(b.KodeVerdi,3) BETWEEN ('T36') AND ('T65') THEN 1 ELSE 0 END,
		"S00_S09"=	CASE WHEN LEFT(b.KodeVerdi,3) BETWEEN ('S00') AND ('S09') THEN 1 ELSE 0 END
FROM SOMHoved AS a
INNER JOIN SOMKoder AS e ON a.som_k = e.som_k 
LEFT JOIN (SELECT som_k, kodeverdi FROM SOMKoder WHERE kodetype=6 AND kodenr IN (11,12) AND aar BETWEEN 2010 AND 2024) AS b ON a.som_k = b.som_k 
LEFT JOIN (SELECT som_k, kodeverdi FROM SOMKoder WHERE kodetype IN (2,3,8) AND aar BETWEEN 2010 AND 2024) AS c ON a.som_k = c.som_k 
LEFT JOIN NPRPerson.NPR.FodtAarMndOgKjonn AS d on a.NPRid = CAST(d.NPRId as varchar)
WHERE LEN(a.NPRId) < 12
AND a.AAR BETWEEN 2010 AND 2024
AND (KodeType = 6 AND KodeNr IN (11,12)  -- kun hovedtilstander
AND 
(
LEFT(b.KodeVerdi,3) BETWEEN 'I00' AND 'I99'
OR LEFT(b.KodeVerdi,3) = 'J44'
OR LEFT(b.KodeVerdi,3) BETWEEN 'M00' AND 'M99'
OR LEFT(b.KodeVerdi,3) BETWEEN 'S00' AND 'T78'
OR LEFT(b.KodeVerdi,4) BETWEEN ('S720') AND ('S722')
OR LEFT(b.KodeVerdi,3) BETWEEN ('T36') AND ('T65')
)
)
AND (erRehabilitering IS NULL OR erRehabilitering = 0)
AND niva <> 'S'		-- avdelingsopphold (men teller bare personer)
AND omsorgsniva IN (1,2)
) AS Merking
) AS aggregering
WHERE episoderad=1  
-- 5593977


SELECT aar, COUNT(DISTINCT(NPRID)) FROM tmp.H696_folkehelseprofiler_uttrekk group by aar order by aar
-- (alle år)

SELECT COUNT(DISTINCT(a.NPRID)) FROM SOMHoved AS A
INNER JOIN SOMKoder AS b ON a.som_k = b.som_k 
LEFT JOIN NPRPerson.NPR.FodtAarMndOgKjonn AS d on a.NPRid = CAST(d.NPRId as varchar)
WHERE LEN(a.NPRId) < 12
AND a.AAR = 2024
AND (KodeType = 6 AND kodenr IN (11,12) AND LEFT(b.KodeVerdi,3) BETWEEN 'I00' AND 'I99' )
AND (erRehabilitering IS NULL OR erRehabilitering = 0)
AND niva <> 'S'		-- avdelingsopphold
AND omsorgsniva IN (1,2)
AND d.kjonn in (1,2)
-- 87897 (stemmer med uttrekket over)


-- 2) bostedsopplysninger (per 1.1 alternativt 31.12)
----------------------------------------------------------------------------
-- finner NPRidene fra utvalget over som trenger bostedsopplysninger

DROP TABLE IF EXISTS #utvalg;

SELECT DISTINCT NPRID 
INTO #utvalg
FROM tmp.H696_folkehelseprofiler_uttrekk 

-- finner bostedsopplysninger for alle personene i utvalget
DROP TABLE IF EXISTS tmp.H696_bosted;

SELECT distinct NPRid, 
MAX(komnr2010) OVER (PARTITION BY NPRId) AS komnr2010,
MAX(komnr2011) OVER (PARTITION BY NPRId) AS komnr2011,
MAX(komnr2012) OVER (PARTITION BY NPRId) AS komnr2012,
MAX(komnr2013) OVER (PARTITION BY NPRId) AS komnr2013,
MAX(komnr2014) OVER (PARTITION BY NPRId) AS komnr2014,
MAX(komnr2015) OVER (PARTITION BY NPRId) AS komnr2015,
MAX(komnr2016) OVER (PARTITION BY NPRId) AS komnr2016,
MAX(komnr2017) OVER (PARTITION BY NPRId) AS komnr2017,
MAX(komnr2018) OVER (PARTITION BY NPRId) AS komnr2018,
MAX(komnr2019) OVER (PARTITION BY NPRId) AS komnr2019,
MAX(komnr2020) OVER (PARTITION BY NPRId) AS komnr2020,
MAX(komnr2021) OVER (PARTITION BY NPRId) AS komnr2021,
MAX(komnr2022) OVER (PARTITION BY NPRId) AS komnr2022,
MAX(komnr2023) OVER (PARTITION BY NPRId) AS komnr2023,
MAX(komnr2024) OVER (PARTITION BY NPRId) AS komnr2024,
MAX(komnr2025) OVER (PARTITION BY NPRId) AS komnr2025
INTO tmp.H696_bosted
FROM (
SELECT som.NPRID,
komnr2010 = CASE WHEN bo.fradato <= '2010-01-01' AND (bo.tildato >= '2010-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2011 = CASE WHEN bo.fradato <= '2011-01-01' AND (bo.tildato >= '2011-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2012 = CASE WHEN bo.fradato <= '2012-01-01' AND (bo.tildato >= '2012-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2013 = CASE WHEN bo.fradato <= '2013-01-01' AND (bo.tildato >= '2013-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2014 = CASE WHEN bo.fradato <= '2014-01-01' AND (bo.tildato >= '2014-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2015 = CASE WHEN bo.fradato <= '2015-01-01' AND (bo.tildato >= '2015-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2016 = CASE WHEN bo.fradato <= '2016-01-01' AND (bo.tildato >= '2016-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2017 = CASE WHEN bo.fradato <= '2017-01-01' AND (bo.tildato >= '2017-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2018 = CASE WHEN bo.fradato <= '2018-01-01' AND (bo.tildato >= '2018-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2019 = CASE WHEN bo.fradato <= '2019-01-01' AND (bo.tildato >= '2019-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2020 = CASE WHEN bo.fradato <= '2020-01-01' AND (bo.tildato >= '2020-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2021 = CASE WHEN bo.fradato <= '2021-01-01' AND (bo.tildato >= '2021-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2022 = CASE WHEN bo.fradato <= '2022-01-01' AND (bo.tildato >= '2022-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2023 = CASE WHEN bo.fradato <= '2023-01-01' AND (bo.tildato >= '2023-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2024 = CASE WHEN bo.fradato <= '2024-01-01' AND (bo.tildato >= '2024-01-01' OR bo.tildato IS NULL) THEN bo.kommune END,
komnr2025 = CASE WHEN bo.fradato <= '2025-01-01' AND (bo.tildato >= '2025-01-01' OR bo.tildato IS NULL) THEN bo.kommune END
FROM 
(
SELECT NPRid
FROM #utvalg
) AS som
LEFT JOIN NPRPerson.NPR.PersonBosted AS bo ON som.NPRId=CAST(bo.NPRId AS varchar(128))
) AS maxed

SELECT TOP 1000 * FROM tmp.H696_bosted













