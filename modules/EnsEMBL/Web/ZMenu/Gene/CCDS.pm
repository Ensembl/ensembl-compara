package EnsEMBL::Web::ZMenu::Gene::CCDS;

use strict;
use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self = shift;
  $self->SUPER::content;
  my $object = $self->object;

  my $caption = $object->stable_id;
  $self->caption($caption);

  my $url = $object->get_ExtURL_link( $object->stable_id,'CCDS', $object->stable_id );
  $self->add_entry({
    type  => 'CCDS',
    label => $object->stable_id,
    link  => $url,
    extra => { abs_url => 1 },
    position => 2,
  });

  $self->delete_entry_by_type('Gene type');

}

1;
