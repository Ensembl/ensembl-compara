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
use Bio::EnsEMBL::Compara::SitewiseOmega;
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

sub get_leaf_by_Member {
  my $self = shift;
  my $member = shift;

  if($member->isa('Bio::EnsEMBL::Compara::ProteinTree')) {
    return $self->find_leaf_by_node_id($member->node_id);
  } elsif ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    return $self->find_leaf_by_name($member->get_longest_peptide_Member->stable_id);
  } else {
    die "Need a Member object!";
  }
}

sub get_SimpleAlign {
  my ($self, @args) = @_;

  my $id_type = 'STABLE';
  my $unique_seqs = 0;
  my $cdna = 0;
  my $stop2x = 0;
  my $append_taxon_id = 0;
  my $append_sp_short_name = 0;
  my $exon_cased = 0;
  if (scalar @args) {
    ($unique_seqs, $cdna, $id_type, $stop2x, $append_taxon_id, $append_sp_short_name, $exon_cased) = 
       rearrange([qw(UNIQ_SEQ CDNA ID_TYPE STOP2X APPEND_TAXON_ID APPEND_SP_SHORT_NAME EXON_CASED)], @args);
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
      $seqstr = $member->alignment_string($exon_cased);
    }
    next if(!$seqstr);

    my $seqID = $member->stable_id;
    $seqID = $member->sequence_id if($id_type eq "SEQ");
    $seqID = $member->member_id if($id_type eq "MEMBER");
    $seqID .= "_" . $member->taxon_id if($append_taxon_id);

    ## Append $seqID with Speciae short name, if required
    if ($append_sp_short_name) {
      my $species = $member->genome_db->short_name;
      $species =~ s/\s/_/g;
      $seqID .= "_" . $species . "_";
    }

#    $seqID .= "_" . $member->genome_db->taxon_id if($append_taxon_id); # this may be needed if you have subspecies or things like that
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

# Takes a protein tree and creates a consensus cigar line from the
# constituent leaf nodes.
sub consensus_cigar_line {

   my $self = shift;
   my @cigars;

   # First get an 'expanded' cigar string for each leaf of the subtree
   foreach my $leaf (@{$self->get_all_leaves}) {
     next unless( UNIVERSAL::can( $leaf, 'cigar_line' ) );
     my @cigar;
     foreach my $num ($leaf->cigar_line =~ m/\d*[A-Z]/g) {
       my $type = chop $num;
       $num ||= 1;
       push @cigar, $type x $num;
     }
     push @cigars, join( '', @cigar );
   }

   # Itterate through each character of the expanded cigars.
   # If there is a 'D' at a given location in any cigar,
   # set the consensus to 'D', otherwise assume an 'M'.
   # TODO: Fix assumption that cigar strings are always the same length,
   # and start at the same point.
   my $cigar_len = length( $cigars[0] );
   my $cons_cigar;
   for( my $i=0; $i<$cigar_len; $i++ ){
     my $char = 'M';
     foreach my $cigar( @cigars ){
       if ( substr($cigar,$i,1) eq 'D'){
         $char='D';
         last;
       }
     }
     $cons_cigar .= $char;
   }

   # TODO: collapse the consensus cigar, e.g. 'DDDD' = 4D

   # Return the consensus
   return $cons_cigar;
}

sub get_SitewiseOmega_values {
  my $self = shift;

  my @values = @{$self->adaptor->db->get_SitewiseOmegaAdaptor->fetch_all_by_ProteinTreeId($self->node_id)};

  return \@values;
}

1;
