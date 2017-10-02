# rnaSQLite
Tool for storing cuffdiff output into a SQLite database, and matching with known gene functions and families.  Although the tool was designed to take the Panther Sequence Association file, the script or input reference files can be reformated to accept any annotation or database file.  Furthermore the schema used for the SQLite database was designed to be as source-database agnostic as possible, which will hopefully make this tool flexible for use with other sources, such as Kegg or CPDB.

## Prerequisites
The rnaSQLite tool uses the following perl modules:
* DBD-SQLite

on RHEL/Centos systems you can install as follows:
```bash
yum install perl-DBD-SQLite
```

## Getting Started (the basics)
1. Download the repo and unzip.
```bash
unzip master.zip
```

If your system does not have `unzip` you will need to install.  RHEL/Centos `yum install unzip`.

2. The first step, after downloading, is to setup the database and store reference codes used throughout the program.
```bash
./init_db.pl my_rnaseq_data.db
```
Change `my_rnaseq_data.db` to whatever name that is more descriptive to your project or analysis you are going to do.

3. Initialize the reference/annotation database.  This can be for either mouse or human (more species to come).

Download the Seuqence Association file from PANTHER (ftp://ftp.pantherdb.org/pathway/current_release/SequenceAssociationPathway3.5.txt).

Before use, please read their README (ftp://ftp.pantherdb.org/pathway/current_release/README) and LICENSE (ftp://ftp.pantherdb.org/pathway/current_release/LICENSE)

### For Mouse
Download the mouse gene list file from JAX (http://www.informatics.jax.org/downloads/reports/MRK_List2.rpt) and run the following program
```bash
./init_mouse_ref.pl my_rnaseq_data.db SequenceAssociationPathway3.5.txt MRK_List2.rpt
```

### For Human
Download the human gene list from HGNC (ftp://ftp.ebi.ac.uk/pub/databases/genenames/new/tsv/locus_groups/protein-coding_gene.txt) and run the following program
```bash
./init_human_ref.pl my_rnaseq_data.db SequenceAssociationPathway3.5.txt protein-coding_gene.txt
```

4. Take the cuffdiff diff_out file and store in SQLite database. Use the appropriate sepcies short name.  HUMAN = Homo sapien, MOUSE = Mus musculus.

**_It may be worth copying the SQLite database file at this point as a backup._**  It is easier to come back to this step than to redo the whole initialisation process.
```bash
./cuffdiff2SQLite.pl my_rnaseq_data.db /path/to/cuff/diff/output HUMAN
```
This step may take a while depending on how large the diffout file is.

5. Generate a report with the pathways/functions and genes.  By default the program will use a 0.05 p-value cutoff and 5 FPKM cutoff.  You can change this by using the `-p` and `-r` flags respectively.
```bash
./report_pathways.pl my_rnaseq_data.db HEALTHY TREATMENT /path/to/output.txt
```

For a p-value of less than 0.01 and FPKM cutoff of 10:
```bash
./report_pathways.pl my_rnaseq_data.db HEALTHY TREATMENT /path/to/output.txt -p 0.01 -r 10
```

## Cytoscape and CPDB Induced Network Modules
In this section we will use the gene list that you obtained from `report_pathways.pl` to obtain a network list from CPDB's induced network module.  CPDB, or ConsensusPathDB, is a network analysis tool that integrates many different pathway databases into one.  At the time of writing, CPDB supports human, yeast and mouse pathways (http://cpdb.molgen.mpg.de/).  Once a network list is obtained, we will use this tool to merge the network list with gene expression data, which we will then import into cytoscape for visualisation.  Download Cytoscape from http://www.cytoscape.org/.

1. When using CPDB, the first thing is to select your species at the top of the website (http://cpdb.molgen.mpg.de/).  Then access the induced network modules by clicking on "gene set analysis" in the menu on the right.  You will see "induced network modules" show up.  Click it and you will be presented with a text field to past a list of genes.

2. Open the output file from `report_pathways.pl` in a spreadsheet software to copy the list of gene symbols, or just extract the first colum from the text file using `awk` or similar methods.  Duplicate gene symbols may appear, as a single gene can be part of one or more pathways.  If you would like, you can remove duplicates, although they will not affect the induced network modules.

3. Paste the list of genes into the text box on CPDB's induced network modules page and click "Proceed".

4. Once the page loads you will see a visualisation of the network.  To download the network list as a text file, click on "export" at the top of the page.

5. Use `cpdb2cytoscape.pl` to merge expression data which can then be visualised as colour changes in cytoscape.
```bash
./cpdb2cytoscape.pl my_rnaseq_data.db HEALTHY TREATMENT /path/to/CPDB_inducedModules /path/to/output.txt
```
You will then be able to import the resulting text file in to a new session in Cytoscape for visualisation.

## Database Schema
The following is the table schemas and other details.

### diff_table
|Column Name|Type   |Remarks                           |
|-----------|-------|----------------------------------|
|id         |INTEGER|PRIMARY KEY AUTOINCREMENT NOT NULL|
|sample_id_1|INTEGER|NOT NULL                          |
|sample_id_2|INTEGER|NOT NULL                          |
|diff_status|CHAR(8)|NOT NULL                          |
|log2FC     |REAL   |NOT NULL                          |
|test_stat  |REAL   |NOT NULL                          |
|p_value    |REAL   |NOT NULL                          |
|q_value    |REAL   |NOT NULL                          |

**Code:**
```perl
$stmt = qq(CREATE TABLE IF NOT EXISTS diff_table(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        sample_id_1 INTEGER NOT NULL,
        sample_id_2 INTEGER NOT NULL,
        diff_status CHAR(8) NOT NULL,
        log2FC REAL NOT NULL,
        test_stat REAL NOT NULL,
        p_value REAL NOT NULL,
        q_value REAL NOT NULL););
```

### reference_table
|Column Name           |Type    |Remarks                           |
|----------------------|--------|----------------------------------|
|id                    |INTEGER |PRIMARY KEY AUTOINCREMENT NOT NULL|
|accession_id          |CHAR(16)|NOT NULL                          |
|gene_symbol           |CHAR(16)|NOT NULL                          |
|gene_name             |CHAR(64)|NOT NULL                          |
|chromosome            |CHAR(2) |NOT NULL                          |
|species               |INTEGER |NOT NULL                          |
|pathway_accession     |CHAR(16)|NOT NULL                          |
|pathway_name          |TEXT    |NOT NULL                          |
|evidence_id           |CHAR(16)|NOT NULL                          |
|evidence_type         |CHAR(16)|NOT NULL                          |
|panther_subfamily_id  |CHAR(16)|                                  |
|panther_subfamily_name|TEXT    |                                  |

**Code:**
```perl
$stmt = qq(CREATE TABLE IF NOT EXISTS reference_table(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        accession_id CHAR(16) NOT NULL,
        gene_symbol CHAR(16) NOT NULL,
        gene_name CHAR(64) NOT NULL,
        chromosome char(2) NOT NULL,
        species INTEGER NOT NULL,
        pathway_accession CHAR(16) NOT NULL,
        pathway_name TEXT NOT NULL,
        evidence_id CHAR(16) NOT NULL,
        evidence_type CHAR(16) NOT NULL,
        panther_subfamily_id CHAR(16),
        panther_subfamily_name TEXT););
```

### sample_table
|Column Name |Type    |Remarks                           |
|------------|--------|----------------------------------|
|id          |INTEGER |PRIMARY KEY AUTOINCREMENT NOT NULL|
|sample_name |TEXT    |NOT NULL                          |
|species     |INTEGER |NOT NULL                          |
|gene_symbol |CHAR(16)|NOT NULL                          |
|accession_id|CHAR(16)|NOT NULL                          |
|reads       |INTEGER |NOT NULL                          |

**Code:**
```perl
$stmt = qq(CREATE TABLE IF NOT EXISTS sample_table(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        sample_name TEXT NOT NULL,
        species INTEGER NOT NULL,
        gene_symbol CHAR(16) NOT NULL,
        accession_id CHAR(16) NOT NULL,
        reads INTEGER NOT NULL););

```

### species_table
|Column Name|Type   |Remarks                           |
|-----------|-------|----------------------------------|
|id         |INTEGER|PRIMARY KEY AUTOINCREMENT NOT NULL|
|short_name |CHAR(8)|NOT NULL                          |
|organism   |TEXT   |NOT NULL                          |
|common_name|TEXT   |NOT NULL                          |

**Code:**
```perl
my $stmt = qq(CREATE TABLE IF NOT EXISTS species_table(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        short_name CHAR(8) NOT NULL,
        organism TEXT NOT NULL,
        common_name TEXT NOT NULL););

```

