package EnsEMBL::Web::Document::HTML::Logo;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub home_url { return '/'; }
sub img_url  { return '/i/'; }
sub logo_img {
  my $self=shift;
  return sprintf(
    '<img src="%se-ensembl.gif" alt="" title="Return to home page" />',
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
