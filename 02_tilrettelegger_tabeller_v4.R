################################################################################
# H-696-E2 Folkehelseprofiler og statistikkbank 2026
# NPR-leveranse 2012-2025
# Laget av: TTF  13.juli.2026

################################################################################

################################################################################
#
# ENDRINGER FRA leveranse 2025:
# . Diagnosegruppen I20-I25 er fjernet og erstattet av I21-I22.
# . S720-S722 med NFB/NFJ-prosedyrekoder er ikke lenger med som egen variabel.
# . PHV, TSB, PHBU og AVTPHV er tatt med i tillegg til SOM.
# . Bosted bruker kommune per 1.1, og 31.12 samme år hvis 1.1 mangler.

################################################################################

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
  Trusted_connection = "Yes",
  Encrypt = "Yes",
  Encoding = "utf8"
)

con_kpr <- dbConnect(
  odbc(),
  Driver = "ODBC Driver 17 for SQL Server",
  Server = "NPRDVHPROD",
  Database = "KPRUtlevering",
  Trusted_connection = "Yes",
  Encrypt = "Yes",
  Encoding = "utf8"
)

try(Sys.setlocale("LC_ALL", "nb-NO.UTF-8"), silent = TRUE)

################################################################################
# 2. Les tabellene som SQL-scriptet har laget
################################################################################

cat("Leser SQL-tabeller...\n")

som_raw  <- dbGetQuery(con_npr, "select * from tmp.H696_SOM_uttrekk")
phv_raw  <- dbGetQuery(con_npr, "select * from tmp.H696_PHV_uttrekk")
tsb_raw  <- dbGetQuery(con_npr, "select * from tmp.H696_TSB_uttrekk")
phbu_raw <- dbGetQuery(con_npr, "select * from tmp.H696_PHBU_uttrekk")
avt_raw  <- dbGetQuery(con_npr, "select * from tmp.H696_AVT_uttrekk")
bosted   <- dbGetQuery(con_npr, "select * from tmp.H696_bosted_v5")
# SQL tabeller har NPRid; standardisere til NPRid in R
if ("NPRid" %in% names(bosted)) {
  bosted <- bosted %>% rename(NPRId = NPRid)
}

################################################################################
# 3. Les inn kommunenavn fra KPR
################################################################################

kommune <- dbGetQuery(
  con_kpr,
  "select distinct kommunenr, kommunenavn, kommunenrdagens, kommunenavndagens,
          fylkenr, fylkenavn, fylkenrdagens, fylkenavndagens
   from kprutlevering.kpr.sted"
) %>%
  mutate(
    kommunenr = str_pad(as.character(kommunenr), width = 4, pad = "0", side = "left"),
    kommunenrdagens = as.character(kommunenrdagens),
    kommunenavndagens = as.character(kommunenavndagens),
    kommunenrdagens = if_else(kommunenr == "1534", "1580", kommunenrdagens),
    kommunenavndagens = if_else(kommunenr == "1534", "Haram", kommunenavndagens)
  )

################################################################################
# 4. Lag bostedstabell 
#
# Regel fra oppdatert variabelliste:
# - Bruk kommune per 1.1.
# - Hvis kommune per 1.1 mangler, bruk kommune per 31.12 samme Ãr.
# - Hvis begge mangler, ekskluder personen for det Ãret.
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
# 5. Koble bosted til hver tjeneste 
################################################################################

som_bo <- som_raw %>%
  filter(!is.na(kjonn), aar >= START_YEAR, aar <= END_YEAR) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

phv_bo <- phv_raw %>%
  filter(!is.na(kjonn), aar >= START_YEAR, aar <= END_YEAR) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

tsb_bo <- tsb_raw %>%
  filter(!is.na(kjonn), aar >= START_YEAR, aar <= END_YEAR) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

phbu_bo <- phbu_raw %>%
  filter(!is.na(kjonn), aar >= START_YEAR, aar <= END_YEAR) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

avt_bo <- avt_raw %>%
  filter(!is.na(kjonn), aar >= START_YEAR, aar <= END_YEAR) %>%
  inner_join(bosted_long, by = c("NPRId", "aar"))

################################################################################
# 6. Lag output-tabeller 
################################################################################

