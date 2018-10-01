=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a $rows = copy of the License at

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

Bio::EnsEMBL::Compara::RunnableDB::Families::CopyUniprotData

=head1 DESCRIPTION

This module imports all the members (and their sequences and hmm-hits) that are canonical
and on a reference dnafrag for a given genome_db_id.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::CopyUniprotData;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $reuse_dba = $self->get_cached_compara_dba('reuse_db');
    die $self->param('reuse_db').' cannot be found' unless $reuse_dba;
    $self->param('reuse_dba', $reuse_dba);

}

sub run {
  my $self = shift;

  $self->_sql_copy('seq_member', 'SELECT * FROM seq_member where source_name = "Uniprot/SWISSPROT" OR source_name = "Uniprot/SPTREMBL"');
  $self->_sql_copy('sequence', 'SELECT sequence.* FROM seq_member JOIN sequence USING (sequence_id) where seq_member.source_name = "Uniprot/SWISSPROT" OR seq_member.source_name = "Uniprot/SPTREMBL"');

}

sub _sql_copy{
  my ($self, $table, $input_query) = @_;

  my $from_dbc        = $self->param('reuse_dba')->dbc;
  my $to_dbc          = $self->compara_dba->dbc;

  my $rows = copy_data($from_dbc, $to_dbc, $table, $input_query, undef, 'skip_disable_keys', $self->debug);
  $self->warning("Copied over $rows rows of uniprot members from the $table table ");
}


1;
