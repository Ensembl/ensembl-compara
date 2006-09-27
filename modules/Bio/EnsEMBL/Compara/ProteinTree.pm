=head1 NAME

ProteinTree - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the leaves of this tree
are AlignedMember objects and the tree is a representation of a Protein derived
Phylogenetic tree

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL compara project: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut



package Bio::EnsEMBL::Compara::ProteinTree;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::SimpleAlign;
use IO::File;

use Bio::EnsEMBL::Compara::NestedSet;
our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);

=head2 description_score

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub description_score {
  my $self = shift;
  $self->{'_description_score'} = shift if(@_);
  return $self->{'_description_score'};
}


sub get_SimpleAlign {
  my ($self, @args) = @_;

  my $id_type = 'STABLE';
  my $unique_seqs = 0;
  my $cdna = 0;
  my $stop2x = 0;
  my $append_taxon_id = 0;
  if (scalar @args) {
    ($unique_seqs, $cdna, $id_type, $stop2x, $append_taxon_id) = 
       rearrange([qw(UNIQ_SEQ CDNA ID_TYPE STOP2X APPEND_TAXON_ID)], @args);
  }
  $id_type = 'STABLE' unless(defined($id_type));

  my $sa = Bio::SimpleAlign->new();

  #Hack to try to work with both bioperl 0.7 and 1.2:
  #Check to see if the method is called 'addSeq' or 'add_seq'
  my $bio07 = 0;
  $bio07=1 if(!$sa->can('add_seq'));

  my $seq_id_hash = {};
  foreach my $member (@{$self->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    next if($unique_seqs and $seq_id_hash->{$member->sequence_id});
    $seq_id_hash->{$member->sequence_id} = 1;

    my $seqstr;
    if ($cdna) {
      $seqstr = $member->cdna_alignment_string;
      $seqstr =~ s/\s+//g;
    } else {
      $seqstr = $member->alignment_string;
    }
    next if(!$seqstr);

    my $seqID = $member->stable_id;
    $seqID = $member->sequence_id if($id_type eq "SEQ");
    $seqID = $member->member_id if($id_type eq "MEMBER");
    $seqID .= "_" . $member->taxon_id if($append_taxon_id);
    $seqstr =~ s/\*/X/g if ($stop2x);
    my $seq = Bio::LocatableSeq->new(-SEQ    => $seqstr,
                                     -START  => 1,
                                     -END    => length($seqstr),
                                     -ID     => $seqID,
                                     -STRAND => 0);

    if($bio07) {
      $sa->addSeq($seq);
    } else {
      $sa->add_seq($seq);
    }
  }

  return $sa;
}



1;
