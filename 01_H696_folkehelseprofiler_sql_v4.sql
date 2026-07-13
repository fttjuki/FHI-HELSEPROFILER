-- ============================================================
-- H-696 Folkehelseprofiler og tilhorende statistikkbank
-- Leveranse til Helsedirektoratet (Hdir) 2026
--  Dato: 13.juli.2026 | Versjon 8 | Laget av: Tingting Feng
--
-- ============================================================
-- BEKREFTET tabellstruktur (alle i NPRNasjonaltDatagrunnlag):
--
--   Tjeneste | Koder      | Hoved      | nokkel | Hovedtilstand-filter
--   ---------|------------|------------|--------|---------------------------
--   SOM      | SOMKoder   | SOMHoved   | som_k  | KodeType=6 AND KodeNr IN (11,12)
--   PHV      | PHVKoder   | PHVHoved   | phv_k  | KodeType=6 AND KodeNr IN (11,12)
--   TSB      | TSBKoder   | TSBHoved   | phv_k  | KodeType=6 AND KodeNr IN (11,12)
--   AVT      | AVTKoder   | AVTHoved   | asp_k  | KodeType=6 AND KodeNr IN (11,12)
--   PHBU     | PHBUKoder  | PHBUHoved  | bup_k  | Akse=1 AND Tilstand=1
--
--   Kjonn/fodselsar: NPRPerson.NPR.FodtAarMndOgKjonn
--   Bosted: NPRPerson.NPR.PersonBosted
-- ============================================================
--
-- DIAGNOSEGRUPPER per variabelliste NPR (H-696-E2):
--   SOM: I00-I99, I21-I22, J44, M00-M99, S00-T78,
--        S720-S729, S720-S722 (uten pros), T36-T65, S00-S09
--   PSYK (PHV/TSB/PHBU/AVT): F00-F99, F30-F39, F40-F48,
--        F10-F16+F18-F19, F10, F11-F16+F18-F19
--
-- ENDRINGER FRA leveranse 2025:
--   1. S720_S722_pros (med NFB/NFJ-prosedyrekoder) FJERNET
--   2. I20_I25 ERSTATTET av I21_I22
--   3. Utvidet til PHV, TSB, PHBU, AVT
--   4. Alle argangar 2012-2025 pa nytt
--   5. Omsorgsniva IN (1,2) brukes for SOM, PHV, TSB, PHBU og AVT
--
-- FELLES UTVALGSREGEL:
--   Kun dag- og dognbehandling: omsorgsniva IN (1,2)
--   Regelen brukes i alle fem tjenesteomrader, ogsa AVT.
--   AVT kan derfor fa fa eller ingen rader dersom aktiviteten er poliklinisk.
-- ============================================================

USE NPRNasjonaltDatagrunnlag;

SET NOCOUNT ON;
SET XACT_ABORT ON;


DROP TABLE IF EXISTS tmp.H696_AVT_omsorgsniva_kontroll;
DROP TABLE IF EXISTS tmp.H696_SOM_uttrekk;
DROP TABLE IF EXISTS tmp.H696_PHV_uttrekk;
DROP TABLE IF EXISTS tmp.H696_TSB_uttrekk;
DROP TABLE IF EXISTS tmp.H696_PHBU_uttrekk;
DROP TABLE IF EXISTS tmp.H696_AVT_uttrekk;
DROP TABLE IF EXISTS tmp.H696_bosted_v8;

GO

USE NPRNasjonaltDatagrunnlag;
SET NOCOUNT ON;
SET XACT_ABORT ON;


-- ============================================================
-- DEL 0: FORHÅNDSKONTROLL AV OMSORGSNIVÅ
--
-- Kontrollen kjøres før uttrekkene og viser om AVTPHV faktisk har
-- relevante hoveddiagnoser på omsorgsnivå 1 eller 2. Resultatet lagres
-- også i tmp.H696_AVT_omsorgsniva_kontroll og leses inn av R-scriptet.
-- ============================================================

IF EXISTS (
    SELECT krav.tabellnavn
    FROM (VALUES
        ('SOMHoved'),
        ('PHVHoved'),
        ('TSBHoved'),
        ('PHBUHoved'),
        ('AVTHoved')
    ) AS krav(tabellnavn)
    WHERE NOT EXISTS (
        SELECT 1
        FROM sys.objects AS t
        INNER JOIN sys.columns AS c
            ON c.object_id = t.object_id
        WHERE t.type IN ('U', 'V')
          AND t.name = krav.tabellnavn
          AND c.name = 'omsorgsniva'
    )
)
BEGIN
    THROW 50001, 'Minst 1 hovedtabell mangler kolonnen omsorgsniva. Kontroller tabellstrukturen før uttrekket kjøres.', 1;
END;

DROP TABLE IF EXISTS tmp.H696_AVT_omsorgsniva_kontroll;

