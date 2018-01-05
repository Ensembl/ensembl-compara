=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Synteny::FetchSyntenyParametersOrthologs

=head1 DESCRIPTION

Given the URL of a database that contains a set of orthologs, dataflows a job
with parameters that define the Synteny analysis to be run.

If the given database contains several ortholog mlss's , and if no input
mlss_id is given, the runnable will dataflow parameters for each of the ortholog mlss's.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::FetchSyntenyParametersOrthologs;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


########## Hive::Process interface ##########

sub param_defaults {
    return {
        # When to create jobs
        recompute_failed_syntenies      => 0,   # boolean
        recompute_existing_syntenies    => 1,   # boolean
        create_missing_synteny_mlsss    => 1,   # boolean

        # By default, we'll test all the orthologs found in the db
        ortholog_mlss_id                => undef,
        # MLSS parameters
        synteny_method_link_type        => 'SYNTENY',
        synteny_source                  => 'ensembl',
    }
}


sub fetch_input {
    my $self = shift;

    if ((not $self->param_required('recompute_existing_syntenies')) and (not $self->param_required('create_missing_synteny_mlsss'))) {
        die "At least one of 'recompute_existing_syntenies' / 'create_missing_synteny_mlsss' must be set.\n"
    }

    if ($self->param("registry")) {
        $self->load_registry($self->param("registry"));
    }

    $self->param('master_dba', $self->get_cached_compara_dba('master_db'));
    $self->param('ptree_dba',  $self->get_cached_compara_dba('ptree_db'));

    $self->param('mlsss_ok', []);
}

sub run {
    my $self= shift;

    if ($self->param('ortholog_mlss_id')) {
        my $mlss = $self->param('ptree_dba')->get_MethodLinkSpeciesSetAdaptor()->fetch_by_dbID($self->param('ortholog_mlss_id'));
        die sprintf("MLSS %d could not be found in %s\n", $self->param('ortholog_mlss_id'), $self->param('ptree_db')) unless $mlss;
        $self->_check_ortholog($mlss);
    } else {
        foreach my $ml (@{$self->param_required('ortholog_method_link_types')}) {
            foreach my $mlss (@{$self->param('ptree_dba')->get_MethodLinkSpeciesSetAdaptor()->fetch_all_by_method_link_type($ml)}) {
                $self->_check_ortholog($mlss);
            }
        }
    }
}

sub write_output {
    my ($self) = @_;

    # each doubl is: [$ortholog_mlss, $synt_mlss]
    foreach my $doubl (@{$self->param('mlsss_ok')}) {
        my $genome_db_ids = join(',', map {$_->dbID} @{$doubl->[0]->species_set->genome_dbs});
        $self->dataflow_output_id( {
            ortholog_mlss_id    => $doubl->[0]->dbID,
            synteny_mlss_id     => $doubl->[1]->dbID,
            ref_species         => $doubl->[0]->species_set->genome_dbs->[0]->name(),
            pseudo_non_ref_species     => $doubl->[0]->species_set->genome_dbs->[1]->name(),
            genome_db_ids       => $genome_db_ids,
        }, 2);
    }
}

########## Private methods ##########

sub _check_ortholog {
    my ($self, $mlss) = @_;

    # Check consistency with master for the ortholog MLSS
    my $master_mlss = $self->param('master_dba')->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss->dbID);
    if (($master_mlss->name ne $mlss->name) or ($master_mlss->method->type ne $mlss->method->type) or ($master_mlss->species_set->dbID != $mlss->species_set->dbID)) {
        die sprintf("Mismatch between master database (%s) and ptree database (%s) for MLSS object dbID=%d\n", $self->param('master_db'), $self->param('ptree_db'), $mlss->dbID);
    }

    # Have we tried (and failed) before ?
    if ($mlss->has_tag('low_synteny_coverage')) {
        $self->warning(sprintf("The ortholog mlss_id=%d has already been tried but lead to a low synteny-coverage (%s)", $mlss->dbID, $mlss->get_value_for_tag('low_synteny_coverage')));
        return unless $self->param('recompute_failed_syntenies');
    }

    # Do the species have karyotypes ?
    my $genome_dbs = $master_mlss->species_set->genome_dbs;
    if (grep {not $_->has_karyotype} @$genome_dbs) {
        if (not $self->param('include_non_karyotype')) {
            $self->warning(sprintf("Discarding '%s' because some species don't have a karyotype", $mlss->name));
            return;
        }
    }

        # synteny MLSS
    my $synt_method = $self->param('master_dba')->get_MethodAdaptor->fetch_by_type($self->param_required('synteny_method_link_type'))
        or die sprintf("Could not find the method '%s' in the master database (%s)\n", $self->param('synteny_method_link_type'), $self->param('master_db'));
    my $master_synt_mlss = $self->param('master_dba')->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_id_species_set_id($synt_method->dbID, $mlss->species_set->dbID);

    # Create a new one in the master database if needed
    if (not $master_synt_mlss) {
        die "Could not find the $synt_method MLSS in the master database that matches the ortholog \n" unless $self->param('create_missing_synteny_mlsss');
        my $synt_name = $mlss->name;
        $synt_name =~ s/ .*/ synteny/;
        $master_synt_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
            -METHOD             => $synt_method,
            -SPECIES_SET        => $mlss->species_set,
            -NAME               => $synt_name,
            -SOURCE             => $self->param_required('synteny_source'),
        );
        $self->elevate_privileges($self->param('master_dba')->dbc);
        $self->param('master_dba')->get_MethodLinkSpeciesSetAdaptor->store($master_synt_mlss, 0);
        # It has to be stored also in the current database
        $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->store($master_synt_mlss);
    } elsif (not $self->param('recompute_existing_syntenies')) {
        $self->warning(sprintf("Discarding '%s' because its MLSS already exists in the master database", $mlss->name));
        return;
    }
    # It should be in the current database
    my $synt_mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_id_species_set_id($synt_method->dbID, $mlss->species_set->dbID)
        or die "Error: the method_link_species_set table hasn't been imported from master yet\n";

    push @{$self->param('mlsss_ok')}, [$mlss, $synt_mlss ];
}

1;
