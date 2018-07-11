=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Compara::Production::Analysis::Lastz to add
functionality to read and write to databases.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Production::Analysis::Lastz;

use Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAligner;
use Bio::EnsEMBL::Utils::Exception qw(throw);

our @ISA = qw(Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAligner);


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'method_link_type'  => 'LASTZ_RAW',
    }
}


sub run {
  my $self = shift;

  #
  # get the sequences and create the runnable
  #
  my $query_DnaFragChunkSet = $self->param('query_DnaFragChunkSet');
  my $qyChunkFile = $self->dumpChunkSetToWorkdir($query_DnaFragChunkSet);

  my @db_chunk_files;
  my $db_dna_collection = $self->param('db_DnaFragChunkSet')->dna_collection;
  foreach my $db_chunk (@{$self->param('db_DnaFragChunkSet')->get_all_DnaFragChunks}) {
      $db_chunk->masking($db_dna_collection->masking);
    push @db_chunk_files, $self->dumpChunkToWorkdir($db_chunk, $db_dna_collection);
  }

  if (@db_chunk_files > 1) {
    $self->warning("you have given a chunkset for the database; dumping individual chunks and creating a runnable for each one");
  }

  if($self->debug) {
    print("running with analysis '".$self->input_job->analysis->logic_name."'\n");
  }
  
  $self->compara_dba->dbc->disconnect_if_idle();

  my $starttime = time();
  my @output;
  foreach my $dbChunkFile (@db_chunk_files) {
      my $o = Bio::EnsEMBL::Compara::Production::Analysis::Lastz::run_lastz($self, $qyChunkFile, $dbChunkFile);
      push @output, @$o;
  }

  if($self->debug){printf("%1.3f secs to run %s pairwise\n", (time()-$starttime), $self->param('method_link_type'));}
  $self->param('output', \@output);
}


1;

