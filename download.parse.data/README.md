# Archival stability pipeline

This is an updated version from the repository of Mangul et al.

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

To pull the data for 10 journals, you now have to go through each PMC ID range, using the file `download_files.sh`. This also downloads `oa_file_list.csv` which has a list of the download links of each article. We will run `download_indv_articles.R` to download individual articles and move them to the journal directories to be able to use the link extraction scripts. You will obtain ten folders:

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

But since there are a huge amount of papers, it is better to submit this as a job in the HPC. An example script is `get_links.pbs`. I used array jobs, submitting one job per journal, with the command `wsub -t 1-10 -batch get_links.pbs`. This command will be different in each HPC system. It took around 20 hours to check the links for the journal with the most papers (_Nucleic Acids Research_ with almost 26,000 papers). 

**NOTE:** The scripts have been updated to be compatible with Python 3. I also modified the regex search to allow IDs after the abstract tag, e.g., `<abstract id="1">`. At least one article ran into an error because it had that format. This should not affect the normal `<abstract>` tags.

Running this script for each journal you want to evaluate will put two files in the `download.parse.data/` directory: `abstractLinks_${JOURNAL}.prepared.tsv` and `bodyLinks_${JOURNAL}.prepared.tsv`. Each time you run this script, it will append results to the end of these two files. If you want to restart the analysis for a journal, you should first remove the corresponding tsv files.

You can then combine all the files from all journals `cat abstractLinks_*.tsv >> abstractLinks.prepared.tsv` (and do the same with `bodyLinks`.)

The last step is to run the `clean.sh` script to combine these files into `links.unchecked.csv`. It does not require any parameters to run:

```sh
./clean.sh
```

## Step 3: Run detailed request checks

Improvements to the link screening process required re-processing some of the failed requests to ensure they were actually "failures." This script requires **Python 3** and the Python modules specified in `requirements.txt`; to install all dependencies and run the script, run the following commands from within the `download.parse.data/` directory:

```sh
python -m venv goodsoftware
source goodsoftware/bin/activate
pip install -r requirements.txt

# Run the script. First parameter is source data, second parameter is where output should be directed.
python recheck_timeouts.py links.unchecked.csv links.bulk.csv

deactivate
```

Again, this can really take a while, so I suggesting splitting the links into parts. I divided them using `split`, but you can do it any other way. Example code:
```
split -da 2 -l $((`wc -l < links.unchecked.csv`/24)) links.unchecked.csv part --additional-suffix=".csv"
```

This divides `links.unchecked.csv` into `part00.csv`, `part01.csv` ... `part24.csv`. I moved these into a folder called `links_unchecked_parts/`. part24 only had ten links so I combined it with part23 using `cat part24.csv >> part23.csv; rm part24.csv`
However, only `part00.csv` has the header, and we have to add it to the other parts. We can do the following:
```
header=type,journal,id,year,link,code,flag.uniqueness
for i in {01..23}
do
    echo "$i"
    { echo $header ; cat "part$i.csv"; } > tmp/xx.csv
    mv tmp/xx.csv "part$i.csv"
done
```
So now we can run the check in parts. I submitted `recheck_timeout.pbs` to the HPC in multiple parts (to get a quicker queue): `wsub -t 1-5 -batch recheck_timeout.pbs` ... `wsub -t 21-24 -batch recheck_timeout.pbs` This will store the checked links in the directory `links_checked_parts/`.

TODO: Script to create link.bulks.csv.

## Step 4: Collect additional data for analysis

There are two additional files that need to be generated for the analysis that is performed in the "Figure1" Jupyter notebook.

### Step 4a: Minor redirection information

If a redirection response changes only the protocol of a request (for example, `http://google.com` to `https://google.com`), then we count that as a `200` instead.

If you are working with the parts, this can also be done in the HPC using `redirection.pbs`.

Otherwise, provided you have `links.bulk.csv`, you can run the following command within the `download.parse.data/` directory:

```sh
python redirection.py links.bulk.csv http2https.redirected.csv
```

`http2https.redirected.csv` is used in the Jupyter notebook analysis.

### Step 4b: Altmetric data

The portion of the analysis that incorporates Altmetric data requires that data first be fetched from their API. This uses the same virtual environment as step 3:

```sh
source bin/activate
python fetching_altmetric.py
deactivate
```

## Step 5: Analysis

The final file created in step 3 (`links.bulk.csv`) is in same `links.bulk.csv` source file referred to in the Jupyter notebooks. Using this output as the source for the figures should generate results in the same way we did for our paper.
