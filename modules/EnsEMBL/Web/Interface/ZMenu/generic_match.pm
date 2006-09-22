package EnsEMBL::Web::Interface::ZMenu::generic_match;

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Interface::ZMenu;

our @ISA = qw(EnsEMBL::Web::Interface::ZMenu);

sub populate {
  my ($self, %params) = @_;
  my $indexer = new EnsEMBL::Web::ExtIndex( new EnsEMBL::Web::SpeciesDefs );
  my $result_ref = $indexer->get_seq_by_id({ DB  => 'EMBL', ID  => $self->ident, OPTIONS => 'desc' });
  my @results = @{$result_ref||['NO DATA']};
  my $count = 0;

  foreach my $result (@results) {
    chomp $result;
    $self->add_text("item" . $count, $result);
  }

  $self->title($self->ident);

}

1;
