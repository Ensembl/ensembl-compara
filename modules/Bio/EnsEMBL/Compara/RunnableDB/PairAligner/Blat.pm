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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::Blat

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Analysis::RunnableDB::Blat->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
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

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::Blat;

use strict;
use warnings;
use Bio::EnsEMBL::Analysis::Runnable::Blat;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAligner;
our @ISA = qw(Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAligner);


############################################################
sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
  
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

        'method_link_type'  => 'TRANSLATED_BLAT_RAW',
    }
}


############################################################
sub configure_runnable {
  my $self = shift;

  my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

  #
  # get the sequences and create the runnable
  #
  my $qyChunkFile;
  if($self->param('query_DnaFragChunkSet')->count == 1) {
      my ($qy_chunk) = @{$self->param('query_DnaFragChunkSet')->get_all_DnaFragChunks};
      $qyChunkFile = $self->dumpChunkToWorkdir($qy_chunk, $self->param('query_DnaFragChunkSet')->dna_collection);
  } else {
      $qyChunkFile = $self->dumpChunkSetToWorkdir($self->param('query_DnaFragChunkSet'));
  }

  my $dbChunkFile = $self->dumpChunkSetToWorkdir($self->param('db_DnaFragChunkSet'));

  my $program = $self->require_executable('pair_aligner_exe');

  $self->delete_fasta_dumps_but_these([$qyChunkFile,$dbChunkFile]);

  #Do not create ooc files for translated blat analyses
  #create 5ooc file by replacing ".fa" with "/ooo5"
  #my $oocFile = $dbChunkFile;
  #$oocFile =~ s/(.fa)/\/5ooc/;

  #my $options = $self->options . " -ooc=$oocFile";

  my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('mlss_id'));
  my $options = $mlss->get_value_for_tag("param");

  #If not in method_link_species_set_tag table (new pipeline) try param (old pipeline)
  if (!$options) {
      my $option_str = "options_" . $self->param('mlss_id');
      $options = $self->param($option_str);
  }

  #Check options have been set.
  throw("Unable to find options in method_link_species_set_tag table or in $self->param('options') ") unless (defined $options);

  if($self->debug) {
    print("running with analysis '".$self->input_job->analysis->logic_name."'\n");
    print("  options : ", $options, "\n");
    print("  program : $program\n");
  }

  $self->param('runnable', []);
  my $runnable = Bio::EnsEMBL::Analysis::Runnable::Blat->
    new(
	-query      => $qyChunkFile,
	-database   => $dbChunkFile,
	-options    => $options,
	-program    => $program,
	-analysis   => $fake_analysis,
       );
  push @{$self->param('runnable')}, $runnable;

  return 1;
}

1;

