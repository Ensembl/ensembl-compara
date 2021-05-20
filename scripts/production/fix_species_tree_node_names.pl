#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use warnings;
use strict;

=head1 NAME

fix_species_tree_node_names.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script can be used when the genome_db table has changed and the
species-tree node names are out of date. It will update the latter.

=head1 SYNOPSIS

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/fix_species_tree_node_names.pl --help

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/fix_species_tree_node_names.pl \
         --compara $(mysql-ens-compara-prod-1 details url ensembl_compara_master)

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the L<--compara> option must be a URL.

=item B<[--compara compara_db_name_or_alias]>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file (in which case you need to pass
the L<--reg_conf> option too).

=item B<[--dry-run]>

When given, the script will not store / update anything in the database.
Default: not set (i.e. the database *will* be updated).

=back

=cut

use Getopt::Long;

use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $help;
my $reg_conf;
my $compara;
my $verbose;
my $dry_run;

GetOptions(
    'help'          => \$help,
    'reg_conf=s'    => \$reg_conf,
    'compara=s'     => \$compara,
    'dryrun|dry_run|dry-run'    => \$dry_run,
);

# Print Help and exit if help is requested
if ($help) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

#################################################
## Get the adaptors from the Registry
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, 'throw_if_missing') if $reg_conf;

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, 'compara');
}
if (!$compara_dba) {
  die "Cannot connect to compara database <$compara>.";
}

my $all_trees = $compara_dba->get_SpeciesTreeAdaptor->fetch_all;

$compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
    foreach my $tree (@$all_trees) {
        foreach my $l (@{$tree->root->get_all_leaves}) {
            my $n = $l->genome_db->get_scientific_name('unique');
            if ($n ne $l->name) {
                if ($dry_run) {
                    printf("Renaming node_id=%d (tree mlss_id=%d/%s) from '%s' to '%s'\n", $l->node_id, $tree->method_link_species_set_id, $tree->label, $l->name, $n);
                } else {
                    $compara_dba->dbc->sql_helper->execute(
                        -SQL => 'UPDATE species_tree_node SET node_name = ? WHERE node_id = ?',
                        -PARAMS => [$n, $l->node_id],
                    );
                }
            }
        }
    }
} );