SELECT
    b.omsorgsniva,
    CASE
        WHEN b.omsorgsniva IN (1, 2) THEN 'Med i uttrekk'
        ELSE 'Ikke med i uttrekk'
    END AS filterstatus,
    COUNT(*) AS n_koderader,
    COUNT(DISTINCT b.asp_k) AS n_opphold,
    COUNT(DISTINCT b.NPRId) AS n_pasienter
INTO tmp.H696_AVT_omsorgsniva_kontroll
FROM AVTKoder AS a
INNER JOIN AVTHoved AS b
    ON b.asp_k = a.asp_k
   AND b.aar = a.aar
WHERE LEN(b.NPRId) < 12
  AND a.aar BETWEEN 2012 AND 2025
  AND a.KodeType = 6
  AND a.KodeNr IN (11, 12)
  AND LEFT(a.KodeVerdi, 3) BETWEEN 'F00' AND 'F99'
GROUP BY
    b.omsorgsniva,
    CASE
        WHEN b.omsorgsniva IN (1, 2) THEN 'Med i uttrekk'
        ELSE 'Ikke med i uttrekk'
    END;

SELECT
    omsorgsniva,
    filterstatus,
    n_koderader,
    n_opphold,
    n_pasienter
FROM tmp.H696_AVT_omsorgsniva_kontroll
ORDER BY
    CASE WHEN omsorgsniva IS NULL THEN 1 ELSE 0 END,
    omsorgsniva;

SELECT
    COUNT(DISTINCT b.asp_k) AS avt_opphold_med_i_uttrekk,
    COUNT(DISTINCT b.NPRId) AS avt_pasienter_med_i_uttrekk
FROM AVTKoder AS a
INNER JOIN AVTHoved AS b
    ON b.asp_k = a.asp_k
   AND b.aar = a.aar
WHERE LEN(b.NPRId) < 12
  AND a.aar BETWEEN 2012 AND 2025
  AND a.KodeType = 6
  AND a.KodeNr IN (11, 12)
  AND LEFT(a.KodeVerdi, 3) BETWEEN 'F00' AND 'F99'
  AND b.omsorgsniva IN (1, 2);


-- ============================================================
-- DEL 1A: SOM - Somatikk
-- ============================================================

DROP TABLE IF EXISTS tmp.H696_SOM_uttrekk;

SELECT * INTO tmp.H696_SOM_uttrekk
FROM (
    SELECT
        NPRId, nokkel, alder, kjonn, komNrHjem, aar, tjeneste, omsorgsniva,
        MAX(I00_I99)   OVER (PARTITION BY nokkel) AS I00_I99,
        MAX(I21_I22)   OVER (PARTITION BY nokkel) AS I21_I22,
        MAX(J44)       OVER (PARTITION BY nokkel) AS J44,
        MAX(M00_M99)   OVER (PARTITION BY nokkel) AS M00_M99,
        MAX(S00_T78)   OVER (PARTITION BY nokkel) AS S00_T78,
        MAX(S720_S729) OVER (PARTITION BY nokkel) AS S720_S729,
        MAX(S720_S722) OVER (PARTITION BY nokkel) AS S720_S722,
        MAX(T36_T65)   OVER (PARTITION BY nokkel) AS T36_T65,
        MAX(S00_S09)   OVER (PARTITION BY nokkel) AS S00_S09,
        ROW_NUMBER()   OVER (PARTITION BY nokkel ORDER BY nokkel) AS episoderad
    FROM (
        SELECT
            b.NPRId,
            a.aar,
            CONCAT('SOM', a.som_k) AS nokkel,
            a.aar - d.fodtAar      AS alder,
            b.komnrhjem2           AS komNrHjem,
            b.omsorgsniva           AS omsorgsniva,
            CASE
                WHEN COALESCE(d.kjonn, b.kjonn) = '1' THEN 'Menn'
                WHEN COALESCE(d.kjonn, b.kjonn) = '2' THEN 'Kvinner'
                ELSE 'Uoppgitt'
            END                    AS kjonn,
            'SOM'                  AS tjeneste,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'I00' AND 'I99' THEN 1 ELSE 0 END AS I00_I99,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'I21' AND 'I22' THEN 1 ELSE 0 END AS I21_I22,
            CASE WHEN LEFT(a.KodeVerdi,3) = 'J44'                  THEN 1 ELSE 0 END AS J44,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'M00' AND 'M99' THEN 1 ELSE 0 END AS M00_M99,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'S00' AND 'T78' THEN 1 ELSE 0 END AS S00_T78,
            CASE WHEN LEFT(a.KodeVerdi,4) BETWEEN 'S720' AND 'S729' THEN 1 ELSE 0 END AS S720_S729,
            CASE WHEN LEFT(a.KodeVerdi,4) BETWEEN 'S720' AND 'S722' THEN 1 ELSE 0 END AS S720_S722,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'T36' AND 'T65' THEN 1 ELSE 0 END AS T36_T65,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'S00' AND 'S09' THEN 1 ELSE 0 END AS S00_S09
        FROM SOMKoder AS a
        INNER JOIN SOMHoved AS b
            ON b.som_k = a.som_k
           AND b.aar = a.aar
        LEFT JOIN NPRPerson.NPR.FodtAarMndOgKjonn AS d
            ON CAST(d.NPRId AS varchar) = b.NPRId
        WHERE LEN(b.NPRId) < 12
          AND a.aar BETWEEN 2012 AND 2025
          AND b.aar BETWEEN 2012 AND 2025
          AND a.KodeType = 6
          AND a.KodeNr IN (11,12)
          AND (
              LEFT(a.KodeVerdi,3) BETWEEN 'I00' AND 'I99'
              OR LEFT(a.KodeVerdi,3) = 'J44'
              OR LEFT(a.KodeVerdi,3) BETWEEN 'M00' AND 'M99'
              OR LEFT(a.KodeVerdi,3) BETWEEN 'S00' AND 'T78'
              OR LEFT(a.KodeVerdi,4) BETWEEN 'S720' AND 'S729'
              OR LEFT(a.KodeVerdi,3) BETWEEN 'T36' AND 'T65'
          )
          AND (b.erRehabilitering IS NULL OR b.erRehabilitering = 0)
          AND b.niva <> 'S'
          AND b.omsorgsniva IN (1,2)
    ) AS Merking
) AS aggregering
WHERE episoderad = 1;

