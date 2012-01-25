=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

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
use Bio::EnsEMBL::Analysis::Runnable::Lastz;

use Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAligner;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);

our @ISA = qw(Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAligner);


sub configure_defaults {
  my $self = shift;
  
  $self->param('method_link_type', 'LASTZ_RAW') unless defined ($self->param('method_link_type'));
  $self->param('do_transactions', 1) unless defined ($self->param('do_transactions'));

  return 0;
}


sub configure_runnable {
  my $self = shift;

  my (@db_chunk) = @{$self->param('db_DnaFragChunkSet')->get_all_DnaFragChunks};

  #
  # get the sequences and create the runnable
  #
  my $query_DnaFragChunkSet = $self->param('query_DnaFragChunkSet');
  my $qyChunkFile;
  if($query_DnaFragChunkSet->count == 1) {
    my ($qy_chunk) = @{$query_DnaFragChunkSet->get_all_DnaFragChunks};
    $qyChunkFile = $self->dumpChunkToWorkdir($qy_chunk);
  } else {
    $qyChunkFile = $self->dumpChunkSetToWorkdir($query_DnaFragChunkSet);
  }

  my @db_chunk_files;
  #if ($self->db_DnaFragChunkSet->count > 1) {
    #throw("lastz can not use more than 1 sequence in the database/target file.\n" .
    #      "You may have specified a group_set_size in the target_dna_collection.\n" .
    #      "In the case of lastz this should only be used for query_dna_collection");
  #}
  foreach my $db_chunk (@{$self->param('db_DnaFragChunkSet')->get_all_DnaFragChunks}) {
    push @db_chunk_files, $self->dumpChunkToWorkdir($db_chunk);
  }

  if (@db_chunk_files > 1) {
    warning("you have given a chunkset for the database; dumping individual chunks\n" .
            "and creating a runnable for each one");
  }

  my $program = $self->param('pair_aligner_exe');
  throw($program . " is not executable")
    unless ($program && -x $program);

  #Get options from meta table
  my $meta_container = $self->compara_dba->get_MetaContainer;
  my $key = "options_" . $self->param('method_link_species_set')->dbID;
  my @option_list = $meta_container->list_value_by_key($key);

  #Should be one entry in meta table
  my $options = $option_list[0][0];

  #If not in meta table (new pipeline) try param (old pipeline)
  if (!$options) {
      $options = $self->param('options');
  }

  throw("Unable to find options in meta table") unless (defined $options);

  if($self->debug) {
    print("running with analysis '".$self->analysis->logic_name."'\n");
    print("  options : ", $options, "\n");
    print("  program : $program\n");
  }
  
  $self->delete_fasta_dumps_but_these([$qyChunkFile,@db_chunk_files]);
  foreach my $dbChunkFile (@db_chunk_files) {
    my $runnable = Bio::EnsEMBL::Analysis::Runnable::Lastz->
        new(
            -query      => $dbChunkFile,
            -database   => $qyChunkFile,
            -options    => $options,
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
  #                 lastz flipped them in the parameter list from expected
  #
  #
                  
  return 1;
}


1;

