=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::CompareNonReusedGenomeList

=head1 EXAMPLE

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::CompareNonReusedGenomeList \
        -compara_db $(mysql-ens-compara-prod-8 details url jalvarez_vertebrates_load_members_99) \
        -expected_updates_file <(echo "homo_sapiens"; echo "mus_musculus"; echo "equus_caballus") \
        -current_release 99 -nonreuse_ss_id 10000002

=head1 DESCRIPTION

This RunnableDB compares the list of genomes that are expected to have an
annotation update (provided in a file) to the actual list of genomes that
cannot be reused.

Both lists must match, and the job will fail if there are any differences.
If a difference happens to be fine, the species can be manually okay-ed
by adding a parameter named "ok_${species_name}".

The parameters are:

=over

=item expected_updates_file

Optional. The path to the file that contains the names of all genome_dbs
we expect an update for. If missing, the Runnable will immediately end
(with a success status). This is useful for groups who don't use the
ensembl-metadata service / the PrepareMasterDatabaseForRelease pipeline.
If the parameter is set but the file doesn't exist, the Runnable will fail.

=item current_release

Mandatory. The current release number. Used to filter out the new genomes,
since they are detected as non-reusable by the LoadMembers but are not
listed under "updated_annotations" in the metadata report ("new_genomes"
instead).

=item nonreuse_ss_id

Mandatory. The dbID if the species-set that holds the list of non-reusable
species.

=item do_not_reuse_list

Optional. The list of species that we didn't want to reuse, regardless
of their true reusability status. The RunnableDB will not complain about
those.

=back

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::CompareNonReusedGenomeList;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::IO qw/slurp_to_array/;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift @_;
    return {
        %{ $self->SUPER::param_defaults },

        'expected_updates_file' => undef,
        'do_not_reuse_list'     => [],
    };
}


sub fetch_input {
    my $self = shift @_;

    my $expected_updates_file = $self->param('expected_updates_file');
    unless ($expected_updates_file) {
        $self->complete_early('No annotation file provided. Skipping this step');
    }
    unless (-e $expected_updates_file) {
        $self->die_no_retry("'$expected_updates_file' doesn't exist");
    }
    my %rel_gdbs = map {$_->name => 1} @{ $self->compara_dba->get_GenomeDBAdaptor->fetch_all() };
    my %expected_updated_gdbs = map {$_ => 1} grep {exists $rel_gdbs{$_}} @{ slurp_to_array($expected_updates_file, 'chomp') };

    my $nonreuse_ss_id  = $self->param_required('nonreuse_ss_id');
    my $nonreuse_ss     = $self->compara_dba->get_SpeciesSetAdaptor->fetch_by_dbID($nonreuse_ss_id);
    my %nonreuse_gdbs   = map {$_->name => $_->dbID} @{$nonreuse_ss->genome_dbs};  # map GenomeDB name to dbID, so we can use both later

    my $do_not_reuse_list   = $self->param('do_not_reuse_list');
    my %do_not_reuse_hash   = map {$_ => 1} @$do_not_reuse_list;

    $self->param('nonreuse_gdbs', \%nonreuse_gdbs);
    $self->param('expected_updated_gdbs', \%expected_updated_gdbs);
    $self->param('do_not_reuse_hash', \%do_not_reuse_hash)
}


sub run {
    my $self = shift @_;

    my $nonreuse_gdbs           = $self->param('nonreuse_gdbs');
    my $expected_updated_gdbs   = $self->param('expected_updated_gdbs');
    my $do_not_reuse_hash       = $self->param('do_not_reuse_hash');

    my $error_msg = '';

    # In nonreuse_gdbs, but not in expected_updated_gdbs, not in do_not_reuse_hash,
    # not lacking reusable members in reuse_member_db, and not manually OK'd
    my $reuse_member_adaptor = $self->get_cached_compara_dba('reuse_member_db')->get_GeneMemberAdaptor();
    foreach my $name (keys %$nonreuse_gdbs) {
        next if exists $do_not_reuse_hash->{$name};
        next if exists $expected_updated_gdbs->{$name};
        next if $self->param_exists("ok_$name") && $self->param("ok_$name");
        next if $reuse_member_adaptor->count_all_by_GenomeDB($nonreuse_gdbs->{$name}) == 0;
        $error_msg .= "$name can't be reused but is not listed as having an updated annotation.\n";
    }

    # In expected_updated_gdbs, but not in nonreuse_gdbs
    foreach my $name (keys %$expected_updated_gdbs) {
        next if exists $nonreuse_gdbs->{$name};
        next if $self->param_exists("ok_$name") && $self->param("ok_$name");
        $error_msg .= "$name is listed as having an updated annotation but we detected it can be reused.\n";
    }

    $self->die_no_retry($error_msg) if $error_msg;
}

1;