SELECT 'SOM' AS tjeneste, aar, COUNT(DISTINCT NPRId) AS n_pasienter
FROM tmp.H696_SOM_uttrekk GROUP BY aar ORDER BY aar;


-- ============================================================
-- DEL 1B: PHV - Psykisk helsevern voksne
-- Kun dag- og dognbehandling: omsorgsniva IN (1,2)
-- ============================================================

DROP TABLE IF EXISTS tmp.H696_PHV_uttrekk;

SELECT * INTO tmp.H696_PHV_uttrekk
FROM (
    SELECT
        NPRId, nokkel, alder, kjonn, komNrHjem, aar, tjeneste, omsorgsniva,
        MAX(F00_F99)         OVER (PARTITION BY nokkel) AS F00_F99,
        MAX(F30_F39)         OVER (PARTITION BY nokkel) AS F30_F39,
        MAX(F40_F48)         OVER (PARTITION BY nokkel) AS F40_F48,
        MAX(F10_F16_F18_F19) OVER (PARTITION BY nokkel) AS F10_F16_F18_F19,
        MAX(F10)             OVER (PARTITION BY nokkel) AS F10,
        MAX(F11_F16_F18_F19) OVER (PARTITION BY nokkel) AS F11_F16_F18_F19,
        ROW_NUMBER()         OVER (PARTITION BY nokkel ORDER BY nokkel) AS episoderad
    FROM (
        SELECT
            b.NPRId,
            a.aar,
            CONCAT('PHV', a.phv_k) AS nokkel,
            a.aar - d.fodtAar      AS alder,
            b.komnrhjem2           AS komNrHjem,
            b.omsorgsniva           AS omsorgsniva,
            CASE
                WHEN COALESCE(d.kjonn, b.kjonn) = '1' THEN 'Menn'
                WHEN COALESCE(d.kjonn, b.kjonn) = '2' THEN 'Kvinner'
                ELSE 'Uoppgitt'
            END                    AS kjonn,
            'PHV'                  AS tjeneste,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F00' AND 'F99' THEN 1 ELSE 0 END AS F00_F99,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F30' AND 'F39' THEN 1 ELSE 0 END AS F30_F39,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F40' AND 'F48' THEN 1 ELSE 0 END AS F40_F48,
            CASE WHEN (LEFT(a.KodeVerdi,3) BETWEEN 'F10' AND 'F16'
                       OR LEFT(a.KodeVerdi,3) IN ('F18','F19')) THEN 1 ELSE 0 END AS F10_F16_F18_F19,
            CASE WHEN LEFT(a.KodeVerdi,3) = 'F10'                  THEN 1 ELSE 0 END AS F10,
            CASE WHEN (LEFT(a.KodeVerdi,3) BETWEEN 'F11' AND 'F16'
                       OR LEFT(a.KodeVerdi,3) IN ('F18','F19')) THEN 1 ELSE 0 END AS F11_F16_F18_F19
        FROM PHVKoder AS a
        INNER JOIN PHVHoved AS b
            ON b.phv_k = a.phv_k
           AND b.aar = a.aar
        LEFT JOIN NPRPerson.NPR.FodtAarMndOgKjonn AS d
            ON CAST(d.NPRId AS varchar) = b.NPRId
        WHERE LEN(b.NPRId) < 12
          AND a.aar BETWEEN 2012 AND 2025
          AND b.aar BETWEEN 2012 AND 2025
          AND a.KodeType = 6
          AND a.KodeNr IN (11,12)
          AND LEFT(a.KodeVerdi,3) BETWEEN 'F00' AND 'F99'
          AND b.omsorgsniva IN (1,2)
    ) AS Merking
) AS aggregering
WHERE episoderad = 1;

