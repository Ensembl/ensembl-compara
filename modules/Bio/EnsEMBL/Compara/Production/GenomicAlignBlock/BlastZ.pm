#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastZ

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Analysis::RunnableDB::BlastZ->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Analysis::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Pipeline::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::BlastZ;

use strict;
use Bio::EnsEMBL::Analysis::Runnable::Blastz;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::PairAligner;
our @ISA = qw(Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::PairAligner);


sub configure_defaults {
  my $self = shift;
  
  $self->options('T=2 H=2200');
  $self->method_link_type('BLASTZ_RAW');

  #Although this seems a good idea in principle, it takes longer and longer to
  #check as the genomic_align_block table gets longer.
  #$self->max_alignments('5000000');
  $self->max_alignments('0');
  
  return 0;
}


sub configure_runnable {
  my $self = shift;

  my (@db_chunk) = @{$self->db_DnaFragChunkSet->get_all_DnaFragChunks};

  #
  # get the sequences and create the runnable
  #
  my $qyChunkFile;
  if($self->query_DnaFragChunkSet->count == 1) {
    my ($qy_chunk) = @{$self->query_DnaFragChunkSet->get_all_DnaFragChunks};
    $qyChunkFile = $self->dumpChunkToWorkdir($qy_chunk);
  } else {
    $qyChunkFile = $self->dumpChunkSetToWorkdir($self->query_DnaFragChunkSet);
  }

  my @db_chunk_files;
  #if ($self->db_DnaFragChunkSet->count > 1) {
    #throw("blastz can not use more than 1 sequence in the database/target file.\n" .
    #      "You may have specified a group_set_size in the target_dna_collection.\n" .
    #      "In the case of blastz this should only be used for query_dna_collection");
  #}
  foreach my $db_chunk (@{$self->db_DnaFragChunkSet->get_all_DnaFragChunks}) {
    push @db_chunk_files, $self->dumpChunkToWorkdir($db_chunk);
  }

  if (@db_chunk_files > 1) {
    warning("you have given a chunkset for the database; dumping individual chunks\n" .
            "and creating a runnable for each one");
  }

  my $program = $self->analysis->program_file;
  $program = 'blastz' unless($program);

  if($self->debug) {
    print("running with analysis '".$self->analysis->logic_name."'\n");
    print("  options : ", $self->options, "\n");
    print("  program : $program\n");
  }
  
  $self->delete_fasta_dumps_but_these([$qyChunkFile,@db_chunk_files]);
 
  foreach my $dbChunkFile (@db_chunk_files) {
    my $runnable = Bio::EnsEMBL::Analysis::Runnable::Blastz->
        new(
            -query      => $dbChunkFile,
            -database   => $qyChunkFile,
            -options    => $self->options,
            -program    => $program,
            -analysis   => $self->analysis,
            );
    
    if($self->debug >1) {
      my ($fid) = $dbChunkFile =~ /([^\/]+)$/;
      $runnable->resultsfile($self->worker_temp_directory . "/results.$fid.");
      $runnable->results_to_file(1);  # switch on whether to use pipe or /tmp file
    }

    $self->runnable($runnable);
  }

  #
  #
  # BIG WARNING!!!! I FLIPPED THE DB and Query above because it looks like
  #                 blastz flipped them in the parameter list from expected
  #
  #
                  
  return 1;
}


1;

