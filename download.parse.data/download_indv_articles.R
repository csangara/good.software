library(tidyverse)
library(parallel)
setwd("/kyukon/data/gent/vo/000/gvo00070/vsc43831/maintenance_ch")

# Create flag for using through the command line
args <- R.utils::commandArgs(asValues = TRUE, trailingOnly = TRUE)
first_run <- "first_run" %in% names(args)

num_cores <- as.numeric(Sys.getenv("SLURM_NTASKS"))
cat("num_cores:", num_cores, "\n")
pmc_ids <- sprintf("%02d", 0:11)

journals_oi <- c("BMC Genomics", "Genet Res (Camb)", "Genome Med", "Nat Methods",
                 "PLoS Comput Biol", "BMC Bioinformatics", "BMC Syst Biol",
                 "Genome Biol", "Nat Biotechnol", "Nucleic Acids Res") %>%
                 gsub(" ", "_", .)

dir.create("journals")
lapply(journals_oi, function(journal) dir.create(paste0("journals/", journal), showWarnings = FALSE))

oa_types <- c("comm", "noncomm", "other")

oa_file_list <- read.csv("oa_file_list.csv")

filelist <- lapply(oa_types, function(oa_type){
  lapply(pmc_ids, function(pmc_id) {
    read.csv(paste0("articles_filelist/oa_", oa_type, "_xml.PMC0", pmc_id,
                    "xxxxxx.baseline.2024-12-18.filelist.csv"))
  }) %>% bind_rows()
}) %>% bind_rows()

# Get journal name by splitting from period
data <- filelist %>%
  mutate(Journal = sapply(strsplit(Article.Citation, "\\."), function(x) x[1]),
         .after=Article.Citation) %>%
  mutate(Journal = gsub(" ", "_", Journal)) %>%
  # Join data_subset with oa_file_list by PMID
  left_join(oa_file_list %>% select(File, PMID, Accession.ID),
            by=c("AccessionID"="Accession.ID")) %>% 
  # Some newer articles aren't in the file list yet
  filter(!is.na(File), Journal %in% journals_oi)

print(data[which(data$PMID.x != data$PMID.y),] %>% nrow) #705

ftp_server <- "ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/"


if (first_run){
  # Download xml files of all 70297 articles
  mclapply(1:nrow(data), function(i) {
    accessionID <- data$AccessionID[i]
    file <- data$File[i]
    filepath <- paste0("journals/", data$Journal[i], "/", accessionID, ".tar.gz")
    # If file exists, continue
    if (file.exists(filepath)) {
      return(NULL)
    }
    tryCatch(download.file(paste0(ftp_server, file),
                           destfile = filepath), 
             error = function(e) print(paste(file, 'did not download')))
    
    
  }, mc.cores=num_cores)
} else {
  
  for (journal_oi in journals_oi){
    journal_articles <- list.files(paste0("journals/", journal_oi), pattern = ".nxml") %>%
      gsub(".nxml", "", .)
    data_subset <- data %>% filter(Journal == journal_oi,
                                   !AccessionID %in% journal_articles)
    
    cat(length(journal_articles), "files in", journal_oi, "\n")
    cat(sum(journal_articles %in% data$AccessionID), "of these files are in data\n")
    cat(nrow(data_subset), "files missing from data\n")
    
    # remove articles not in data
    articles_to_delete <- journal_articles[!journal_articles %in% data$AccessionID]
    cat("Deleting ", length(articles_to_delete), "files\n")
    for (article in articles_to_delete) {
      file.remove(paste0("journals/", journal_oi, "/", article, ".nxml"))
    }
    
    # Download missing articles
    ftp_server <- "ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/"
    
    mclapply(1:nrow(data_subset), function(i) {
      accessionID <- data_subset$AccessionID[i]
      file <- data_subset$File[i]
      filepath <- paste0("journals/", journal_oi, "/", accessionID, ".tar.gz")
      # If file exists, continue
      if (file.exists(filepath)) {
        return(NULL)
      }
      tryCatch(download.file(paste0(ftp_server, file),
                             destfile = filepath), 
               error = function(e) print(paste(file, 'did not download')))
      
    }, mc.cores=num_cores)
    
    }
    
}

