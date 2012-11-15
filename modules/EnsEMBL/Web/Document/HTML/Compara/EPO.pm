package EnsEMBL::Web::Document::HTML::Compara::EPO;

use strict;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub render { 
  my $self = shift;

  my $sets = [
    {'name' => 'birds',     'label' => 'neognath birds'},
    {'name' => 'fish',      'label' => 'teleost fish'},
    {'name' => 'primates',  'label' => 'primates'},
    {'name' => 'mammals',   'label' => 'eutherian mammals'},
  ];

  return $self->format_list('EPO', $sets);
}

1;
