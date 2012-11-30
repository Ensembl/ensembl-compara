package EnsEMBL::Web::ZMenu::VChrom;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $chr = $hub->param('chr');
  my $href = $hub->url({'type' => 'Location',
                        'action' => 'Chromosome',
                        '__clear' => 1, 
                        'r' => $chr});   
 
  $self->caption("Chromosome $chr");
  $self->add_entry({
    type  => 'Summary',
    label => "Chromosome $chr", 
    link => $href,
    order => 1,
  });
}

1;
