# rnaSQLite
Tool for storing cuffdiff output into a SQLite database, and matching with known gene functions and families.  Although the tool was designed to take the Panther Sequence Association file, the script or input reference files can be reformated to accept any annotation or database file.  Furthermore the schema used for the SQLite database was designed to be as source-database agnostic as possible, which will hopefully make this tool flexible for use with other sources, such as Kegg or CPDB.

## Prerequisites
The rnaSQLite tool uses the following perl modules:
* DBD-SQLite

on RHEL/Centos systems you can install as follows:
```bash
yum install perl-DBD-SQLite
```

## Getting Started
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

4. Take the cuffdiff diff_out file and store in SQLite database. Use the appropriate sepcies short name.  HUMAN = homo sapien, MOUSE = Mus musculus
**_ It may be worth copying the SQLite database file at this point as a backup._**  It is easier to come back to this step than to redo the whole initialisation process.
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

