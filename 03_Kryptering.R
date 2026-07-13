# ============================================================
#  Kryptering (ZIP) + SMS (SMSOut)
#  - Lister ALLE .xlsx i prosjektmappen
#  - Loop: krypterer hver fil til egen .zip (AES-256)
#  - Passord lagres i passord.txt
#  - SMSOut-fil lages og legges i N://Temp/SMSOut/
# ============================================================

# -----------------------------
# 9.1 Innstillinger
# -----------------------------

# Prosjektmappe 
project_folder <-  "utlevering"

# Hvor ligger 7z.exe 
seven_zip_path <- "C:/Program Files/7-Zip/7z.exe"  

# Telefonliste i prosjektmappen (1 linje per nummer)
telefon_fil <- file.path(project_folder, "telefon.txt")

# SMSOut drop-folder 
smsout_folder <- "N://Temp/SMSOut/" 
smsout_filename <- "hørsel_passord.csv"

# -----------------------------
# 9.2 Funksjon: lag passord
# -----------------------------
generate_password <- function(length = 16) {
  char_set <- c(LETTERS,letters,as.character(0:9))
  paste(sample(char_set, length, replace = TRUE), collapse = "")
}

# Lag passord + lagre til passord.txt i prosjektmappen
passord <- generate_password(16)
passord_path <- file.path(project_folder, "passord.txt")
writeLines(passord, passord_path)

# -----------------------------
# 9.3 Funksjon: krypter alle Excel-filer
# -----------------------------
encrypt_all_xlsx_to_zip <- function(folder, seven_zip, password) {
  
  # 1) Finn alle Excel-filer (.xlsx) i mappen
  xlsx_files <- list.files(path = folder, pattern = "\\.xlsx$", full.names = TRUE)
  
  if (length(xlsx_files) == 0) {
    stop("Fant ingen .xlsx-filer i: ", folder)
  }
  
  # 2) Loop over hver fil og lag en kryptert ZIP med samme navn
  for (file in xlsx_files) {
    
    zip_name <- sub("\\.xlsx$", ".zip", basename(file))
    zip_path <- file.path(folder, zip_name)
    
    
    #  - a       = add til arkiv
    #  - -tzip   = zip-format
    #  - -p      = passord
    #  - -mem=AES256 = AES-256 kryptering 
    cmd <- paste0(
      "\"", seven_zip, "\" a -tzip ",
      "\"", zip_path, "\" ",
      "\"", file, "\" ",
      "-p\"", password, "\" -mem=AES256"
    )
    
    system(cmd)
  }
  
  # Returner filene (nyttig for logging)
  invisible(xlsx_files)
}

# Kjør kryptering
encrypted_files <- encrypt_all_xlsx_to_zip(project_folder, seven_zip_path, passord)

# -----------------------------
#  Funksjon: lag SMSOut-fil med passord
# -----------------------------
write_smsout_file <- function(password_file, phone_file, out_folder, out_name) {
  
  # Les passord (første ikke-tomme linje) 
  lines <- trimws(readLines(password_file, warn = FALSE))
  lines <- lines[nzchar(lines)]
  passord <- lines[1]
  
  # Les telefonnummer (1 per linje) 
  telefon <- trimws(readLines(phone_file, warn = FALSE))
  telefon <- telefon[nzchar(telefon)]
  
  if (length(telefon) == 0) {
    stop("Ingen telefonnummer funnet i: ", phone_file)
  }
  
  # Bygg SMSOut innhold:
  # Header "TelefonNr;Melding;" og hver rad "nummer;melding;" 
  header <- "TelefonNr;Melding;"
  melding <- paste0("Ditt passord for å åpne kryptert horsel ZIP-fil er: ", passord)
  rows <- paste0(telefon, ";", melding, ";")
  sms_content <- c(header, rows)
  
  # Sørg for at out_folder finnes
  if (!dir.exists(out_folder)) dir.create(out_folder, recursive = TRUE)
  
  out_path <- file.path(out_folder, out_name)
  writeLines(sms_content, out_path, useBytes = TRUE)
  
  return(out_path)
}

# Lag SMSOut-fil
smsout_path <- write_smsout_file(
  password_file = passord_path,
  phone_file = telefon_fil,
  out_folder = smsout_folder,
  out_name = smsout_filename
)

# -----------------------------
#  Logg til konsoll
# -----------------------------
cat("Ferdig!\n")
cat("Passord lagret i: ", passord_path, "\n", sep = "")
cat("Kryptert følgende Excel-filer:\n")
print(encrypted_files)
cat("SMSOut-fil skrevet til: ", smsout_path, "\n", sep = "")