SELECT 'PHV' AS tjeneste, aar, COUNT(DISTINCT NPRId) AS n_pasienter
FROM tmp.H696_PHV_uttrekk GROUP BY aar ORDER BY aar;


-- ============================================================
-- DEL 1C: TSB - Tverrfaglig spesialisert rusbehandling
-- Kun dag- og dognbehandling: omsorgsniva IN (1,2)
-- ============================================================

DROP TABLE IF EXISTS tmp.H696_TSB_uttrekk;

SELECT * INTO tmp.H696_TSB_uttrekk
FROM (
    SELECT
        NPRId, nokkel, alder, kjonn, komNrHjem, aar, tjeneste, omsorgsniva,
        MAX(F00_F99)         OVER (PARTITION BY nokkel) AS F00_F99,
        MAX(F30_F39)         OVER (PARTITION BY nokkel) AS F30_F39,
        MAX(F40_F48)         OVER (PARTITION BY nokkel) AS F40_F48,
        MAX(F10_F16_F18_F19) OVER (PARTITION BY nokkel) AS F10_F16_F18_F19,
        MAX(F10)             OVER (PARTITION BY nokkel) AS F10,
        MAX(F11_F16_F18_F19) OVER (PARTITION BY nokkel) AS F11_F16_F18_F19,
        ROW_NUMBER()         OVER (PARTITION BY nokkel ORDER BY nokkel) AS episoderad
    FROM (
        SELECT
            b.NPRId,
            a.aar,
            CONCAT('TSB', a.phv_k) AS nokkel,
            a.aar - d.fodtAar      AS alder,
            b.komnrhjem2           AS komNrHjem,
            b.omsorgsniva           AS omsorgsniva,
            CASE
                WHEN COALESCE(d.kjonn, b.kjonn) = '1' THEN 'Menn'
                WHEN COALESCE(d.kjonn, b.kjonn) = '2' THEN 'Kvinner'
                ELSE 'Uoppgitt'
            END                    AS kjonn,
            'TSB'                  AS tjeneste,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F00' AND 'F99' THEN 1 ELSE 0 END AS F00_F99,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F30' AND 'F39' THEN 1 ELSE 0 END AS F30_F39,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F40' AND 'F48' THEN 1 ELSE 0 END AS F40_F48,
            CASE WHEN (LEFT(a.KodeVerdi,3) BETWEEN 'F10' AND 'F16'
                       OR LEFT(a.KodeVerdi,3) IN ('F18','F19')) THEN 1 ELSE 0 END AS F10_F16_F18_F19,
            CASE WHEN LEFT(a.KodeVerdi,3) = 'F10'                  THEN 1 ELSE 0 END AS F10,
            CASE WHEN (LEFT(a.KodeVerdi,3) BETWEEN 'F11' AND 'F16'
                       OR LEFT(a.KodeVerdi,3) IN ('F18','F19')) THEN 1 ELSE 0 END AS F11_F16_F18_F19
        FROM TSBKoder AS a
        INNER JOIN TSBHoved AS b
            ON b.phv_k = a.phv_k
           AND b.aar = a.aar
        LEFT JOIN NPRPerson.NPR.FodtAarMndOgKjonn AS d
            ON CAST(d.NPRId AS varchar) = b.NPRId
        WHERE LEN(b.NPRId) < 12
          AND a.aar BETWEEN 2012 AND 2025
          AND b.aar BETWEEN 2012 AND 2025
          AND a.KodeType = 6
          AND a.KodeNr IN (11,12)
          AND LEFT(a.KodeVerdi,3) BETWEEN 'F00' AND 'F99'
          AND b.omsorgsniva IN (1,2)
    ) AS Merking
) AS aggregering
WHERE episoderad = 1;

SELECT 'TSB' AS tjeneste, aar, COUNT(DISTINCT NPRId) AS n_pasienter
FROM tmp.H696_TSB_uttrekk GROUP BY aar ORDER BY aar;


-- ============================================================
-- DEL 1D: PHBU - Psykisk helsevern barn og unge
-- Kun dag- og dognbehandling: omsorgsniva IN (1,2)
-- Hovedtilstand: Akse = 1 (klinisk psyk. syndrom, F00-F99)
--                Tilstand = 1 (hovedtilstand)
-- ============================================================

DROP TABLE IF EXISTS tmp.H696_PHBU_uttrekk;

