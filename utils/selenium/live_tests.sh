#!/bin/sh
perl run_tests.pl --module FTPtable --url http://www.ensembl.org --host 172.20.10.187 --port 4444 > "test_reports/FTPtable.txt" 2>&1
perl run_tests.pl --module Blast --url http://www.ensembl.org --host 172.20.10.187 --port 4444 --species all > "test_reports/Blast.txt" 2>&1
