=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->output();
$runnable->write_output(); #writes to DB

=head1 DESCRIPTION

Given an compara MethodLinkSpeciesSet identifer, and a reference genomic
slice identifer, fetches the GenomicAlignBlocks from the given compara
database, forms them into sets of alignment chains, and writes the result
back to the database. 

This module (at least for now) relies heavily on Jim Kent\'s Axt tools.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentChains;

use strict;
use Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Analysis::Runnable::AlignmentChains;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

our @ISA = qw(Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing);


############################################################

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Returns :   nothing
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_; 

  $self->SUPER::fetch_input;
  my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

  $self->compara_dba->dbc->disconnect_when_inactive(0);
  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $dafa = $self->compara_dba->get_DnaAlignFeatureAdaptor;
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  $gaba->lazy_loading(0);

  if(defined($self->param('qyDnaFragID'))) {
    my $dnafrag = $self->compara_dba->get_DnaFragAdaptor->fetch_by_dbID($self->param('qyDnaFragID'));
    $self->param('query_dnafrag', $dnafrag);
  }
  if(defined($self->param('tgDnaFragID'))) {
    my $dnafrag = $self->compara_dba->get_DnaFragAdaptor->fetch_by_dbID($self->param('tgDnaFragID'));
    $self->param('target_dnafrag', $dnafrag);
  }

  my $qy_gdb = $self->param('query_dnafrag')->genome_db;
  my $tg_gdb = $self->param('target_dnafrag')->genome_db;


  ################################################################
  # get the compara data: MethodLinkSpeciesSet, reference DnaFrag, 
  # and all GenomicAlignBlocks
  ################################################################
  print "mlss: ",$self->param('input_method_link')," ",$qy_gdb->dbID," ",$tg_gdb->dbID,"\n";

  my $mlss;
  if (defined $self->param('input_mlss_id')) { 
      #new pipeline
      $mlss = $mlssa->fetch_by_dbID($self->param('input_mlss_id'));
  } else {
      #old pipeline
      if ($qy_gdb->dbID == $tg_gdb->dbID) {
	  $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->param('input_method_link'),
							      [$qy_gdb]);
      } else {
	  $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->param('input_method_link'),
							      [$qy_gdb,
							       $tg_gdb]);
      }
  }
  throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->param('input_mlss_id'))
      if not $mlss;

  my $out_mlss;
  if (defined $self->param('output_mlss_id')) {
      $out_mlss = $mlssa->fetch_by_dbID($self->param('output_mlss_id'));
  } else {
      #old pipeline
      if ($qy_gdb->dbID == $tg_gdb->dbID) {
	  $out_mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->param('output_method_link'),
							      [$qy_gdb]);
      } else {
	  $out_mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->param('output_method_link'),
							      [$qy_gdb,
							       $tg_gdb]);
      }
  }
  throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->param('output_mlss_id'))
      if not $out_mlss;

  ######## needed for output####################
  $self->param('output_MethodLinkSpeciesSet', $out_mlss);

  my $query_slice = $self->param('query_dnafrag')->slice;
  my $target_slice = $self->param('target_dnafrag')->slice;

  print STDERR "Fetching all DnaDnaAlignFeatures by query and target...\n";
  print STDERR "start fetching at time: ",scalar(localtime),"\n";

  if ($self->input_job->retry_count > 0) {
    $self->warning("Deleting alignments as it is a rerun");
    $self->delete_alignments($out_mlss,$self->param('query_dnafrag'),$self->param('target_dnafrag'));
  }

  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag($mlss,$self->param('query_dnafrag'),undef,undef,$self->param('target_dnafrag'));
  my $features;
  while (my $gab = shift @{$gabs}) {
    my ($qy_ga) = $gab->reference_genomic_align;
    my ($tg_ga) = @{$gab->get_all_non_reference_genomic_aligns};

    unless (defined $self->param('query_DnaFrag_hash')->{$qy_ga->dnafrag->name}) {
      ######### needed for output ######################################
      $self->param('query_DnaFrag_hash')->{$qy_ga->dnafrag->name} = $qy_ga->dnafrag;
    }
      
    unless (defined $self->param('target_DnaFrag_hash')->{$tg_ga->dnafrag->name}) {
      ######### needed for output #######################################
      $self->param('target_DnaFrag_hash')->{$tg_ga->dnafrag->name} = $tg_ga->dnafrag;
    }
    
    my $daf_cigar = $self->daf_cigar_from_compara_cigars($qy_ga->cigar_line,
                                                         $tg_ga->cigar_line);

    if (defined $daf_cigar) {
      my $daf = Bio::EnsEMBL::DnaDnaAlignFeature->new
        (-seqname => $qy_ga->dnafrag->name,
         -start   => $qy_ga->dnafrag_start,
         -end     => $qy_ga->dnafrag_end,
         -strand  => $qy_ga->dnafrag_strand,
         -hseqname => $tg_ga->dnafrag->name,
         -hstart  => $tg_ga->dnafrag_start,
         -hend    => $tg_ga->dnafrag_end,
         -hstrand => $tg_ga->dnafrag_strand,
         -cigar_string => $daf_cigar);
      push @{$features}, $daf;
    }
  }
  
  print STDERR scalar @{$features}," features at time: ",scalar(localtime),"\n";

  my %parameters = (-analysis             => $fake_analysis,
                    -query_slice          => $query_slice,
                    -target_slices        => {$self->param('target_dnafrag')->name => $target_slice},
                    -query_nib_dir        => undef,
                    -target_nib_dir       => undef,
                    -features             => $features,
                    -workdir              => $self->worker_temp_directory,
		    -linear_gap           => $self->param('linear_gap'));
  
  my $query_nib_dir = $self->param('query_nib_dir');
  if ($self->param('query_nib_dir') and
      -d $query_nib_dir and
      -e $query_nib_dir . "/" . $query_slice->seq_region_name . ".nib") {
    $parameters{-query_nib_dir} = $query_nib_dir;
  }

  my $target_nib_dir = $self->param('target_nib_dir');
  if ($target_nib_dir and
      -d $target_nib_dir and
      -e $target_nib_dir . "/" . $target_slice->seq_region_name . ".nib") {
    $parameters{-target_nib_dir} = $target_nib_dir;
  }

  foreach my $program (qw(faToNib lavToAxt axtChain)) {
    #$parameters{'-' . $program} = $self->BIN_DIR . "/" . $program;
      $parameters{'-' . $program} = $self->param($program);
  }

  my $runnable = Bio::EnsEMBL::Analysis::Runnable::AlignmentChains->new(%parameters);
  #Store runnable in param
  $self->param('runnable', $runnable);

}

sub write_output {
  my $self = shift;

  my $disconnect_when_inactive_default = $self->compara_dba->dbc->disconnect_when_inactive;
  $self->compara_dba->dbc->disconnect_when_inactive(0);
  $self->SUPER::write_output;
  $self->compara_dba->dbc->disconnect_when_inactive($disconnect_when_inactive_default);

}

1;
