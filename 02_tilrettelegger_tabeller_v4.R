################################################################################
# H-696-E2 Folkehelseprofiler og statistikkbank 2026
# NPR-leveranse 2012-2025
# Versjon 8 - enkel R-kode uten egne funksjoner og uten løkker
# Laget av: TTF  13. juli 2026
################################################################################

################################################################################
# ENDRINGER FRA LEVERANSE 2025:
# - Diagnosegruppen I20-I25 er fjernet og erstattet av I21-I22.
# - S720-S722 med NFB/NFJ-prosedyrekoder er ikke lenger med som egen variabel.
# - PHV, TSB, PHBU og AVTPHV er tatt med i tillegg til SOM.
# - Omsorgsnivå 1 og 2 brukes for alle fem tjenesteområder.
# - Bosted bruker kommune per 1.1. Hvis denne mangler, brukes kommune per
#   31.12 samme år. Hvis begge mangler, ekskluderes personen det året.
#
################################################################################

library(DBI)
library(dplyr)
library(odbc)
library(openxlsx)
library(stringr)

rm(list = ls())

START_YEAR <- 2012
END_YEAR <- 2025
RUN_DATE <- format(Sys.Date(), "%Y-%m-%d")

################################################################################
# 1. Koble til databasene
################################################################################

con_npr <- dbConnect(
  odbc(),
  Driver = "ODBC Driver 17 for SQL Server",
  Server = "NPRSQLprod",
  Database = "NPRNasjonaltdatagrunnlag",
  Trusted_Connection = "Yes",
  Encrypt = "Yes",
  encoding = "UTF-8"
)

con_kpr <- dbConnect(
  odbc(),
  Driver = "ODBC Driver 17 for SQL Server",
  Server = "NPRDVHPROD",
  Database = "KPRUtlevering",
  Trusted_Connection = "Yes",
  Encrypt = "Yes",
  encoding = "UTF-8"
)

try(Sys.setlocale("LC_ALL", "nb-NO.UTF-8"), silent = TRUE)

################################################################################
# 2. Les tabellene som SQL-script  har laget
################################################################################

cat("Leser SQL-tabeller...\n")

som_raw  <- dbGetQuery(con_npr, "SELECT * FROM tmp.H696_SOM_uttrekk")
phv_raw  <- dbGetQuery(con_npr, "SELECT * FROM tmp.H696_PHV_uttrekk")
tsb_raw  <- dbGetQuery(con_npr, "SELECT * FROM tmp.H696_TSB_uttrekk")
phbu_raw <- dbGetQuery(con_npr, "SELECT * FROM tmp.H696_PHBU_uttrekk")
avt_raw  <- dbGetQuery(con_npr, "SELECT * FROM tmp.H696_AVT_uttrekk")
bosted   <- dbGetQuery(con_npr, "SELECT * FROM tmp.H696_bosted_v8")

avt_omsorgsniva_kontroll <- dbGetQuery(
  con_npr,
  "SELECT * FROM tmp.H696_AVT_omsorgsniva_kontroll"
)

################################################################################
# 3. Kontroller og klargjør kolonnenavn
################################################################################

# Standardiser til NPRId.
if ("NPRid" %in% names(bosted)) {
  bosted <- bosted %>% rename(NPRId = NPRid)
}

# De fem uttrekkstabellene skal normalt allerede ha NPRId.
# Disse kontrollene gjør scriptet robust dersom databasen returnerer NPRid.
if ("NPRid" %in% names(som_raw)) {
  som_raw <- som_raw %>% rename(NPRId = NPRid)
}
if ("NPRid" %in% names(phv_raw)) {
  phv_raw <- phv_raw %>% rename(NPRId = NPRid)
}
if ("NPRid" %in% names(tsb_raw)) {
  tsb_raw <- tsb_raw %>% rename(NPRId = NPRid)
}
if ("NPRid" %in% names(phbu_raw)) {
  phbu_raw <- phbu_raw %>% rename(NPRId = NPRid)
}
if ("NPRid" %in% names(avt_raw)) {
  avt_raw <- avt_raw %>% rename(NPRId = NPRid)
}



