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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ImportNets

=head1 DESCRIPTION

Reads a Net file and imports the data into a compara database, saving the results in the 
genomic_align_block and genomic_align tables with a given method_link_species_set_id. Needs the
presence of the corresponding Chain data already in the database.
Download from:
http://hgdownload.cse.ucsc.edu/downloads.html
Choose reference species
Choose Pairwise Alignments
wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/hg19.hg19.net.gz

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ImportNets;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentNets;
use Bio::EnsEMBL::Analysis::Runnable::AlignmentNets;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Utils::Exception qw(throw );

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

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

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $dafa = $self->compara_dba->get_DnaAlignFeatureAdaptor;
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  my $genome_dba = $self->compara_dba->get_GenomeDBAdaptor;

  my $ref_dnafrag;
  if(defined($self->param('dnafrag_id'))) {
      $ref_dnafrag = $self->compara_dba->get_DnaFragAdaptor->fetch_by_dbID($self->param('dnafrag_id'));
  }

  ################################################################
  # get the compara data: MethodLinkSpeciesSet, reference DnaFrag, 
  # and GenomicAlignBlocks
  ################################################################

  #get ref species
  my $ref_gdb = $genome_dba->fetch_by_name_assembly($self->param('ref_species'));

  #get non-ref species. If self alignment, set non-ref species to be the same as ref-species
  my $non_ref_gdb;
  if (!$self->param('non_ref_species')) {
      $self->param('non_ref_species', $self->param('ref_species'));
  }
  $non_ref_gdb = $genome_dba->fetch_by_name_assembly($self->param('non_ref_species'));

  #get method_link_species_set of Chains, defined by input_method_link_type
  my $mlss;
  if ($ref_gdb->dbID == $non_ref_gdb->dbID) {
      #self alignments
      $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->param('input_method_link_type'), [$ref_gdb]);
  } else {
      $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->param('input_method_link_type'), [$ref_gdb, $non_ref_gdb]);

  }

  throw("No MethodLinkSpeciesSet for method_link_type". $self->param('input_method_link_type') . " and species " . $ref_gdb->name . " and " . $non_ref_gdb->name)
      if not $mlss;

  #Check if doing self_alignment where the species_set will contain only one
  #entry
  my $self_alignment = 0;
  if (@{$mlss->species_set->genome_dbs} == 1) {
      $self_alignment = 1;
  }
  
  #get Net method_link_species_set_id.
  my $out_mlss = $mlssa->fetch_by_dbID($self->param('output_mlss_id'));
  
  throw("No MethodLinkSpeciesSet for method_link_species_set_id".$self->param('output_mlss_id'))
      if not $out_mlss;

  ######## needed for output####################
  $self->param('output_MethodLinkSpeciesSet', $out_mlss);
  
  #Check if need to delete alignments. This shouldn't be needed if using transactions
  if ($self->input_job->retry_count > 0) {
    $self->warning("Deleting alignments as it is a rerun");
    $self->delete_alignments($out_mlss,
                             $ref_dnafrag,
                             $self->param('start'),
                             $self->param('end'));
  }

  #Get Chain GenomicAlignBlocks associated with reference dnafrag and start and end
  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss,
							      $ref_dnafrag,
							      $self->param('start'),
							      $self->param('end'));

  ###################################################################
  # get the target slices and bin the GenomicAlignBlocks by group id
  ###################################################################
  my (%features_by_group, %query_lengths, %target_lengths);

  my $self_gabs;

  while (my $gab = shift @{$gabs}) {
    
      #Find reference genomic_align by seeing which has the visible field set (reference has visible=1 for chains)
      my $ga1 = $gab->genomic_align_array->[0];
      my $ga2 = $gab->genomic_align_array->[1];
      my $ref_ga;
      my $non_ref_ga;

      #visible is true on the reference genomic_align
      if ($ga1->visible) {
	  $ref_ga = $ga1;
	  $non_ref_ga = $ga2;
      } else {
	  $ref_ga = $ga2;
	  $non_ref_ga = $ga1;
      }

      #Check the ref_ga dnafrag_id is valid for this job. Since the gabs were fetched using fetch_all_by_MethodLinkSpeciesSet_DnaFrag, the $gab->reference_genomic_align->dnafrag_id needs to be the same as the visible genomic_align_id else this isn't the reference genomic_align and we need to skip it)

      next if ($ref_ga->dnafrag_id != $gab->reference_genomic_align->dnafrag_id);

      #Set the gab reference ga
      $gab->reference_genomic_align($ref_ga);

      if (not exists($self->param('query_DnaFrag_hash')->{$ref_ga->dnafrag->name})) {
	  ######### needed for output ######################################
	  $self->param('query_DnaFrag_hash')->{$ref_ga->dnafrag->name} = $ref_ga->dnafrag;
      }
      if (not exists($self->param('target_DnaFrag_hash')->{$non_ref_ga->dnafrag->name})) {
	  ######### needed for output #######################################
	  $self->param('target_DnaFrag_hash')->{$non_ref_ga->dnafrag->name} = $non_ref_ga->dnafrag;
      }

      my $group_id = $gab->group_id();
      push @{$features_by_group{$group_id}}, $gab;
  }
  
  foreach my $group_id (keys %features_by_group) {
    $features_by_group{$group_id} = [ sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start} @{$features_by_group{$group_id}} ];
  }

  foreach my $nm (keys %{$self->param('query_DnaFrag_hash')}) {
    $query_lengths{$nm} = $self->param('query_DnaFrag_hash')->{$nm}->length;
  }
  foreach my $nm (keys %{$self->param('target_DnaFrag_hash')}) {
    $target_lengths{$nm} = $self->param('target_DnaFrag_hash')->{$nm}->length;
  }

  #Must store chains in array indexed by [group_id-1] so that the AlignmentNets code uses the correct genomic_align_block chain
  my $features_array;
  foreach my $group_id (keys %features_by_group) {
      $features_array->[$group_id-1] = $features_by_group{$group_id};
  }

  if (!defined $features_array) {
      print "No features found for " .  $ref_dnafrag->name . "\n";
      return;
  }

  my %parameters = (-analysis             => $fake_analysis, 
                    -query_lengths        => \%query_lengths,
                    -target_lengths       => \%target_lengths,
                    -chains               => $features_array,
                    -chains_sorted        => 1,
                    -chainNet             => "",
                    -workdir              => $self->worker_temp_directory,
		    -min_chain_score      => $self->param('min_chain_score'));
  
  my $runnable = Bio::EnsEMBL::Analysis::Runnable::AlignmentNets->new(%parameters);

  #Store runnable in param
  $self->param('runnable', $runnable);

  ##################################
  # read the net file
  ##################################
  my $fh;
  open $fh, $self->param('net_file') or throw("Could not open net file '" . $self-param('net_file') . "' for reading\n");
  my $res_chains = $runnable->parse_Net_file($fh);
  close($fh);
  
  $runnable->output($res_chains);
 
}


sub run {
    my $self = shift;
    #print "RUNNING \n";

    if ($self->param('runnable')) {
        my $runnable = $self->param('runnable');
        $self->cleanse_output($runnable->output);
        $self->param('chains', $runnable->output);
    } else {
        #Set to empty if no features found
        $self->param('chains', []);
    }
}


1;

