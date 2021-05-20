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


use strict;
use warnings;

=head1 NAME

mark_mlss_ids_as_rerun.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script's main purpose is to mark mlss_ids as being rerun in
a certain release.

This is necessary because the default mechanism assumes that the
data are computed on the date of "first_release" and copied over
until "last_release". However, in some cases we want to rerun the
pipeline (e.g. EPO alignment with new anchors).

The script will add a mlss_tag to this mlss_id and to all the
other mlss_ids that depend on it (e.g. EPO -> EPO2X).

=head1 SYNOPSIS

  perl mark_mlss_ids_as_rerun.pl --help
    [--reg_conf registry_configuration_file]
    --compara compara_db_name_or_alias
    --mlss_id 1234

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 DATABASES

=over

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either the original name or any
of the aliases given in the registry_configuration_file

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. Needed if you refer to the
compara database by an alias.

=back

=head2 OPTIONS

=over

=item B<--mlss_id mlss_id>

The mlss_id of the data we are recomputing

=back

=head2 EXAMPLES

    # In e96
    $ perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/mark_mlss_ids_as_rerun.pl --reg_conf $ENSEMBL_ROOT_DIR/ensembl-compara/conf/${COMPARA_DIV}/production_reg_conf.pl --compara compara_curr --mlss_id 1497

=cut


use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::ApiVersion;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


my $help;
my $reg_conf;
my $compara;
my $mlss_id;

GetOptions(
    'help'          => \$help,
    'reg_conf=s'    => \$reg_conf,
    'compara=s'     => \$compara,
    'mlss_id=i'     => \$mlss_id,
);
# Print Help and exit if help is requested
if ($help or !$compara or !$mlss_id) {
    pod2usage({-exitvalue => 0, -verbose => 2});
}

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-URL => $compara);
} else {
    Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, 'throw_if_missing');
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, 'compara');
}
throw ("Cannot connect to database [$compara]") if (!$compara_dba);

my $rerun_tag = 'rerun_in_'.software_version();

my $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);

my @mlss_todo = ($mlss);

while ($mlss = shift @mlss_todo) {
    die $mlss->toString . " is retired\n" unless $mlss->is_current;
    print "Adding tag '$rerun_tag' to ".($mlss->toString)."\n";
    $mlss->store_tag($rerun_tag, '1');

    # LasZ/TBlat -> Synteny
    if ($mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment') {
        my $synt_mlsss = $mlss->get_all_sister_mlss_by_class('SyntenyRegion.synteny');
        push @mlss_todo, @$synt_mlsss;

    # EPO -> EPO2X
    } elsif ($mlss->method->type eq 'EPO') {
        my @epo2x_mlsss = grep {$_->is_current}
                          grep {$_->species_set->name eq $mlss->species_set->name}
                          @{$mlss->adaptor->fetch_all_by_method_link_type('EPO_EXTENDED')};
        push @mlss_todo, @epo2x_mlsss;

    # (MSA) -> GERP_CS/GERP_CE
    } elsif ($mlss->method->class =~ /^GenomicAlign/) {
        my $sister_mlsss = $mlss->adaptor->fetch_all_by_species_set_id($mlss->species_set->dbID);
        my @cs_mlsss = grep {$_->method->class =~ /(ConservationScore.conservation_score|ConstrainedElement.constrained_element)/} @$sister_mlsss;
        push @mlss_todo, @cs_mlsss;
    }
}

