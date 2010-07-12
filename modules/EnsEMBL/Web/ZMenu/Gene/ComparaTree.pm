# $Id$

package EnsEMBL::Web::ZMenu::Gene::ComparaTree;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $stable_id    = $object->stable_id;
  my $species      = $hub->species;
  my $species_path = $hub->species_path($species);
  my $phy_link     = $hub->get_ExtURL('PHYLOMEDB', $stable_id);
  my $dyo_link     = $hub->get_ExtURL('GENOMICUSSYNTENY', $stable_id);
  my $treefam_link = $hub->get_ExtURL('TREEFAMSEQ', $stable_id);
  my $ens_tran     = $object->Obj->canonical_transcript; # Link to protein sequence for cannonical or longest translation
  my $ens_prot;
  
  $self->SUPER::content;
  
  if ($ens_tran) {
    $ens_prot = $ens_tran->translation;
  } else {
    my ($longest) = sort { $b->[1]->length <=> $a->[1]->length } map {[$_, ($_->translation || next) ]} @{$object->Obj->get_all_Transcripts};
    ($ens_tran, $ens_prot) = @{$longest||[]};
  }
  
  $self->add_entry({
    type     => 'Species',
    label    => $species,
    link     => $species_path,
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
      link     => $hub->url({
        type   => 'Transcript',
        action => 'Sequence_Protein',
        t      => $ens_tran->stable_id 
      })
    });
  }
}

1;