# Standardiser datatyper.
som_raw <- som_raw %>%
  mutate(
    NPRId = as.character(NPRId),
    aar = as.integer(aar),
    alder = as.integer(alder),
    kjonn = as.character(kjonn),
    omsorgsniva = as.integer(omsorgsniva)
  )

phv_raw <- phv_raw %>%
  mutate(
    NPRId = as.character(NPRId),
    aar = as.integer(aar),
    alder = as.integer(alder),
    kjonn = as.character(kjonn),
    omsorgsniva = as.integer(omsorgsniva)
  )

tsb_raw <- tsb_raw %>%
  mutate(
    NPRId = as.character(NPRId),
    aar = as.integer(aar),
    alder = as.integer(alder),
    kjonn = as.character(kjonn),
    omsorgsniva = as.integer(omsorgsniva)
  )

phbu_raw <- phbu_raw %>%
  mutate(
    NPRId = as.character(NPRId),
    aar = as.integer(aar),
    alder = as.integer(alder),
    kjonn = as.character(kjonn),
    omsorgsniva = as.integer(omsorgsniva)
  )

avt_raw <- avt_raw %>%
  mutate(
    NPRId = as.character(NPRId),
    aar = as.integer(aar),
    alder = as.integer(alder),
    kjonn = as.character(kjonn),
    omsorgsniva = as.integer(omsorgsniva)
  )

bosted <- bosted %>% mutate(NPRId = as.character(NPRId))

################################################################################
# 4. Kontroller omsorgsnivå
################################################################################

# SQL-scriptet skal allerede ha avgrenset alle fem områder til omsorgsnivå 1 og 2.
# R-scriptet stopper hvis andre eller manglende verdier likevel finnes.

ugyldig_som <- som_raw %>%
  filter(is.na(omsorgsniva) | !omsorgsniva %in% c(1, 2))
if (nrow(ugyldig_som) > 0) {
  stop("SOM inneholder omsorgsnivå utenfor 1 og 2, eller manglende omsorgsnivå.")
}

ugyldig_phv <- phv_raw %>%
  filter(is.na(omsorgsniva) | !omsorgsniva %in% c(1, 2))
if (nrow(ugyldig_phv) > 0) {
  stop("PHV inneholder omsorgsnivå utenfor 1 og 2, eller manglende omsorgsnivå.")
}

ugyldig_tsb <- tsb_raw %>%
  filter(is.na(omsorgsniva) | !omsorgsniva %in% c(1, 2))
if (nrow(ugyldig_tsb) > 0) {
  stop("TSB inneholder omsorgsnivå utenfor 1 og 2, eller manglende omsorgsnivå.")
}

ugyldig_phbu <- phbu_raw %>%
  filter(is.na(omsorgsniva) | !omsorgsniva %in% c(1, 2))
if (nrow(ugyldig_phbu) > 0) {
  stop("PHBU inneholder omsorgsnivå utenfor 1 og 2, eller manglende omsorgsnivå.")
}

ugyldig_avt <- avt_raw %>%
  filter(is.na(omsorgsniva) | !omsorgsniva %in% c(1, 2))
if (nrow(ugyldig_avt) > 0) {
  stop("AVTPHV inneholder omsorgsnivå utenfor 1 og 2, eller manglende omsorgsnivå.")
}

if (nrow(avt_raw) == 0) {
  warning("AVTPHV har 0 rader etter avgrensning til omsorgsnivå 1 og 2.")
}

################################################################################
# 5. Les inn kommunenavn fra KPR
################################################################################

