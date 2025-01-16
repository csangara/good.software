library(tidyverse)
pmc_ids <- sprintf("%02d", 0:11)

journals_oi <- c("BMC Genomics", "Genet Res (Camb)", "Genome Med", "Nat Methods",
                 "PLoS Comput Biol", "BMC Bioinformatics", "BMC Syst Biol",
                 "Genome Biol", "Nat Biotechnol", "Nucleic Acids Res")

dir.create("journals")
lapply(journals_oi, function(journal) dir.create(paste0("journals/", journal), showWarnings = FALSE))

oa_types <- c("comm", "noncomm", "other")
for (oa_type in oa_types) {
  # Get list of files
  filelist <- lapply(pmc_ids, function(pmc_id) {
      read.csv(paste0("articles_filelist/oa_", oa_type, "_xml.PMC0", pmc_id,
                      "xxxxxx.baseline.2024-12-18.filelist.csv"))
    }) %>% bind_rows()
  
  # Get journal name by splitting from period
  data <- filelist %>%
    mutate(Journal = sapply(strsplit(Article.Citation, "\\."), function(x) x[1]),
           .after=Article.Citation)
  
  for (journal in journals_oi) {
    data_subset <- data %>% filter(Journal == journal)
    
    # Move all XML files to corresponding journal folder
    data_subset %>%
      filter(Journal == journal) %>%
      pull(Article.File) %>%
      sapply(function(article) {
        file.copy(from=paste0("articles_tarfiles/oa_", oa_type, "_xml.", str_split_i(article, "/", 1),
                       ".baseline.2024-12-18/", article),
                to=paste0("journals/", journal))
        })
    
  }
}