# -----------------------------
# 6A. SOM
# -----------------------------
tabell_SOM <- som_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    I00_I99 = n_distinct(NPRId[I00_I99 == 1]),
    I21_I22 = n_distinct(NPRId[I21_I22 == 1]),
    J44 = n_distinct(NPRId[J44 == 1]),
    M00_M99 = n_distinct(NPRId[M00_M99 == 1]),
    S00_T78 = n_distinct(NPRId[S00_T78 == 1]),
    S720_S729 = n_distinct(NPRId[S720_S729 == 1]),
    S720_S722 = n_distinct(NPRId[S720_S722 == 1]),
    T36_T65 = n_distinct(NPRId[T36_T65 == 1]),
    S00_S09 = n_distinct(NPRId[S00_S09 == 1]),
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
  select(Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
         Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
         I00_I99, I21_I22, J44, M00_M99, S00_T78, S720_S729, S720_S722, T36_T65, S00_S09)

# -----------------------------
# 6B. PHV
# -----------------------------
tabell_PHV <- phv_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    F00_F99 = n_distinct(NPRId[F00_F99 == 1]),
    F30_F39 = n_distinct(NPRId[F30_F39 == 1]),
    F40_F48 = n_distinct(NPRId[F40_F48 == 1]),
    F10_F16_F18_F19 = n_distinct(NPRId[F10_F16_F18_F19 == 1]),
    F10 = n_distinct(NPRId[F10 == 1]),
    F11_F16_F18_F19 = n_distinct(NPRId[F11_F16_F18_F19 == 1]),
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
  select(Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
         Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
         F00_F99, F30_F39, F40_F48, F10_F16_F18_F19, F10, F11_F16_F18_F19)

# -----------------------------
# 6C. TSB
# -----------------------------
tabell_TSB <- tsb_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    F00_F99 = n_distinct(NPRId[F00_F99 == 1]),
    F30_F39 = n_distinct(NPRId[F30_F39 == 1]),
    F40_F48 = n_distinct(NPRId[F40_F48 == 1]),
    F10_F16_F18_F19 = n_distinct(NPRId[F10_F16_F18_F19 == 1]),
    F10 = n_distinct(NPRId[F10 == 1]),
    F11_F16_F18_F19 = n_distinct(NPRId[F11_F16_F18_F19 == 1]),
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
  select(Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
         Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
         F00_F99, F30_F39, F40_F48, F10_F16_F18_F19, F10, F11_F16_F18_F19)

# -----------------------------
# 6D. PHBU
# -----------------------------
tabell_PHBU <- phbu_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    F00_F99 = n_distinct(NPRId[F00_F99 == 1]),
    F30_F39 = n_distinct(NPRId[F30_F39 == 1]),
    F40_F48 = n_distinct(NPRId[F40_F48 == 1]),
    F10_F16_F18_F19 = n_distinct(NPRId[F10_F16_F18_F19 == 1]),
    F10 = n_distinct(NPRId[F10 == 1]),
    F11_F16_F18_F19 = n_distinct(NPRId[F11_F16_F18_F19 == 1]),
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
  select(Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
         Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
         F00_F99, F30_F39, F40_F48, F10_F16_F18_F19, F10, F11_F16_F18_F19)

