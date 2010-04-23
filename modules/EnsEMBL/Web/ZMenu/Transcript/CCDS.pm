package EnsEMBL::Web::ZMenu::Transcript::CCDS;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Transcript);

sub content {
  my $self = shift;
  $self->SUPER::content;
  my $object  = $self->object;
  $self->caption($object->gene->stable_id);

  my $url = $object->get_ExtURL_link( $object->stable_id,'CCDS', $object->stable_id );
  $self->add_entry({
    type  => 'CCDS',
    label => $object->stable_id,
    link  => $url,
    extra => { abs_url => 1 },
    position => 2,
  });

  $self->delete_entry_by_type('Transcript');
  $self->delete_entry_by_type('Protein product');
  $self->delete_entry_by_type('Gene type');
}

1;
