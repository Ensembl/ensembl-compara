#! /usr/bin/perl

=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <dev@ensembl.org>.

Questions may also be sent to the Ensembl help desk at
<helpdesk@ensembl.org>.

=head1 DESCRIPTION

This script is used to populate the new "has_karyotype" and "is_high_coverage"
fields of the genome_db table. Most likely, you will need to run this script
only once, on your master
database.
Make sure that you have patched the schema before running the script !

It is advised to first run the script with the "-dry_run 1" option and to
inspect the list of found karyotypes / coverages.

The scripts tries to update all the species that have assembly_default=1

=head1 SYNOPSIS

perl scripts/production/populate_genome_db_has_karyotype_high_coverage.pl -reg_conf PATH_TO_A_REGISTRY_FILE -compara_reg_name INSERT_HERE_YOUR_ALIAS_TO_MASTER [-dry_run 1]

=cut


use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

# Get the command-line arguments

my $reg_conf;
my $reg_name;
my $help;
my $dry_run = 0;

GetOptions(
        'reg_conf=s'            => \$reg_conf,
        'compara_reg_name=s'    => \$reg_name,

        'dry_run=i'             => \$dry_run,

        'h|help'                => \$help,
);

if ($help or (not defined $reg_conf) or (not defined $reg_name)) {
    pod2usage({-exitvalue => 0, -verbose => 2});
}

Bio::EnsEMBL::Registry->load_all($reg_conf);

my $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($reg_name, "compara");

my $sql = 'UPDATE genome_db SET has_karyotype = ?, is_high_coverage = ? WHERE genome_db_id = ?';
my $sth = $compara_dba->dbc->prepare($sql);

my $adaptor = $compara_dba->get_GenomeDBAdaptor;
foreach my $genome_db (@{$adaptor->fetch_all}) {
    next unless $genome_db->assembly_default;
    next unless $genome_db->db_adaptor;

    my $has_karyotype = $genome_db->db_adaptor->has_karyotype;
    next unless defined $has_karyotype;
    printf("has_karyotype=%d for %s/%s\n", $has_karyotype, $genome_db->name, $genome_db->assembly);

    my $is_high_coverage = $genome_db->db_adaptor->is_high_coverage;
    next unless defined $is_high_coverage;
    printf("is_high_coverage=%d for %s/%s\n", $is_high_coverage, $genome_db->name, $genome_db->assembly);

    $sth->execute($has_karyotype, $is_high_coverage, $genome_db->dbID) unless $dry_run;
}


