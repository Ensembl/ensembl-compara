package Bio::EnsEMBL::Compara::Homology;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelation);

sub get_SimpleAlign {
  my $self = shift;
  my $alignment = shift;
  
  my $sa = Bio::SimpleAlign->new();

  #Hack to try to work with both bioperl 0.7 and 1.2:
  #Check to see if the method is called 'addSeq' or 'add_seq'
  my $bio07 = 0;
  if(!$sa->can('add_seq')) {
    $bio07 = 1;
  }

  my $ma = $self->adaptor->db->get_MemberAdaptor;

  foreach my $member_attribute (@{$self->get_all_Member_Attribute}) {
    my ($member, $attribute) = @{$member_attribute};
    my $peptide_member = $ma->fetch_by_dbID($attribute->peptide_member_id);
    my $seqstr;
    if (defined $alignment && $alignment eq "cdna") {
      $seqstr = $attribute->cdna_alignment_string($peptide_member);
      $seqstr =~ s/\s+//g;
    } else {
      $seqstr = $attribute->alignment_string($peptide_member);
    }
    next if(!$seqstr);
    my $seq = Bio::LocatableSeq->new(-SEQ    => $seqstr,
                                     -START  => 1,
                                     -END    => length($seqstr),
                                     -ID     => $peptide_member->stable_id,
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

