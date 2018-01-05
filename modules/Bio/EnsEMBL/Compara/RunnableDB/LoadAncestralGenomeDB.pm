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

Bio::EnsEMBL::Compara::RunnableDB::LoadAncestralGenomeDB

=head1 SYNOPSIS

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::LoadAncestralGenomeDB \
        -compara_db mysql://ensadmin:${ENSADMIN_PSW}@compara3/mm14_homo_sapiens_base_age_84 \
        -master_db mysql://ensro@compara1/mm14_ensembl_compara_master \
        -anc_host compara4 -anc_name ancestral_sequences -anc_dbname mp14_epo_17mammals_ancestral_core_80

=head1 DESCRIPTION

This Runnable is a specific version of LoadOneGenomeDB that loads the
one entry of "ancestral_sequences" into 'genome_db' table and passes
on the genome_db_id.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadAncestralGenomeDB;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},

        'anc_name'  => 'ancestral_sequences',
        'anc_user'  => 'ensro',
        'anc_port'  => 3306,
    }
}


sub fetch_input {
    my $self = shift @_;

    $self->param('master_dba', $self->get_cached_compara_dba('master_db') );
    $self->param('genome_db', $self->param('master_dba')->get_GenomeDBAdaptor->fetch_by_name_assembly($self->param_required('anc_name')));
    $self->param('ancestral_locator', sprintf('Bio::EnsEMBL::DBSQL::DBAdaptor/host=%s;port=%s;user=%s;pass=;dbname=%s;species=%s;species_id=1;disconnect_when_inactive=1',
            $self->param_required('anc_host'), $self->param_required('anc_port'), $self->param_required('anc_user'), $self->param_required('anc_dbname'), $self->param_required('anc_name')));
}

sub run {
    my $self = shift @_;

    $self->param('genome_db')->locator($self->param('ancestral_locator'));
}


1;

