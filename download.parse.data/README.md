# Archival stability pipeline

Multiple scripts were combined to collect and evaluate the data in the "archival stability" section of our study.

## Step 0: Download code

These instructions make several assumptions: first, that your analysis is being performed within the repository directories, and second, that the commands are being performed in a Linux-like shell (either Linux, OSX, or a Bash environment in Windows). To begin, download all the code by running:

```sh
git clone https://github.com/csangara/good.software.git
cd good.software/download.parse.data
```

## Step 1: Download data

We used data pulled directly from PubMed Central for this part of the study. The entire open access dataset can be downloaded at **[ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_bulk/](https://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_bulk/)**, which is also accessible via your browser.

Since the publication of Mangul et al., the collections have been [renamed](https://pmc.ncbi.nlm.nih.gov/about/new-in-pmc/#2017-01-19). The new file naming convention is PMCID-based (e.g., PMC4855680.tar.gz) rather than being built from article citation data (i.e., journal abbreviation_pub date_volume_issue_page). For example, running this command would download the data for all journals with PMC ID starting with '000':

```sh
wget ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_bulk/oa_noncomm/xml/oa_noncomm_xml.PMC000xxxxxx.baseline.2024-12-18.tar.gz  
```

To pull the data for 10 journals, you now have to go through each PMC ID range, using the files `download_files.sh` to download the information of the article and `download_files_targz.sh` to download the XML file for each article containing its abstract and body.

Next, run `create_journal_directories.R` with the output of the two shell scripts to create folders with the correct format for each of the ten journals for link extraction. You will obtain ten folders:

```
BMC_Genomics
Genet_Res
Genome_Med
Nat_Methods
PLoS_Comput_Biol
BMC_Bioinformatics
BMC_Syst_Biol
Genome_Biol
Nat_Biotechnol
Nucleic_Acids_Res
```

An example journal directory (compressed) is provided at [download.parse.data/Nat_Methods.tar.gz](https://github.com/smangul1/good.software/blob/master/download.parse.data/). (This can be extracted by running `tar -xf Nat_Methods.tar.gz` from within the `downloads.parse.data/` directory.)

To complete this step, the directories must be under `good.software/download.parse.data` directory. For example, if you only wanted to evaluate articles from _Nature Methods_, your directory structure would look like this:

```
good.software/
    download.parse.data/
        Nat_Methods/
```

## Step 2: Extract links, perform initial checks

Once the journal directories are all organized, navigate to the `good.software/download.parse.data/` directory in your terminal and run the `getLinksStatus.py` script, which takes a single parameter: the name of a single journal. This parameter should match the name of the journal's directory. For example, to process the links for _Nature Methods_:

```sh
python getLinksStatus.py Nat_Methods
```

**NOTE:** The scripts have been updated to be compatible with Python 3.

Running this script for each journal you want to evaluate will put two files in the `download.parse.data/` directory: `abstractLinks.prepared.tsv` and `bodyLinks.prepared.tsv`.

**ANOTHER NOTE:** Each time you run this script, it will append results to the end of these two files. If you want to restart the analysis, you should first remove `abstractLinks.prepared.tsv` and `bodyLinks.prepared.tsv`.

The last step is to run the `clean.sh` script to combine these files into `links.unchecked.csv`. It does not require any parameters to run:

```sh
./clean.sh
```

## Step 3: Run detailed request checks

Improvements to the link screening process required re-processing some of the failed requests to ensure they were actually "failures." This script requires **Python 3** and the Python modules specified in `requirements.txt`; to install all dependencies and run the script, run the following commands from within the `download.parse.data/` directory:

```sh
python -m venv .
source bin/activate
pip install -r requirements.txt

# Run the script. First parameter is source data, second parameter is where output should be directed.
python recheck_timeouts.py links.unchecked.csv links.bulk.csv

deactivate
```

## Step 4: Collect additional data for analysis

There are two additional files that need to be generated for the analysis that is performed in the "Figure1" Jupyter notebook.

### Step 4a: Minor redirection information

If a redirection response changes only the protocol of a request (for example, `http://google.com` to `https://google.com`), then we count that as a `200` instead. Once `links.bulk.csv` is generated, you can generate the file with this redirection information in it by running the following command within the `download.parse.data/` directory:

```sh
python redirection.py
```

This will create a file called `http2https.redirected.csv`, which is used in the Jupyter notebook analysis.

### Step 4b: Altmetric data

The portion of the analysis that incorporates Altmetric data requires that data first be fetched from their API. This uses the same virtual environment as step 3:

```sh
source bin/activate
python fetching_altmetric.py
deactivate
```

## Step 5: Analysis

The final file created in step 3 (`links.bulk.csv`) is in same `links.bulk.csv` source file referred to in the Jupyter notebooks. Using this output as the source for the figures should generate results in the same way we did for our paper.
