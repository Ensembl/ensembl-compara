# $Id$

package EnsEMBL::Web::ZMenu::Gene::ComparaTree;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self = shift;
  
  $self->SUPER::content;
  
  my $object       = $self->object;
  my $species      = $object->species;
  my $phy_link     = $object->get_ExtURL('PHYLOMEDB', $object->stable_id);
  my $dyo_link     = $object->get_ExtURL('GENOMICUSSYNTENY', $object->stable_id);
  my $treefam_link = $object->get_ExtURL('TREEFAMSEQ', $object->stable_id);
  my $ens_tran     = $object->Obj->canonical_transcript; # Link to protein sequence for cannonical or longest translation
  my $ens_prot;
  
  if ($ens_tran) {
    $ens_prot = $ens_tran->translation;
  } else {
    my ($longest) = sort { $b->[1]->length <=> $a->[1]->length } map {[$_, ($_->translation || next) ]} @{$object->Obj->get_all_Transcripts};
    ($ens_tran, $ens_prot) = @{$longest||[]};
  }
  
  $self->add_entry({
    type     => 'Species',
    label    => $species,
    link     => "/$species",
    position => 1
  });
  
  if ($phy_link) {
    $self->add_entry({
      type     => 'PhylomeDB',
      label    => 'Gene in PhylomeDB',
      link     => $phy_link,
      extra    => { external => 1 },
      position => 3
    });
  }
  
  if ($dyo_link) {
    $self->add_entry({
      type     => 'Genomicus Synteny',
      label    => 'Gene in Genomicus',
      link     => $dyo_link,
      extra    => { external => 1 }, 
      position => 4
    });
  }
  
  if ($treefam_link) {
    $self->add_entry({
      type     => 'TreeFam',
      label    => 'Gene in TreeFam',
      link     => $treefam_link,
      extra    => { external => 1 },
      position => 5
    });
  }
  
  if ($ens_prot) {
    $self->add_entry({
      type     => 'Protein',
      label    => $ens_prot->display_id,
      position => 6,
      link     => $object->_url({
        type   => 'Transcript',
        action => 'Sequence_Protein',
        t      => $ens_tran->stable_id 
      })
    });
  }
}

1;
