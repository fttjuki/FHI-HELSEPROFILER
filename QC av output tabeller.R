# QC av output tabeller

if ("NPRId" %in% names(tabell_SOM)) {
  stop("Personvernfeil: NPRId finnes i tabell_SOM.")
}
if ("NPRId" %in% names(tabell_PHV)) {
  stop("Personvernfeil: NPRId finnes i tabell_PHV.")
}
if ("NPRId" %in% names(tabell_TSB)) {
  stop("Personvernfeil: NPRId finnes i tabell_TSB.")
}
if ("NPRId" %in% names(tabell_PHBU)) {
  stop("Personvernfeil: NPRId finnes i tabell_PHBU.")
}
if ("NPRId" %in% names(tabell_AVTPHV)) {
  stop("Personvernfeil: NPRId finnes i tabell_AVTPHV.")
}

if (nrow(tabell_SOM) > 0) {
  if (min(tabell_SOM$Ar, na.rm = TRUE) < START_YEAR |
      max(tabell_SOM$Ar, na.rm = TRUE) > END_YEAR) {
    stop("SOM har år utenfor perioden 2012-2025.")
  }
}

if (nrow(tabell_PHV) > 0) {
  if (min(tabell_PHV$Ar, na.rm = TRUE) < START_YEAR |
      max(tabell_PHV$Ar, na.rm = TRUE) > END_YEAR) {
    stop("PHV har år utenfor perioden 2012-2025.")
  }
}

if (nrow(tabell_TSB) > 0) {
  if (min(tabell_TSB$Ar, na.rm = TRUE) < START_YEAR |
      max(tabell_TSB$Ar, na.rm = TRUE) > END_YEAR) {
    stop("TSB har år utenfor perioden 2012-2025.")
  }
}

if (nrow(tabell_PHBU) > 0) {
  if (min(tabell_PHBU$Ar, na.rm = TRUE) < START_YEAR |
      max(tabell_PHBU$Ar, na.rm = TRUE) > END_YEAR) {
    stop("PHBU har år utenfor perioden 2012-2025.")
  }
}

if (nrow(tabell_AVTPHV) > 0) {
  if (min(tabell_AVTPHV$Ar, na.rm = TRUE) < START_YEAR |
      max(tabell_AVTPHV$Ar, na.rm = TRUE) > END_YEAR) {
    stop("AVTPHV har år utenfor perioden 2012-2025.")
  }
}