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

package Bio::EnsEMBL::Compara::Graph::GenomicAlignTreePhyloXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::GenomicAlignTreePhyloXMLWriter


=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use base qw /Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter/;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array);

=pod

=head2 new()

  Arg[ALIGNED]          : Boolean; indicates if we want to emit aligned
                          sequence. Defaults to B<false>.
  Arg[COMPACT_ALIGNMENTS]: Boolean; if set to true the fragmented alignments
                           of the low coveage species will be concatenated.
                           Defaults to B<true>.
  Arg[NO_SEQUENCES]     : Boolean; indicates we want to ignore sequence
                          dumping. Defaults to B<false>.

  Description : Creates a new tree writer object.
  Returntype  : Instance of the writer
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::Graph::GenomicAlignTreePhyloXMLWriter->new(
                  -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $handle
                );
  Status      : Stable

=cut

sub new {
  my ($class, @args) = @_;
  $class = ref($class) || $class;
  my $self = $class->SUPER::new(@args);
  
  my ($aligned, $compact_alignments, $no_sequences) = 
    rearrange([qw(aligned compact_alignments no_sequences)], @args);

  if(($compact_alignments || $aligned) && $no_sequences) {
    warning "-COMPACT_ALIGNMENTS or -ALIGNED was specified but so was -NO_SEQUENCES. Will ignore sequences";
  }

  $self->aligned($aligned);
  $self->no_sequences($no_sequences);
  $self->compact_alignments($compact_alignments);

  return $self;
}

=pod

=head2 compact_alignments()

  Arg [0] : Boolean; indiciates we wish to comapct the alignments of fragmented regions of low coverage species
  Returntype : Boolean  Exceptions : None
  Status     : Stable

=cut

sub compact_alignments {
  my ($self, $compact_alignments) = @_;
  $self->{compact_alignments} = $compact_alignments if defined $compact_alignments;
  return $self->{compact_alignments};
}

=pod


=pod

=head2 no_sequences()

  Arg[0] : The value to set this to
  Description : Indicates if we do not want to perform sequence dumping
  Returntype  : Boolean
  Exceptions  : None
  Status      : Stable

=cut

sub no_sequences {
  my ($self, $no_sequences) = @_;
  $self->{no_sequences} = $no_sequences if (defined $no_sequences);
  return $self->{no_sequences};
}


=head2 aligned()

  Arg[0] : The value to set this to
  Description : Indicates if we want to push aligned sequences into the XML
  Returntype : Boolean
  Exceptions : None
  Status     : Stable

=cut

sub aligned {
  my ($self, $aligned) = @_;
  $self->{aligned} = $aligned if defined $aligned;
  return $self->{aligned};
}

sub tree_elements {
  my ($self, $tree) = @_;
}

sub dispatch_tag {
  my ($self, $node) = @_;
  if(check_ref($node, 'Bio::EnsEMBL::Compara::GenomicAlignTree')) {
    return $self->_genomicaligntree_tag($node);
  }

  my $ref = ref($node);
  throw("Cannot process type $ref");
}

sub dispatch_body {
  my ($self, $node) = @_;
  if(check_ref($node, 'Bio::EnsEMBL::Compara::GenomicAlignTree')) {
    return $self->_genomicaligntree_body($node);
  }

  my $ref = ref($node);
  throw("Cannot process type $ref");
}

sub _genomicaligntree_tag {
  my ($self, $node) = @_;
  if ($self->no_branch_lengths) {
      return ['clade'];
  } else {
      return ['clade', {branch_length => $node->distance_to_parent()}];
  }
}

sub _genomicaligntree_body {
  my ($self, $node) = @_;

  my $w = $self->_writer();

  my $compact_alignments = $self->compact_alignments;
  my $all_genomic_aligns = $node->get_all_genomic_aligns_for_node();
  my $genomic_align_group = $node->genomic_align_group;

  #Tag duplications
  my $type = $node->node_type;
  if((defined $type) and ($type eq "duplication")) {
    $w->startTag('events');
    $w->dataElement('type', 'speciation_or_duplication');
    $w->dataElement('duplications', 1);
    $w->endTag();
  }

  #Number of genomic_aligns = 0 for ancestral nodes in EPO_LOW_COVERAGE
  if ($all_genomic_aligns && @$all_genomic_aligns > 0) {

    #Unique name to handle duplications as opposed to scientific name
    $w->dataElement('name', $node->name);

    #Get taxon for extant species only (genomic_aligns are for a single species)
    if ($all_genomic_aligns->[0]->genome_db->name ne "ancestral_sequences") {
      my $gdb = $all_genomic_aligns->[0]->genome_db;
      $self->_write_genome_db($gdb);
    }

    if ($compact_alignments) {
      #join together locations of multiple GenomicAlign objects
      my @locations;

      #Dealing with Sequence
      $w->startTag('sequence');

      #Append the location strings together
      foreach my $genomic_align (@$all_genomic_aligns) {
	push @locations, sprintf('%s:%d-%d',$genomic_align->dnafrag->name, $genomic_align->dnafrag_start(), $genomic_align->dnafrag_end());
      }
      my $location = join ",", @locations;
      $w->dataElement('location', $location);

      #Do I need type?
      #$w->dataElement('type', 'dna');

      my $mol_seq = ($self->aligned()) ? $genomic_align_group->aligned_sequence : $genomic_align_group->original_sequence;

      $w->dataElement('mol_seq', $mol_seq, 'is_aligned' => ($self->aligned() || 0));
      $w->endTag('sequence');  

    } else {

      #Write each location and sequence out separately
      foreach my $genomic_align (@$all_genomic_aligns) {
	#Dealing with Sequence
	$w->startTag('sequence');

	my $location = sprintf('%s:%d-%d',$genomic_align->dnafrag->name, $genomic_align->dnafrag_start(), $genomic_align->dnafrag_end());
	$w->dataElement('location', $location);

	my $mol_seq = ($self->aligned()) ? $genomic_align->aligned_sequence : $genomic_align->original_sequence;

	$w->dataElement('mol_seq', $mol_seq, 'is_aligned' => ($self->aligned() || 0));
	$w->endTag('sequence');
      }
    }
  }

  return;
}


sub tree_type {
  return 'genomic align tree';
}

1;
