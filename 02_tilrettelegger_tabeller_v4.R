######################################################################################

# Saksnummer: H-696 Folkehelseprofiler
# Søker: 
# Saksbehandler: Ailin Falkmo Hansen
# Oppstart dato: 30.04.25 - siste avklaringer 14.05.25

# Ønsker følgende statistikk diagnosegrupper per år, alder, kjønn og kommune som en enkelt tabell 2010-2024

#####################################################################################
# Laster inn div pakker
#####################################################################################

library(tidyverse)
library(odbc)
library(openxlsx)

rm(list=ls())

######################################################################################
# Koble til server
######################################################################################

con_npr <- dbConnect(odbc(),
                     Driver = "ODBC Driver 17 for SQL Server",
                     Server = "NPRSQLprod",
                     Database = "NPRNasjonaltdatagrunnlag",
                     Trusted_connection = "Yes",
                     Encrypt = "Yes",
                     Encoding="utf8")

con_kpr <- dbConnect(odbc(),
                     Driver = "ODBC Driver 17 for SQL Server",
                     Server = "NPRDVHPROD",
                     Database = "KPRUtlevering",
                     Trusted_connection = "Yes",
                     Encrypt = "Yes",
                     Encoding="utf8")

Sys.setlocale("LC_ALL", "nb-NO.UTF-8")

######################################################################################
##Henter kommunenavn fra KPRSted
######################################################################################

