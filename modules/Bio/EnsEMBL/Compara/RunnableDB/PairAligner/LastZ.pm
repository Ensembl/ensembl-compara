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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Analysis::Runnable::Lastz to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. 
required for databse access.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::LastZ;

use strict;
use warnings;
use Bio::EnsEMBL::Analysis::Runnable::Lastz;
use Bio::EnsEMBL::Analysis;

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


sub configure_runnable {
  my $self = shift;

  my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

  #
  # get the sequences and create the runnable
  #
  my $query_DnaFragChunkSet = $self->param('query_DnaFragChunkSet');
  my $qyChunkFile = $self->dumpChunkSetToWorkdir($query_DnaFragChunkSet);

  my @db_chunk_files;
  my $db_dna_collection = $self->param('db_DnaFragChunkSet')->dna_collection;
  foreach my $db_chunk (@{$self->param('db_DnaFragChunkSet')->get_all_DnaFragChunks}) {
      $db_chunk->masking_options($db_dna_collection->masking_options);
    push @db_chunk_files, $self->dumpChunkToWorkdir($db_chunk, $db_dna_collection);
  }

  if (@db_chunk_files > 1) {
    $self->warning("you have given a chunkset for the database; dumping individual chunks and creating a runnable for each one");
  }

  my $program = $self->require_executable('pair_aligner_exe');
  my $mlss = $self->param('method_link_species_set');
  my $options = $mlss->get_value_for_tag("param");

  #If not in method_link_species_set_tag table (new pipeline) try param (old pipeline)
  if (!$options) {
      $options = $self->param('options');
  }

  throw("Unable to find options in method_link_species_set_tag table or in $self->param('options') ") unless (defined $options);

  if($self->debug) {
    print("running with analysis '".$self->input_job->analysis->logic_name."'\n");
    print("  options : ", $options, "\n");
    print("  program : $program\n");
  }
  
  $self->delete_fasta_dumps_but_these([$qyChunkFile,@db_chunk_files]);

  $self->param('runnable', []);

  foreach my $dbChunkFile (@db_chunk_files) {
    my $runnable = Bio::EnsEMBL::Analysis::Runnable::Lastz->
        new(
            -query      => $dbChunkFile,
            -database   => $qyChunkFile,
            -options    => $options,
            -program    => $program,
            -analysis   => $fake_analysis,
            );
    
    if($self->debug >1) {
      my ($fid) = $dbChunkFile =~ /([^\/]+)$/;
      $runnable->resultsfile($self->worker_temp_directory . "/results.$fid.");
      $runnable->results_to_file(1);  # switch on whether to use pipe or /tmp file
    }

    push @{$self->param('runnable')}, $runnable;
  }

  #
  #
  # BIG WARNING!!!! I FLIPPED THE DB and Query above because it looks like
  #                 lastz flipped them in the parameter list from expected
  #
  #
                  
  return 1;
}


1;

