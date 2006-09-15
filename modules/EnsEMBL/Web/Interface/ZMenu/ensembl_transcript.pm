package EnsEMBL::Web::Interface::ZMenu::ensembl_transcript;

use EnsEMBL::Web::Interface::ZMenu;
our @ISA = qw(EnsEMBL::Web::Interface::ZMenu);

sub populate {
  my $self = shift;
  $self->SUPER::populate;
  $self->title($self->ident);
  $self->add_text('info1', 'Data');
  $self->add_text('info2', 'More data');
}

1;