SELECT * INTO tmp.H696_PHBU_uttrekk
FROM (
    SELECT
        NPRId, nokkel, alder, kjonn, komNrHjem, aar, tjeneste, omsorgsniva,
        MAX(F00_F99)         OVER (PARTITION BY nokkel) AS F00_F99,
        MAX(F30_F39)         OVER (PARTITION BY nokkel) AS F30_F39,
        MAX(F40_F48)         OVER (PARTITION BY nokkel) AS F40_F48,
        MAX(F10_F16_F18_F19) OVER (PARTITION BY nokkel) AS F10_F16_F18_F19,
        MAX(F10)             OVER (PARTITION BY nokkel) AS F10,
        MAX(F11_F16_F18_F19) OVER (PARTITION BY nokkel) AS F11_F16_F18_F19,
        ROW_NUMBER()         OVER (PARTITION BY nokkel ORDER BY nokkel) AS episoderad
    FROM (
        SELECT
            b.NPRId,
            a.aar,
            CONCAT('PHBU', a.bup_k) AS nokkel,
            a.aar - d.fodtAar       AS alder,
            b.komnrhjem2            AS komNrHjem,
            b.omsorgsniva            AS omsorgsniva,
            CASE
                WHEN COALESCE(d.kjonn, b.kjonn) = '1' THEN 'Menn'
                WHEN COALESCE(d.kjonn, b.kjonn) = '2' THEN 'Kvinner'
                ELSE 'Uoppgitt'
            END                     AS kjonn,
            'PHBU'                  AS tjeneste,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F00' AND 'F99' THEN 1 ELSE 0 END AS F00_F99,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F30' AND 'F39' THEN 1 ELSE 0 END AS F30_F39,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F40' AND 'F48' THEN 1 ELSE 0 END AS F40_F48,
            CASE WHEN (LEFT(a.KodeVerdi,3) BETWEEN 'F10' AND 'F16'
                       OR LEFT(a.KodeVerdi,3) IN ('F18','F19')) THEN 1 ELSE 0 END AS F10_F16_F18_F19,
            CASE WHEN LEFT(a.KodeVerdi,3) = 'F10'                  THEN 1 ELSE 0 END AS F10,
            CASE WHEN (LEFT(a.KodeVerdi,3) BETWEEN 'F11' AND 'F16'
                       OR LEFT(a.KodeVerdi,3) IN ('F18','F19')) THEN 1 ELSE 0 END AS F11_F16_F18_F19
        FROM PHBUKoder AS a
        INNER JOIN PHBUHoved AS b
            ON b.bup_k = a.bup_k
           AND b.aar = a.aar
        LEFT JOIN NPRPerson.NPR.FodtAarMndOgKjonn AS d
            ON CAST(d.NPRId AS varchar) = b.NPRId
        WHERE LEN(b.NPRId) < 12
          AND a.aar BETWEEN 2012 AND 2025
          AND b.aar BETWEEN 2012 AND 2025
          AND a.Akse = 1          -- Akse I: klinisk psykiatrisk syndrom (F00-F99)
          AND a.Tilstand = 1      -- hovedtilstand
          AND LEFT(a.KodeVerdi,3) BETWEEN 'F00' AND 'F99'
          AND b.omsorgsniva IN (1,2)
    ) AS Merking
) AS aggregering
WHERE episoderad = 1;

SELECT 'PHBU' AS tjeneste, aar, COUNT(DISTINCT NPRId) AS n_pasienter
FROM tmp.H696_PHBU_uttrekk GROUP BY aar ORDER BY aar;


-- ============================================================
-- DEL 1E: AVT - Avtalespesialister psykisk helsevern voksne
-- Kun dag- og dognbehandling: omsorgsniva IN (1,2)

-- ============================================================

DROP TABLE IF EXISTS tmp.H696_AVT_uttrekk;

SELECT * INTO tmp.H696_AVT_uttrekk
FROM (
    SELECT
        NPRId, nokkel, alder, kjonn, komNrHjem, aar, tjeneste, omsorgsniva,
        MAX(F00_F99)         OVER (PARTITION BY nokkel) AS F00_F99,
        MAX(F30_F39)         OVER (PARTITION BY nokkel) AS F30_F39,
        MAX(F40_F48)         OVER (PARTITION BY nokkel) AS F40_F48,
        MAX(F10_F16_F18_F19) OVER (PARTITION BY nokkel) AS F10_F16_F18_F19,
        MAX(F10)             OVER (PARTITION BY nokkel) AS F10,
        MAX(F11_F16_F18_F19) OVER (PARTITION BY nokkel) AS F11_F16_F18_F19,
        ROW_NUMBER()         OVER (PARTITION BY nokkel ORDER BY nokkel) AS episoderad
    FROM (
        SELECT
            b.NPRId,
            a.aar,
            CONCAT('AVT', a.asp_k) AS nokkel,
            a.aar - d.fodtAar      AS alder,
            b.komnrhjem2           AS komNrHjem,
            b.omsorgsniva           AS omsorgsniva,
            CASE
                WHEN COALESCE(d.kjonn, b.kjonn) = '1' THEN 'Menn'
                WHEN COALESCE(d.kjonn, b.kjonn) = '2' THEN 'Kvinner'
                ELSE 'Uoppgitt'
            END                    AS kjonn,
            'AVT'                  AS tjeneste,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F00' AND 'F99' THEN 1 ELSE 0 END AS F00_F99,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F30' AND 'F39' THEN 1 ELSE 0 END AS F30_F39,
            CASE WHEN LEFT(a.KodeVerdi,3) BETWEEN 'F40' AND 'F48' THEN 1 ELSE 0 END AS F40_F48,
            CASE WHEN (LEFT(a.KodeVerdi,3) BETWEEN 'F10' AND 'F16'
                       OR LEFT(a.KodeVerdi,3) IN ('F18','F19')) THEN 1 ELSE 0 END AS F10_F16_F18_F19,
            CASE WHEN LEFT(a.KodeVerdi,3) = 'F10'                  THEN 1 ELSE 0 END AS F10,
            CASE WHEN (LEFT(a.KodeVerdi,3) BETWEEN 'F11' AND 'F16'
                       OR LEFT(a.KodeVerdi,3) IN ('F18','F19')) THEN 1 ELSE 0 END AS F11_F16_F18_F19
        FROM AVTKoder AS a
        INNER JOIN AVTHoved AS b
            ON b.asp_k = a.asp_k
           AND b.aar = a.aar
        LEFT JOIN NPRPerson.NPR.FodtAarMndOgKjonn AS d
            ON CAST(d.NPRId AS varchar) = b.NPRId
        WHERE LEN(b.NPRId) < 12
          AND a.aar BETWEEN 2012 AND 2025
          AND b.aar BETWEEN 2012 AND 2025
          AND a.KodeType = 6
          AND a.KodeNr IN (11,12)
          AND LEFT(a.KodeVerdi,3) BETWEEN 'F00' AND 'F99'
          AND b.omsorgsniva IN (1,2)
    ) AS Merking
) AS aggregering
WHERE episoderad = 1;