kommune <- dbGetQuery(
  con_kpr,
  "SELECT DISTINCT kommunenr, kommunenavn, kommunenrdagens, kommunenavndagens,
          fylkenr, fylkenavn, fylkenrdagens, fylkenavndagens
   FROM kprutlevering.kpr.sted"
) %>%
  mutate(
    kommunenr = str_pad(as.character(kommunenr), width = 4, pad = "0", side = "left"),
    kommunenavn = as.character(kommunenavn),
    kommunenrdagens = as.character(kommunenrdagens),
    kommunenavndagens = as.character(kommunenavndagens),
    fylkenr = as.character(fylkenr),
    fylkenavn = as.character(fylkenavn),
    fylkenrdagens = as.character(fylkenrdagens),
    fylkenavndagens = as.character(fylkenavndagens),
    kommunenrdagens = if_else(kommunenr == "1534", "1580", kommunenrdagens),
    kommunenavndagens = if_else(kommunenr == "1534", "Haram", kommunenavndagens)
  )

# Behold 1 rad per kommunenummer for å unngå at koblingen lager duplikater.
kommune_duplikater <- kommune %>%
  count(kommunenr, name = "antall") %>%
  filter(antall > 1)

if (nrow(kommune_duplikater) > 0) {
  warning("Kommunetabellen har duplikate kommunenummer. Første rad beholdes per kommunenummer.")
}

kommune <- kommune %>% distinct(kommunenr, .keep_all = TRUE)

################################################################################
# 6. Lag bostedstabell
################################################################################

bosted_clean <- bosted %>%
  mutate(across(starts_with("kom_"), as.character)) %>%
  mutate(across(starts_with("kom_"), ~na_if(.x, "9999"))) %>%
  mutate(across(starts_with("kom_"), ~na_if(.x, "")))

bosted_long <- bind_rows(
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2012, Bostedskommune = coalesce(kom_1_1_2012, kom_31_12_2012)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2013, Bostedskommune = coalesce(kom_1_1_2013, kom_31_12_2013)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2014, Bostedskommune = coalesce(kom_1_1_2014, kom_31_12_2014)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2015, Bostedskommune = coalesce(kom_1_1_2015, kom_31_12_2015)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2016, Bostedskommune = coalesce(kom_1_1_2016, kom_31_12_2016)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2017, Bostedskommune = coalesce(kom_1_1_2017, kom_31_12_2017)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2018, Bostedskommune = coalesce(kom_1_1_2018, kom_31_12_2018)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2019, Bostedskommune = coalesce(kom_1_1_2019, kom_31_12_2019)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2020, Bostedskommune = coalesce(kom_1_1_2020, kom_31_12_2020)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2021, Bostedskommune = coalesce(kom_1_1_2021, kom_31_12_2021)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2022, Bostedskommune = coalesce(kom_1_1_2022, kom_31_12_2022)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2023, Bostedskommune = coalesce(kom_1_1_2023, kom_31_12_2023)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2024, Bostedskommune = coalesce(kom_1_1_2024, kom_31_12_2024)),
  bosted_clean %>% transmute(NPRId = NPRId, aar = 2025, Bostedskommune = coalesce(kom_1_1_2025, kom_31_12_2025))
) %>%
  filter(!is.na(Bostedskommune)) %>%
  mutate(Bostedskommune = str_pad(as.character(Bostedskommune), width = 4, pad = "0", side = "left")) %>%
  filter(str_detect(Bostedskommune, "^[0-9]{4}$")) %>%
  distinct(NPRId, aar, .keep_all = TRUE)

cat("Antall bostedsrader etter fallback og ekskludering: ", nrow(bosted_long), "\n", sep = "")

################################################################################
# 7. Koble bosted til hver tjeneste
################################################################################

som_bo <- som_raw %>%
  filter(
    omsorgsniva %in% c(1, 2),
    aar >= START_YEAR,
    aar <= END_YEAR
  ) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

phv_bo <- phv_raw %>%
  filter(
    omsorgsniva %in% c(1, 2),
    aar >= START_YEAR,
    aar <= END_YEAR
  ) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

tsb_bo <- tsb_raw %>%
  filter(
    omsorgsniva %in% c(1, 2),
    aar >= START_YEAR,
    aar <= END_YEAR
  ) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

phbu_bo <- phbu_raw %>%
  filter(
    omsorgsniva %in% c(1, 2),
    aar >= START_YEAR,
    aar <= END_YEAR
  ) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

