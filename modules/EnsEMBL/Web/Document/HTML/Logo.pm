package EnsEMBL::Web::Document::HTML::Logo;

### Generates the logo wrapped in a link to the homepage

use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub site_logo  {
  ### a
  return 'e-ensembl.gif';
}

sub logo_img {
### a
  my $self = shift;
  return sprintf(
    '<img src="%s%s" alt="Home" title="Return to home page" />',
    $self->img_url
  );
}

sub render {
  my $self = shift;
  $self->printf( '<a href="%s">%s</a>',
    $self->home_url, $self->logo_img
  );
}

1;
