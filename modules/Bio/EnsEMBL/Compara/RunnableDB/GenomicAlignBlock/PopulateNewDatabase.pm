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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::PopulateNewDatabase

=cut

=head1 DESCRIPTION

Runs the $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/populate_new_database.pl script, dealing with missing parameters

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::PopulateNewDatabase;

use strict;
use warnings;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Hive::Utils ('destringify');

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');


sub fetch_input {
    my $self = shift;

    my @cmd;
    push @cmd, $self->param_required('program');
    push @cmd, '--master', $self->param_required('master_db');
    push @cmd, '--new', $self->param('pipeline_db') if $self->param('pipeline_db');
    push @cmd, '--cellular_component', $self->param('cellular_component') if $self->param('cellular_component');
    push @cmd, '--species', $self->param('speciesList') if $self->param('speciesList');
    push @cmd, '--reg-conf', $self->param('reg_conf') if $self->param('reg_conf');
    push @cmd, '--collection', $self->param('collection') if ( $self->param('collection') && !$self->param('ignore_collection') );
    push @cmd, '--old', $self->param('old_compara_db') if $self->param('old_compara_db');
    push @cmd, '--alignments_only' if $self->param('alignments_only');

    # allow for a single mlss_id or multiples as populate_new_database.pl can accept multiple mlsses in the same cmd
    push @cmd, '--mlss', $self->param('mlss_id') if $self->param('mlss_id');
    if ( $self->param('mlss_id_list') ){
        push @cmd, '--mlss', $_ for @{ destringify($self->param('mlss_id_list')) };
    }

    $self->param('cmd', \@cmd);
}


1;
