# rnaSQLite
Tool for storing cuffdiff output into a SQLite database, and matching with known gene functions and families.  Although the tool was designed to take the Panther Sequence Association file, the script or input reference files can be reformated to accept any annotation or database file.  Furthermore the schema used for the SQLite database was designed to be as source-database agnostic as possible, which will hopefully make this tool flexible for use with other sources, such as Kegg or CPDB.

## Prerequisites
The rnaSQLite tool uses the following perl modules:
* DBD-SQLite

on RHEL/Centos systems you can install as follows:
```
yum install perl-DBD-SQLite
```

## Getting Started
