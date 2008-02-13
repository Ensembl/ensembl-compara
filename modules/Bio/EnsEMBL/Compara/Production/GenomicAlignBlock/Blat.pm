#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Blat

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Analysis::RunnableDB::Blat->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Analysis::Runnable::Blat to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Analysis::DBSQL::Obj is
required for database access.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Blat;

use strict;
use Bio::EnsEMBL::Analysis::Runnable::Blat;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::PairAligner;
our @ISA = qw(Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::PairAligner);


############################################################
sub configure_defaults {
  my $self = shift;
  
  
  # Target type: dna  - DNA sequence
  #              prot - protein sequence
  #              dnax - DNA sequence translated in six frames to protein
  #              The default is dnax

  # Query type: dna  - DNA sequence
  #             rna  - RNA sequence
  #             prot - protein sequence
  #             dnax - DNA sequence translated in six frames to protein
  #             rnax - DNA sequence translated in three frames to protein
  #             The default is dnax

  #-ooc=/tmp/worker.????/5ooc
  #

  $self->options('-minScore=30 -t=dnax -q=dnax -mask=lower -qMask=lower');
  $self->method_link_type('TRANSLATED_BLAT');
  
  return 0;
}


############################################################
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

  #Grouped seq_regions. Fasta files named after the first seq_region in the set
  my $db_chunks = $self->db_DnaFragChunkSet->get_all_DnaFragChunks;

  my $dnafrag = $db_chunks->[0]->dnafrag;

  my $name = $dnafrag->name . "_" . $db_chunks->[0]->seq_start . "_" . $db_chunks->[0]->seq_end;

  my $dbChunkFile = "" . $self->dump_loc . "/" . $name . ".fa";

  my $program = $self->analysis->program_file;
  $program = $self->analysis->program unless ($program);
  $program = 'blat-32' unless($program);

  if($self->debug) {
    print("running with analysis '".$self->analysis->logic_name."'\n");
    print("  options : ", $self->options, "\n");
    print("  program : $program\n");
  }

  $self->delete_fasta_dumps_but_these([$qyChunkFile,$dbChunkFile]);

  #Do not create ooc files for translated blat analyses
  #create 5ooc file by replacing ".fa" with "/ooo5"
  #my $oocFile = $dbChunkFile;
  #$oocFile =~ s/(.fa)/\/5ooc/;

  #my $options = $self->options . " -ooc=$oocFile";
  my $options = $self->options;

  my $runnable = Bio::EnsEMBL::Analysis::Runnable::Blat->
    new(
	-query      => $qyChunkFile,
	-database   => $dbChunkFile,
	-options    => $options,
	-program    => $program,
	-analysis   => $self->analysis,
       );
  
  $self->runnable($runnable);

  return 1;
}

1;

