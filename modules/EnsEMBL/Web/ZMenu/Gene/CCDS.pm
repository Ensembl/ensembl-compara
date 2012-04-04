package EnsEMBL::Web::ZMenu::Gene::CCDS;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self      = shift;
  my $stable_id = $self->object->stable_id;
  
  $self->SUPER::content;
  
  $self->caption($stable_id);
  
  $self->add_entry({
    type  => 'CCDS',
    label => $stable_id,
    link  => $self->hub->get_ExtURL_link($stable_id, 'CCDS', $stable_id),
    extra => { abs_url => 1 },
    position => 2,
  });
  $self->delete_entry_by_type('Gene');
  $self->delete_entry_by_type('Gene type');
}

1;