SELECT 'AVT' AS tjeneste, aar, COUNT(DISTINCT NPRId) AS n_pasienter
FROM tmp.H696_AVT_uttrekk GROUP BY aar ORDER BY aar;


-- ============================================================
-- DEL 2: Bostedsopplysninger - alle tjenester samlet
-- Per variabelliste: 1.1, fallback 31.12, ellers ekskluder (i R).
-- ============================================================

DROP TABLE IF EXISTS #utvalg_alle;

SELECT DISTINCT NPRId INTO #utvalg_alle FROM tmp.H696_SOM_uttrekk
UNION SELECT DISTINCT NPRId FROM tmp.H696_PHV_uttrekk
UNION SELECT DISTINCT NPRId FROM tmp.H696_TSB_uttrekk
UNION SELECT DISTINCT NPRId FROM tmp.H696_PHBU_uttrekk
UNION SELECT DISTINCT NPRId FROM tmp.H696_AVT_uttrekk;

DROP TABLE IF EXISTS tmp.H696_bosted_v8;

SELECT DISTINCT NPRid,
    MAX(kom_1_1_2012)  OVER (PARTITION BY NPRId) AS kom_1_1_2012,
    MAX(kom_1_1_2013)  OVER (PARTITION BY NPRId) AS kom_1_1_2013,
    MAX(kom_1_1_2014)  OVER (PARTITION BY NPRId) AS kom_1_1_2014,
    MAX(kom_1_1_2015)  OVER (PARTITION BY NPRId) AS kom_1_1_2015,
    MAX(kom_1_1_2016)  OVER (PARTITION BY NPRId) AS kom_1_1_2016,
    MAX(kom_1_1_2017)  OVER (PARTITION BY NPRId) AS kom_1_1_2017,
    MAX(kom_1_1_2018)  OVER (PARTITION BY NPRId) AS kom_1_1_2018,
    MAX(kom_1_1_2019)  OVER (PARTITION BY NPRId) AS kom_1_1_2019,
    MAX(kom_1_1_2020)  OVER (PARTITION BY NPRId) AS kom_1_1_2020,
    MAX(kom_1_1_2021)  OVER (PARTITION BY NPRId) AS kom_1_1_2021,
    MAX(kom_1_1_2022)  OVER (PARTITION BY NPRId) AS kom_1_1_2022,
    MAX(kom_1_1_2023)  OVER (PARTITION BY NPRId) AS kom_1_1_2023,
    MAX(kom_1_1_2024)  OVER (PARTITION BY NPRId) AS kom_1_1_2024,
    MAX(kom_1_1_2025)  OVER (PARTITION BY NPRId) AS kom_1_1_2025,
    MAX(kom_31_12_2012) OVER (PARTITION BY NPRId) AS kom_31_12_2012,
    MAX(kom_31_12_2013) OVER (PARTITION BY NPRId) AS kom_31_12_2013,
    MAX(kom_31_12_2014) OVER (PARTITION BY NPRId) AS kom_31_12_2014,
    MAX(kom_31_12_2015) OVER (PARTITION BY NPRId) AS kom_31_12_2015,
    MAX(kom_31_12_2016) OVER (PARTITION BY NPRId) AS kom_31_12_2016,
    MAX(kom_31_12_2017) OVER (PARTITION BY NPRId) AS kom_31_12_2017,
    MAX(kom_31_12_2018) OVER (PARTITION BY NPRId) AS kom_31_12_2018,
    MAX(kom_31_12_2019) OVER (PARTITION BY NPRId) AS kom_31_12_2019,
    MAX(kom_31_12_2020) OVER (PARTITION BY NPRId) AS kom_31_12_2020,
    MAX(kom_31_12_2021) OVER (PARTITION BY NPRId) AS kom_31_12_2021,
    MAX(kom_31_12_2022) OVER (PARTITION BY NPRId) AS kom_31_12_2022,
    MAX(kom_31_12_2023) OVER (PARTITION BY NPRId) AS kom_31_12_2023,
    MAX(kom_31_12_2024) OVER (PARTITION BY NPRId) AS kom_31_12_2024,
    MAX(kom_31_12_2025) OVER (PARTITION BY NPRId) AS kom_31_12_2025