# -----------------------------
# 6E. AVTPHV
# -----------------------------
tabell_AVTPHV <- avt_bo %>%
  group_by(aar, Bostedskommune, kjonn, alder) %>%
  summarise(
    F00_F99 = n_distinct(NPRId[F00_F99 == 1]),
    F30_F39 = n_distinct(NPRId[F30_F39 == 1]),
    F40_F48 = n_distinct(NPRId[F40_F48 == 1]),
    F10_F16_F18_F19 = n_distinct(NPRId[F10_F16_F18_F19 == 1]),
    F10 = n_distinct(NPRId[F10 == 1]),
    F11_F16_F18_F19 = n_distinct(NPRId[F11_F16_F18_F19 == 1]),
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
  select(Ar, Bostedskommune, Kommunenavn, DagensKommunenr, DagensKommunenavn,
         Fylkenr, Fylkenavn, DagensFylkenr, DagensFylkenavn, Kjonn, Alder,
         F00_F99, F30_F39, F40_F48, F10_F16_F18_F19, F10, F11_F16_F18_F19)

################################################################################
# 7. Kontroll 
################################################################################

if ("NPRId" %in% names(tabell_SOM) || "NPRId" %in% names(tabell_PHV) ||
    "NPRId" %in% names(tabell_TSB) || "NPRId" %in% names(tabell_PHBU) ||
    "NPRId" %in% names(tabell_AVTPHV)) {
  stop("Personvernfeil: NPRId finnes i en av output-tabellene.")
}

if (min(tabell_SOM$Ar, na.rm = TRUE) < START_YEAR || max(tabell_SOM$Ar, na.rm = TRUE) > END_YEAR) stop("SOM har Ã¥r utenfor perioden.")
if (min(tabell_PHV$Ar, na.rm = TRUE) < START_YEAR || max(tabell_PHV$Ar, na.rm = TRUE) > END_YEAR) stop("PHV har Ã¥r utenfor perioden.")
if (min(tabell_TSB$Ar, na.rm = TRUE) < START_YEAR || max(tabell_TSB$Ar, na.rm = TRUE) > END_YEAR) stop("TSB har Ã¥r utenfor perioden.")
if (min(tabell_PHBU$Ar, na.rm = TRUE) < START_YEAR || max(tabell_PHBU$Ar, na.rm = TRUE) > END_YEAR) stop("PHBU har Ã¥r utenfor perioden.")
if (min(tabell_AVTPHV$Ar, na.rm = TRUE) < START_YEAR || max(tabell_AVTPHV$Ar, na.rm = TRUE) > END_YEAR) stop("AVTPHV har Ã¥r utenfor perioden.")

kontroll <- bind_rows(
  data.frame(Tjeneste = "SOM", Rader_i_SQL_uttrekk = nrow(som_raw), Unike_personer_i_SQL_uttrekk = n_distinct(som_raw$NPRId), Rader_i_output = nrow(tabell_SOM), Min_ar_output = min(tabell_SOM$Ar, na.rm = TRUE), Max_ar_output = max(tabell_SOM$Ar, na.rm = TRUE)),
  data.frame(Tjeneste = "PHV", Rader_i_SQL_uttrekk = nrow(phv_raw), Unike_personer_i_SQL_uttrekk = n_distinct(phv_raw$NPRId), Rader_i_output = nrow(tabell_PHV), Min_ar_output = min(tabell_PHV$Ar, na.rm = TRUE), Max_ar_output = max(tabell_PHV$Ar, na.rm = TRUE)),
  data.frame(Tjeneste = "TSB", Rader_i_SQL_uttrekk = nrow(tsb_raw), Unike_personer_i_SQL_uttrekk = n_distinct(tsb_raw$NPRId), Rader_i_output = nrow(tabell_TSB), Min_ar_output = min(tabell_TSB$Ar, na.rm = TRUE), Max_ar_output = max(tabell_TSB$Ar, na.rm = TRUE)),
  data.frame(Tjeneste = "PHBU", Rader_i_SQL_uttrekk = nrow(phbu_raw), Unike_personer_i_SQL_uttrekk = n_distinct(phbu_raw$NPRId), Rader_i_output = nrow(tabell_PHBU), Min_ar_output = min(tabell_PHBU$Ar, na.rm = TRUE), Max_ar_output = max(tabell_PHBU$Ar, na.rm = TRUE)),
  data.frame(Tjeneste = "AVTPHV", Rader_i_SQL_uttrekk = nrow(avt_raw), Unike_personer_i_SQL_uttrekk = n_distinct(avt_raw$NPRId), Rader_i_output = nrow(tabell_AVTPHV), Min_ar_output = min(tabell_AVTPHV$Ar, na.rm = TRUE), Max_ar_output = max(tabell_AVTPHV$Ar, na.rm = TRUE))
)

print(kontroll)

################################################################################
# 8. Skriv Excel-fil 
################################################################################

OUTPUT_XLSX <- paste0("H696_NPR_2012_2025", format(Sys.Date(), "%d%m%y"), ".xlsx")

  wb <- createWorkbook()
  
  addWorksheet(wb, "SOM")
  writeData(wb, "SOM", tabell_SOM)
  
  addWorksheet(wb, "PHV")
  writeData(wb, "PHV", tabell_PHV)
  
  addWorksheet(wb, "TSB")
  writeData(wb, "TSB", tabell_TSB)
  
  addWorksheet(wb, "PHBU")
  writeData(wb, "PHBU", tabell_PHBU)
  
  addWorksheet(wb, "AVTPHV")
  writeData(wb, "AVTPHV", tabell_AVTPHV)
  
  saveWorkbook(wb, OUTPUT_XLSX, overwrite = TRUE)






################################################################################
# 9. Koble fra databasene
################################################################################

dbDisconnect(con_npr)
dbDisconnect(con_kpr)