avt_bo <- avt_raw %>%
  filter(
    omsorgsniva %in% c(1, 2),
    aar >= START_YEAR,
    aar <= END_YEAR
  ) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

cat("SOM: ", nrow(som_raw), " rader i SQL-uttrekket og ", nrow(som_bo), " rader etter bostedskobling.\n", sep = "")
cat("PHV: ", nrow(phv_raw), " rader i SQL-uttrekket og ", nrow(phv_bo), " rader etter bostedskobling.\n", sep = "")
cat("TSB: ", nrow(tsb_raw), " rader i SQL-uttrekket og ", nrow(tsb_bo), " rader etter bostedskobling.\n", sep = "")
cat("PHBU: ", nrow(phbu_raw), " rader i SQL-uttrekket og ", nrow(phbu_bo), " rader etter bostedskobling.\n", sep = "")
cat("AVTPHV: ", nrow(avt_raw), " rader i SQL-uttrekket og ", nrow(avt_bo), " rader etter bostedskobling.\n", sep = "")

################################################################################
# 8. Lag output-tabeller
################################################################################

# -----------------------------
# 8A. SOM
# -----------------------------

tabell_SOM <- som_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    I00_I99 = n_distinct(NPRId[I00_I99 == 1], na.rm = TRUE),
    I21_I22 = n_distinct(NPRId[I21_I22 == 1], na.rm = TRUE),
    J44 = n_distinct(NPRId[J44 == 1], na.rm = TRUE),
    M00_M99 = n_distinct(NPRId[M00_M99 == 1], na.rm = TRUE),
    S00_T78 = n_distinct(NPRId[S00_T78 == 1], na.rm = TRUE),
    S720_S729 = n_distinct(NPRId[S720_S729 == 1], na.rm = TRUE),
    S720_S722 = n_distinct(NPRId[S720_S722 == 1], na.rm = TRUE),
    T36_T65 = n_distinct(NPRId[T36_T65 == 1], na.rm = TRUE),
    S00_S09 = n_distinct(NPRId[S00_S09 == 1], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(kommune, by = c("Bostedskommune" = "kommunenr"), keep = FALSE) %>%
  arrange(aar, Bostedskommune, kjonn, alder) %>%
  rename(
    Ar = aar,
    Kjonn = kjonn,
    Alder = alder,
    Kommunenavn = kommunenavn,
    DagensKommunenr = kommunenrdagens,
    DagensKommunenavn = kommunenavndagens,
    Fylkenr = fylkenr,
    Fylkenavn = fylkenavn,
    DagensFylkenr = fylkenrdagens,
    DagensFylkenavn = fylkenavndagens
  ) %>%
  select(
    Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
    Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
    I00_I99, I21_I22, J44, M00_M99, S00_T78, S720_S729,
    S720_S722, T36_T65, S00_S09
  )

# -----------------------------
# 8B. PHV
# -----------------------------

tabell_PHV <- phv_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    F00_F99 = n_distinct(NPRId[F00_F99 == 1], na.rm = TRUE),
    F30_F39 = n_distinct(NPRId[F30_F39 == 1], na.rm = TRUE),
    F40_F48 = n_distinct(NPRId[F40_F48 == 1], na.rm = TRUE),
    F10_F16_F18_F19 = n_distinct(NPRId[F10_F16_F18_F19 == 1], na.rm = TRUE),
    F10 = n_distinct(NPRId[F10 == 1], na.rm = TRUE),
    F11_F16_F18_F19 = n_distinct(NPRId[F11_F16_F18_F19 == 1], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(kommune, by = c("Bostedskommune" = "kommunenr"), keep = FALSE) %>%
  arrange(aar, Bostedskommune, kjonn, alder) %>%
  rename(
    Ar = aar,
    Kjonn = kjonn,
    Alder = alder,
    Kommunenavn = kommunenavn,
    DagensKommunenr = kommunenrdagens,
    DagensKommunenavn = kommunenavndagens,
    Fylkenr = fylkenr,
    Fylkenavn = fylkenavn,
    DagensFylkenr = fylkenrdagens,
    DagensFylkenavn = fylkenavndagens
  ) %>%
  select(
    Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
    Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
    F00_F99, F30_F39, F40_F48, F10_F16_F18_F19, F10, F11_F16_F18_F19
  )

# -----------------------------
# 8C. TSB
# -----------------------------

tabell_TSB <- tsb_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    F00_F99 = n_distinct(NPRId[F00_F99 == 1], na.rm = TRUE),
    F30_F39 = n_distinct(NPRId[F30_F39 == 1], na.rm = TRUE),
    F40_F48 = n_distinct(NPRId[F40_F48 == 1], na.rm = TRUE),
    F10_F16_F18_F19 = n_distinct(NPRId[F10_F16_F18_F19 == 1], na.rm = TRUE),
    F10 = n_distinct(NPRId[F10 == 1], na.rm = TRUE),
    F11_F16_F18_F19 = n_distinct(NPRId[F11_F16_F18_F19 == 1], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(kommune, by = c("Bostedskommune" = "kommunenr"), keep = FALSE) %>%
  arrange(aar, Bostedskommune, kjonn, alder) %>%
  rename(
    Ar = aar,
    Kjonn = kjonn,
    Alder = alder,
    Kommunenavn = kommunenavn,
    DagensKommunenr = kommunenrdagens,
    DagensKommunenavn = kommunenavndagens,
    Fylkenr = fylkenr,
    Fylkenavn = fylkenavn,
    DagensFylkenr = fylkenrdagens,
    DagensFylkenavn = fylkenavndagens
  ) %>%
  select(
    Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
    Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
    F00_F99, F30_F39, F40_F48, F10_F16_F18_F19, F10, F11_F16_F18_F19
  )

# -----------------------------
# 8D. PHBU
# -----------------------------

tabell_PHBU <- phbu_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    F00_F99 = n_distinct(NPRId[F00_F99 == 1], na.rm = TRUE),
    F30_F39 = n_distinct(NPRId[F30_F39 == 1], na.rm = TRUE),
    F40_F48 = n_distinct(NPRId[F40_F48 == 1], na.rm = TRUE),
    F10_F16_F18_F19 = n_distinct(NPRId[F10_F16_F18_F19 == 1], na.rm = TRUE),
    F10 = n_distinct(NPRId[F10 == 1], na.rm = TRUE),
    F11_F16_F18_F19 = n_distinct(NPRId[F11_F16_F18_F19 == 1], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(kommune, by = c("Bostedskommune" = "kommunenr"), keep = FALSE) %>%
  arrange(aar, Bostedskommune, kjonn, alder) %>%
  rename(
    Ar = aar,
    Kjonn = kjonn,
    Alder = alder,
    Kommunenavn = kommunenavn,
    DagensKommunenr = kommunenrdagens,
    DagensKommunenavn = kommunenavndagens,
    Fylkenr = fylkenr,
    Fylkenavn = fylkenavn,
    DagensFylkenr = fylkenrdagens,
    DagensFylkenavn = fylkenavndagens
  ) %>%
  select(
    Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
    Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
    F00_F99, F30_F39, F40_F48, F10_F16_F18_F19, F10, F11_F16_F18_F19
  )

# -----------------------------
# 8E. AVTPHV
# -----------------------------

tabell_AVTPHV <- avt_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    F00_F99 = n_distinct(NPRId[F00_F99 == 1], na.rm = TRUE),
    F30_F39 = n_distinct(NPRId[F30_F39 == 1], na.rm = TRUE),
    F40_F48 = n_distinct(NPRId[F40_F48 == 1], na.rm = TRUE),
    F10_F16_F18_F19 = n_distinct(NPRId[F10_F16_F18_F19 == 1], na.rm = TRUE),
    F10 = n_distinct(NPRId[F10 == 1], na.rm = TRUE),
    F11_F16_F18_F19 = n_distinct(NPRId[F11_F16_F18_F19 == 1], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(kommune, by = c("Bostedskommune" = "kommunenr"), keep = FALSE) %>%
  arrange(aar, Bostedskommune, kjonn, alder) %>%
  rename(
    Ar = aar,
    Kjonn = kjonn,
    Alder = alder,
    Kommunenavn = kommunenavn,
    DagensKommunenr = kommunenrdagens,
    DagensKommunenavn = kommunenavndagens,
    Fylkenr = fylkenr,
    Fylkenavn = fylkenavn,
    DagensFylkenr = fylkenrdagens,
    DagensFylkenavn = fylkenavndagens
  ) %>%
  select(
    Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
    Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
    F00_F99, F30_F39, F40_F48, F10_F16_F18_F19, F10, F11_F16_F18_F19
  )

################################################################################
# 9. Kontroller output-tabellene
################################################################################



# Lag verdier til kontrolltabellen. Tomme tabeller får NA for min og maks år.
min_ar_som <- NA_integer_
max_ar_som <- NA_integer_
if (nrow(tabell_SOM) > 0) {
  min_ar_som <- min(tabell_SOM$Ar, na.rm = TRUE)
  max_ar_som <- max(tabell_SOM$Ar, na.rm = TRUE)
}

min_ar_phv <- NA_integer_
max_ar_phv <- NA_integer_
if (nrow(tabell_PHV) > 0) {
  min_ar_phv <- min(tabell_PHV$Ar, na.rm = TRUE)
  max_ar_phv <- max(tabell_PHV$Ar, na.rm = TRUE)
}

min_ar_tsb <- NA_integer_
max_ar_tsb <- NA_integer_
if (nrow(tabell_TSB) > 0) {
  min_ar_tsb <- min(tabell_TSB$Ar, na.rm = TRUE)
  max_ar_tsb <- max(tabell_TSB$Ar, na.rm = TRUE)
}

min_ar_phbu <- NA_integer_
max_ar_phbu <- NA_integer_
if (nrow(tabell_PHBU) > 0) {
  min_ar_phbu <- min(tabell_PHBU$Ar, na.rm = TRUE)
  max_ar_phbu <- max(tabell_PHBU$Ar, na.rm = TRUE)
}

min_ar_avt <- NA_integer_
max_ar_avt <- NA_integer_
if (nrow(tabell_AVTPHV) > 0) {
  min_ar_avt <- min(tabell_AVTPHV$Ar, na.rm = TRUE)
  max_ar_avt <- max(tabell_AVTPHV$Ar, na.rm = TRUE)
}

kontroll <- bind_rows(
  data.frame(
    Tjeneste = "SOM",
    Rader_i_SQL_uttrekk = nrow(som_raw),
    Unike_personer_i_SQL_uttrekk = n_distinct(som_raw$NPRId, na.rm = TRUE),
    Rader_omsorgsniva_1 = sum(som_raw$omsorgsniva == 1, na.rm = TRUE),
    Rader_omsorgsniva_2 = sum(som_raw$omsorgsniva == 2, na.rm = TRUE),
    Rader_etter_bosted = nrow(som_bo),
    Rader_i_output = nrow(tabell_SOM),
    Min_ar_output = min_ar_som,
    Max_ar_output = max_ar_som
  ),
  data.frame(
    Tjeneste = "PHV",
    Rader_i_SQL_uttrekk = nrow(phv_raw),
    Unike_personer_i_SQL_uttrekk = n_distinct(phv_raw$NPRId, na.rm = TRUE),
    Rader_omsorgsniva_1 = sum(phv_raw$omsorgsniva == 1, na.rm = TRUE),
    Rader_omsorgsniva_2 = sum(phv_raw$omsorgsniva == 2, na.rm = TRUE),
    Rader_etter_bosted = nrow(phv_bo),
    Rader_i_output = nrow(tabell_PHV),
    Min_ar_output = min_ar_phv,
    Max_ar_output = max_ar_phv
  ),
  data.frame(
    Tjeneste = "TSB",
    Rader_i_SQL_uttrekk = nrow(tsb_raw),
    Unike_personer_i_SQL_uttrekk = n_distinct(tsb_raw$NPRId, na.rm = TRUE),
    Rader_omsorgsniva_1 = sum(tsb_raw$omsorgsniva == 1, na.rm = TRUE),
    Rader_omsorgsniva_2 = sum(tsb_raw$omsorgsniva == 2, na.rm = TRUE),
    Rader_etter_bosted = nrow(tsb_bo),
    Rader_i_output = nrow(tabell_TSB),
    Min_ar_output = min_ar_tsb,
    Max_ar_output = max_ar_tsb
  ),
  data.frame(
    Tjeneste = "PHBU",
    Rader_i_SQL_uttrekk = nrow(phbu_raw),
    Unike_personer_i_SQL_uttrekk = n_distinct(phbu_raw$NPRId, na.rm = TRUE),
    Rader_omsorgsniva_1 = sum(phbu_raw$omsorgsniva == 1, na.rm = TRUE),
    Rader_omsorgsniva_2 = sum(phbu_raw$omsorgsniva == 2, na.rm = TRUE),
    Rader_etter_bosted = nrow(phbu_bo),
    Rader_i_output = nrow(tabell_PHBU),
    Min_ar_output = min_ar_phbu,
    Max_ar_output = max_ar_phbu
  ),
  data.frame(
    Tjeneste = "AVTPHV",
    Rader_i_SQL_uttrekk = nrow(avt_raw),
    Unike_personer_i_SQL_uttrekk = n_distinct(avt_raw$NPRId, na.rm = TRUE),
    Rader_omsorgsniva_1 = sum(avt_raw$omsorgsniva == 1, na.rm = TRUE),
    Rader_omsorgsniva_2 = sum(avt_raw$omsorgsniva == 2, na.rm = TRUE),
    Rader_etter_bosted = nrow(avt_bo),
    Rader_i_output = nrow(tabell_AVTPHV),
    Min_ar_output = min_ar_avt,
    Max_ar_output = max_ar_avt
  )
)

print(kontroll)
cat("\nAVTPHV-fordeling før omsorgsnivåfilter:\n")
print(avt_omsorgsniva_kontroll)

################################################################################
# 10. Skriv Excel-fil
################################################################################
setwd( "N:/Utleveringer/2026/Personidentifiserbart/24_02130_H696_folkehelseprofiler/Utlevering")
OUTPUT_XLSX <- paste0(
  "H696_NPR_2012_2025_",
  format(Sys.Date(), "%d%m%y"),
  ".xlsx"
)

wb <- createWorkbook()

addWorksheet(wb, "SOM")
writeData(wb, "SOM", tabell_SOM)
freezePane(wb, "SOM", firstRow = TRUE)

addWorksheet(wb, "PHV")
writeData(wb, "PHV", tabell_PHV)
freezePane(wb, "PHV", firstRow = TRUE)

addWorksheet(wb, "TSB")
writeData(wb, "TSB", tabell_TSB)
freezePane(wb, "TSB", firstRow = TRUE)

addWorksheet(wb, "PHBU")
writeData(wb, "PHBU", tabell_PHBU)
freezePane(wb, "PHBU", firstRow = TRUE)

addWorksheet(wb, "AVTPHV")
writeData(wb, "AVTPHV", tabell_AVTPHV)
freezePane(wb, "AVTPHV", firstRow = TRUE)

addWorksheet(wb, "Kontroll")
writeData(wb, "Kontroll", kontroll)
freezePane(wb, "Kontroll", firstRow = TRUE)

addWorksheet(wb, "AVT_omsorgsniva")
writeData(wb, "AVT_omsorgsniva", avt_omsorgsniva_kontroll)
freezePane(wb, "AVT_omsorgsniva", firstRow = TRUE)

saveWorkbook(wb, OUTPUT_XLSX, overwrite = TRUE)

cat("Excel-fil lagret som: ", OUTPUT_XLSX, "\n", sep = "")

################################################################################
# 11. Koble fra databasene
################################################################################

dbDisconnect(con_npr)
dbDisconnect(con_kpr)

cat("Scriptet er ferdig.\n")