INTO tmp.H696_bosted_v8
FROM (
    SELECT
        s.NPRId,
        CASE WHEN bo.fradato <= '2012-01-01' AND (bo.tildato >= '2012-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2012,
        CASE WHEN bo.fradato <= '2013-01-01' AND (bo.tildato >= '2013-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2013,
        CASE WHEN bo.fradato <= '2014-01-01' AND (bo.tildato >= '2014-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2014,
        CASE WHEN bo.fradato <= '2015-01-01' AND (bo.tildato >= '2015-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2015,
        CASE WHEN bo.fradato <= '2016-01-01' AND (bo.tildato >= '2016-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2016,
        CASE WHEN bo.fradato <= '2017-01-01' AND (bo.tildato >= '2017-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2017,
        CASE WHEN bo.fradato <= '2018-01-01' AND (bo.tildato >= '2018-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2018,
        CASE WHEN bo.fradato <= '2019-01-01' AND (bo.tildato >= '2019-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2019,
        CASE WHEN bo.fradato <= '2020-01-01' AND (bo.tildato >= '2020-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2020,
        CASE WHEN bo.fradato <= '2021-01-01' AND (bo.tildato >= '2021-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2021,
        CASE WHEN bo.fradato <= '2022-01-01' AND (bo.tildato >= '2022-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2022,
        CASE WHEN bo.fradato <= '2023-01-01' AND (bo.tildato >= '2023-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2023,
        CASE WHEN bo.fradato <= '2024-01-01' AND (bo.tildato >= '2024-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2024,
        CASE WHEN bo.fradato <= '2025-01-01' AND (bo.tildato >= '2025-01-01' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_1_1_2025,
        CASE WHEN bo.fradato <= '2012-12-31' AND (bo.tildato >= '2012-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2012,
        CASE WHEN bo.fradato <= '2013-12-31' AND (bo.tildato >= '2013-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2013,
        CASE WHEN bo.fradato <= '2014-12-31' AND (bo.tildato >= '2014-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2014,
        CASE WHEN bo.fradato <= '2015-12-31' AND (bo.tildato >= '2015-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2015,
        CASE WHEN bo.fradato <= '2016-12-31' AND (bo.tildato >= '2016-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2016,
        CASE WHEN bo.fradato <= '2017-12-31' AND (bo.tildato >= '2017-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2017,
        CASE WHEN bo.fradato <= '2018-12-31' AND (bo.tildato >= '2018-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2018,
        CASE WHEN bo.fradato <= '2019-12-31' AND (bo.tildato >= '2019-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2019,
        CASE WHEN bo.fradato <= '2020-12-31' AND (bo.tildato >= '2020-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2020,
        CASE WHEN bo.fradato <= '2021-12-31' AND (bo.tildato >= '2021-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2021,
        CASE WHEN bo.fradato <= '2022-12-31' AND (bo.tildato >= '2022-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2022,
        CASE WHEN bo.fradato <= '2023-12-31' AND (bo.tildato >= '2023-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2023,
        CASE WHEN bo.fradato <= '2024-12-31' AND (bo.tildato >= '2024-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2024,
        CASE WHEN bo.fradato <= '2025-12-31' AND (bo.tildato >= '2025-12-31' OR bo.tildato IS NULL) THEN bo.kommune END AS kom_31_12_2025
    FROM (SELECT NPRId FROM #utvalg_alle) AS s
    LEFT JOIN NPRPerson.NPR.PersonBosted AS bo
        ON s.NPRId = CAST(bo.NPRId AS varchar(128))
) AS maxed;

SELECT COUNT(DISTINCT NPRid) AS n_unike_i_bosted FROM tmp.H696_bosted_v8;
SELECT TOP 5 * FROM tmp.H696_bosted_v8;


-- Ferdig med opprettelse av uttrekkstabeller og bostedstabell.
-- Ny batch sikrer at QA kompileres mot den NYE tabellstrukturen.
GO

USE NPRNasjonaltDatagrunnlag;
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ============================================================
-- DEL 3: QA-KONTROLLER
-- ============================================================

-- 3.0: Kontroller at alle fem uttrekkstabellene faktisk har omsorgsniva.
IF COL_LENGTH('tmp.H696_SOM_uttrekk',  'omsorgsniva') IS NULL
 OR COL_LENGTH('tmp.H696_PHV_uttrekk',  'omsorgsniva') IS NULL
 OR COL_LENGTH('tmp.H696_TSB_uttrekk',  'omsorgsniva') IS NULL
 OR COL_LENGTH('tmp.H696_PHBU_uttrekk', 'omsorgsniva') IS NULL
 OR COL_LENGTH('tmp.H696_AVT_uttrekk',  'omsorgsniva') IS NULL
BEGIN
    THROW 50002, 'Minst 1 uttrekkstabell mangler kolonnen omsorgsniva. Kjør hele SQL-script versjon 8 fra starten.', 1;
END;

-- 3a: Forhåndskontroll AVTPHV før omsorgsnivåfilter
SELECT *
FROM tmp.H696_AVT_omsorgsniva_kontroll
ORDER BY CASE WHEN omsorgsniva IS NULL THEN 1 ELSE 0 END, omsorgsniva;

-- 3b: Unike pasienter per tjeneste
SELECT 'SOM'  AS tjeneste, COUNT(DISTINCT NPRId) AS n FROM tmp.H696_SOM_uttrekk  UNION ALL
SELECT 'PHV',  COUNT(DISTINCT NPRId) FROM tmp.H696_PHV_uttrekk  UNION ALL
SELECT 'TSB',  COUNT(DISTINCT NPRId) FROM tmp.H696_TSB_uttrekk  UNION ALL
SELECT 'PHBU', COUNT(DISTINCT NPRId) FROM tmp.H696_PHBU_uttrekk UNION ALL
SELECT 'AVT',  COUNT(DISTINCT NPRId) FROM tmp.H696_AVT_uttrekk;

-- 3c: Arsspenn (skal vaere 2012-2025)
SELECT 'SOM'  AS tjeneste, MIN(aar) AS min_aar, MAX(aar) AS max_aar FROM tmp.H696_SOM_uttrekk  UNION ALL
SELECT 'PHV',  MIN(aar), MAX(aar) FROM tmp.H696_PHV_uttrekk  UNION ALL
SELECT 'TSB',  MIN(aar), MAX(aar) FROM tmp.H696_TSB_uttrekk  UNION ALL
SELECT 'PHBU', MIN(aar), MAX(aar) FROM tmp.H696_PHBU_uttrekk UNION ALL
SELECT 'AVT',  MIN(aar), MAX(aar) FROM tmp.H696_AVT_uttrekk;

-- 3d: Kjonnsfordeling
SELECT tjeneste, kjonn, COUNT(*) AS n FROM (
    SELECT 'SOM'  AS tjeneste, kjonn FROM tmp.H696_SOM_uttrekk  UNION ALL
    SELECT 'PHV',  kjonn FROM tmp.H696_PHV_uttrekk  UNION ALL
    SELECT 'TSB',  kjonn FROM tmp.H696_TSB_uttrekk  UNION ALL
    SELECT 'PHBU', kjonn FROM tmp.H696_PHBU_uttrekk UNION ALL
    SELECT 'AVT',  kjonn FROM tmp.H696_AVT_uttrekk
) x GROUP BY tjeneste, kjonn ORDER BY tjeneste, kjonn;


-- 3e: Fordeling pa omsorgsniva etter filter
-- Forventning: bare verdiene 1 og 2.
SELECT tjeneste, omsorgsniva, COUNT(*) AS n
FROM (
    SELECT 'SOM'  AS tjeneste, omsorgsniva FROM tmp.H696_SOM_uttrekk  UNION ALL
    SELECT 'PHV',  omsorgsniva FROM tmp.H696_PHV_uttrekk  UNION ALL
    SELECT 'TSB',  omsorgsniva FROM tmp.H696_TSB_uttrekk  UNION ALL
    SELECT 'PHBU', omsorgsniva FROM tmp.H696_PHBU_uttrekk UNION ALL
    SELECT 'AVT',  omsorgsniva FROM tmp.H696_AVT_uttrekk
) x
GROUP BY tjeneste, omsorgsniva
ORDER BY tjeneste, omsorgsniva;

-- 3f: Rader som bryter utvalgsregelen
-- Forventning: ingen rader i resultatet.
SELECT tjeneste, COUNT(*) AS n_ugyldig_omsorgsniva
FROM (
    SELECT 'SOM'  AS tjeneste, omsorgsniva FROM tmp.H696_SOM_uttrekk  UNION ALL
    SELECT 'PHV',  omsorgsniva FROM tmp.H696_PHV_uttrekk  UNION ALL
    SELECT 'TSB',  omsorgsniva FROM tmp.H696_TSB_uttrekk  UNION ALL
    SELECT 'PHBU', omsorgsniva FROM tmp.H696_PHBU_uttrekk UNION ALL
    SELECT 'AVT',  omsorgsniva FROM tmp.H696_AVT_uttrekk
) x
WHERE omsorgsniva NOT IN (1,2) OR omsorgsniva IS NULL
GROUP BY tjeneste
ORDER BY tjeneste;