kprbosted_kommunenavn  <- dbGetQuery(con_kpr,
                    "select distinct kommunenr, kommunenavn, kommunenrdagens, kommunenavndagens, 
                    fylkenr, fylkenavn, fylkenrdagens, fylkenavndagens from kprutlevering.kpr.sted") %>%
  mutate(kommunenr = as.character(kommunenr)) %>%
  mutate(kommunenr = str_pad(kommunenr, width = 4, pad = '0', side = 'left')) %>%
  # p.t er det feil i overnevnte view - endrer både kommunenrdagens og kommunenavndagens (trenger egentlig ikke denne informasjonen etter siste avklaringer, men lar stå i tilfelle endringer fra søker)
  mutate(kommunenrdagens = case_when(kommunenr=='1534' ~ '1580', TRUE ~ kommunenr)) %>%
  mutate(kommunenavndagens = case_when(kommunenr=='1534' ~ 'Haram', TRUE ~ kommunenavndagens)) 

######################################################################################
# Henter inn aktivitets- og bostedopplysninger for utvalget
######################################################################################

uttrekk <- dbGetQuery(con_npr,
                           "select * FROM tmp.H696_folkehelseprofiler_uttrekk") %>%
  # fjerner de som ikke har informasjon om kjønn (svært få)
  filter(!is.na(kjonn)) 
  

bosted <- dbGetQuery(con_npr,
                 "select * FROM tmp.H696_bosted")

# søker ønsker bosted per 1.1, alternativt 1.1 påfølgende år. Fyller inn bostedskommune fra påfølgende år, dersom bostedskommune samme år mangler.
bosted_fyller <- bosted %>%
              mutate(komnr2010 = ifelse(komnr2010==9999, NA, komnr2010)) %>% 
              mutate(komnr2011 = ifelse(komnr2011==9999, NA, komnr2011)) %>% 
              mutate(komnr2012 = ifelse(komnr2012==9999, NA, komnr2012)) %>% 
              mutate(komnr2013 = ifelse(komnr2013==9999, NA, komnr2013)) %>% 
              mutate(komnr2014 = ifelse(komnr2014==9999, NA, komnr2014)) %>% 
              mutate(komnr2015 = ifelse(komnr2015==9999, NA, komnr2015)) %>% 
              mutate(komnr2016 = ifelse(komnr2016==9999, NA, komnr2016)) %>% 
              mutate(komnr2017 = ifelse(komnr2017==9999, NA, komnr2017)) %>% 
              mutate(komnr2018 = ifelse(komnr2018==9999, NA, komnr2018)) %>% 
              mutate(komnr2019 = ifelse(komnr2019==9999, NA, komnr2019)) %>% 
              mutate(komnr2020 = ifelse(komnr2020==9999, NA, komnr2020)) %>% 
              mutate(komnr2021 = ifelse(komnr2021==9999, NA, komnr2021)) %>% 
              mutate(komnr2022 = ifelse(komnr2022==9999, NA, komnr2022)) %>% 
              mutate(komnr2023 = ifelse(komnr2023==9999, NA, komnr2023)) %>% 
              mutate(komnr2024 = ifelse(komnr2024==9999, NA, komnr2024)) %>%
              # fyller inn bostedsopplysninger fra påfølgende år dersom de mangler per 1.1 inneværende år
              mutate(komnr2010 = ifelse(!is.na(komnr2010), komnr2010, komnr2011)) %>% 
              mutate(komnr2011 = ifelse(!is.na(komnr2011), komnr2011, komnr2012)) %>% 
              mutate(komnr2012 = ifelse(!is.na(komnr2012), komnr2012, komnr2013)) %>% 
              mutate(komnr2013 = ifelse(!is.na(komnr2013), komnr2013, komnr2014)) %>% 
              mutate(komnr2014 = ifelse(!is.na(komnr2014), komnr2014, komnr2015)) %>% 
              mutate(komnr2015 = ifelse(!is.na(komnr2015), komnr2015, komnr2016)) %>% 
              mutate(komnr2016 = ifelse(!is.na(komnr2016), komnr2016, komnr2017)) %>% 
              mutate(komnr2017 = ifelse(!is.na(komnr2017), komnr2017, komnr2018)) %>% 
              mutate(komnr2018 = ifelse(!is.na(komnr2018), komnr2018, komnr2019)) %>% 
              mutate(komnr2019 = ifelse(!is.na(komnr2019), komnr2019, komnr2020)) %>% 
              mutate(komnr2020 = ifelse(!is.na(komnr2020), komnr2020, komnr2021)) %>% 
              mutate(komnr2021 = ifelse(!is.na(komnr2021), komnr2021, komnr2022)) %>% 
              mutate(komnr2022 = ifelse(!is.na(komnr2022), komnr2022, komnr2023)) %>% 
              mutate(komnr2023 = ifelse(!is.na(komnr2023), komnr2023, komnr2024)) %>% 
              mutate(komnr2024 = ifelse(!is.na(komnr2024), komnr2024, komnr2025)) %>%
  rename(NPRId = NPRid)
  
# lager en enkelt variabel for bostedskommune per kontakt
uttrekk_med_bosted <- uttrekk %>%
  left_join(bosted_fyller, by=c('NPRId')) %>%
  mutate(bostedskommune_1_1 = case_when(aar==2010 ~ komnr2010,
                                        aar==2011 ~ komnr2011,
                                        aar==2012 ~ komnr2012,
                                        aar==2013 ~ komnr2013,
                                        aar==2014 ~ komnr2014,
                                        aar==2015 ~ komnr2015,
                                        aar==2016 ~ komnr2016,
                                        aar==2017 ~ komnr2017,
                                        aar==2018 ~ komnr2018,
                                        aar==2019 ~ komnr2019,
                                        aar==2020 ~ komnr2020,
                                        aar==2021 ~ komnr2021,
                                        aar==2022 ~ komnr2022,
                                        aar==2023 ~ komnr2023,
                                        aar==2024 ~ komnr2024)) %>%
  # fikse for påkobling av navn
  mutate(bostedskommune_1_1 = as.character(bostedskommune_1_1)) %>%
  mutate(bostedskommune_1_1 = str_pad(bostedskommune_1_1, width = 4, pad = '0', side = 'left')) %>%
  # fjerner alle som ikke har bostedskommune 1.1 etter avtale med søker, fjerner også noen veldig få individer med bostedskommune lik 9999
  filter(!is.na(bostedskommune_1_1)) %>%
  filter(!bostedskommune_1_1=='9999') %>%
  # koble på kommunenavn
  left_join(kprbosted_kommunenavn, by=c('bostedskommune_1_1'='kommunenr'), keep = T ) 


# Aar, alder, kjønn og diagnosegrupper (tabell som søker ønsker) 
######################################################################################

# per aar og diagnosegrupper
antall_pasienter_diagnoser_100_I99_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(I00_I99==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(I00_I99 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_120_I25_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(I20_I25==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(I20_I25 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_J440_J449_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(J440_J449==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(J440_J449 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_M00_M99_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(M00_M99==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(M00_M99 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_S00_T78_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(S00_T78==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(S00_T78 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_S720_S722_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(S720_S722==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(S720_S722 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_S720_S722_pros_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(S720_S722_pros==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(S720_S722_pros = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_T36_T65_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(T36_T65==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(T36_T65 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_S00_S09_alder_kjonn_bostedskommune <- uttrekk_med_bosted %>%
  filter(S00_S09==1) %>%
  group_by(aar, bostedskommune_1_1, kjonn, alder) %>%
  summarise(S00_S09 = n_distinct(NPRId)) %>%
  ungroup()


# slår sammen til en tabell
antall_pasienter_aar_diagnoser <- antall_pasienter_diagnoser_100_I99_alder_kjonn_bostedskommune %>%
  full_join(antall_pasienter_diagnoser_120_I25_alder_kjonn_bostedskommune, by=c('aar', 'bostedskommune_1_1', 'kjonn', 'alder')) %>%
  full_join(antall_pasienter_diagnoser_J440_J449_alder_kjonn_bostedskommune, by=c('aar', 'bostedskommune_1_1', 'kjonn', 'alder')) %>%
  full_join(antall_pasienter_diagnoser_M00_M99_alder_kjonn_bostedskommune, by=c('aar', 'bostedskommune_1_1', 'kjonn', 'alder')) %>%
  full_join(antall_pasienter_diagnoser_S00_T78_alder_kjonn_bostedskommune, by=c('aar', 'bostedskommune_1_1', 'kjonn', 'alder')) %>%
  full_join(antall_pasienter_diagnoser_S720_S722_alder_kjonn_bostedskommune, by=c('aar', 'bostedskommune_1_1', 'kjonn', 'alder')) %>%
  full_join(antall_pasienter_diagnoser_S720_S722_pros_alder_kjonn_bostedskommune, by=c('aar', 'bostedskommune_1_1', 'kjonn', 'alder')) %>%
  full_join(antall_pasienter_diagnoser_T36_T65_alder_kjonn_bostedskommune, by=c('aar', 'bostedskommune_1_1', 'kjonn', 'alder')) %>%
  full_join(antall_pasienter_diagnoser_S00_S09_alder_kjonn_bostedskommune, by=c('aar', 'bostedskommune_1_1', 'kjonn', 'alder')) %>%
  mutate(across(where(is.numeric), function(x) replace_na(x, 0))) %>%
  mutate(across(where(is.numeric), as.character)) %>%
  rename('År' = aar, 'Kjønn' = kjonn)

head(antall_pasienter_aar_diagnoser) 
dim(antall_pasienter_aar_diagnoser) # 735.302     13

######################################################################################
# Tabeller
######################################################################################


# lagrer ut
samle_tabeller <- function(tabelliste,tabelltitler,innsti,utsti) {
  
  mal <- loadWorkbook(innsti)
  
  teller <- 0
  for (i in names(tabelliste)) {
    teller <- teller+1
    print(teller)
    
    cloneWorksheet(mal, i, 'Sheet1')
    
    # Bruke tabellstiler fra excel
    writeData(mal, sheet=i, tabelltitler[[teller]],startCol=1, startRow=2)
    writeDataTable(mal, sheet=i, tabelliste[[i]], startCol=1, startRow=4, tableStyle="TableStyleLight1")
    
    # Wrap tittel og endre litt på formattering
    wrap_title_style<-createStyle(wrapText = TRUE, valign = "top", textDecoration = "bold", border = "bottom", borderStyle="thin")
    addStyle(mal, sheet=i, style = wrap_title_style, cols=1:11, rows=2)
    
    # Legge til tusen-separerte tall - for numeriske tall
    thousand_style <- createStyle(numFmt = "#,##", halign = 'right')
    addStyle(mal, sheet = i, style = thousand_style, rows=4:(nrow(tabelliste[[i]]) + 4), cols=4:ncol(tabelliste[[i]]), gridExpand= T)
    
    # header style
    header_style <- createStyle(halign = 'center')
    addStyle(mal, sheet = i, style = header_style, rows=4, cols=1:ncol(tabelliste[[i]]), gridExpand= T)
    
  }
  removeWorksheet(mal,'Sheet1')
  saveWorkbook(mal,utsti, overwrite =T)
} 

tabeller = list('Tabell1' = antall_pasienter_aar_diagnoser)

titler = list('Tabell 1. Antall unike personer som mottok behandling med dag- og/eller døgnopphold for utvalgte tilstand-/diagnosegrupper innen somatikk (avdelingsopphold). Fordelt per bostedskommune per 1.1, kjønn, alder og år 2010-2024. Kun hovedtilstander er inkluderte i datagrunnlaget. Kilde: Norsk pasientregister (NPR)')


samle_tabeller(tabeller,titler,
               "FHI_mal_statistikk_A4liggende.xlsx",
               "H696_NPR_diagnosegrupper_spesialisthelsetjenesten_somatikk_2010_2024_v170925.xlsx") 



# lage liste med NPRider som skal inn i register-utleveringsløsningen
nprid <- uttrekk_med_bosted %>% select(NPRId) %>% distinct()
  

# sjekker
head(nprid)
dim(nprid) # 1.972.673                

# Til register-utleveringsløsningen
#write.table(nprid,"p24_02130_nprid.txt", row.names = F, col.names = F, eol=";\n", quote =F) #

######################################################################################
# dobbeltsjekker totaltaøø
######################################################################################

# leser inn resultatfil
antall_pasienter_per_diagnosegruppe_per_aar <- antall_pasienter_aar_diagnoser %>%
  group_by(År) %>%
  mutate(I00_I99 = as.numeric(I00_I99)) %>% 
  summarise(across(where(is.numeric), sum, .names="sum_{.col}")) 

# ser OK ut---

# per aar og diagnosegrupper
antall_pasienter_diagnoser_100_I99 <- uttrekk %>%
  filter(I00_I99==1) %>%
  group_by(aar) %>%
  summarise(I00_I99 = n_distinct(NPRId)) %>%
  ungroup()


# per aar og diagnosegrupper
antall_pasienter_diagnoser_120_I25 <- uttrekk %>%
  filter(I20_I25==1) %>%
  group_by(aar) %>%
  summarise(I20_I25 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_J440_J449 <- uttrekk %>%
  filter(J440_J449==1) %>%
  group_by(aar) %>%
  summarise(J440_J449 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_M00_M99 <- uttrekk %>%
  filter(M00_M99==1) %>%
  group_by(aar) %>%
  summarise(M00_M99 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_S00_T78 <- uttrekk %>%
  filter(S00_T78==1) %>%
  group_by(aar) %>%
  summarise(S00_T78 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_S720_S722 <- uttrekk %>%
  filter(S720_S722==1) %>%
  group_by(aar) %>%
  summarise(S720_S722 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_S720_S722_pros <- uttrekk %>%
  filter(S720_S722_pros==1) %>%
  group_by(aar) %>%
  summarise(S720_S722_pros = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_T36_T65 <- uttrekk %>%
  filter(T36_T65==1) %>%
  group_by(aar) %>%
  summarise(T36_T65 = n_distinct(NPRId)) %>%
  ungroup()

# per aar og diagnosegrupper
antall_pasienter_diagnoser_S00_S09 <- uttrekk %>%
  filter(S00_S09==1) %>%
  group_by(aar) %>%
  summarise(S00_S09 = n_distinct(NPRId)) %>%
  ungroup()

