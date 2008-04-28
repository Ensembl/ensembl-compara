package EnsEMBL::Web::Document::HTML::Species;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $linked_title; # = '<h1><a class="mh_lnk" href="#">Human</a></h1>';
  $self->printf( $linked_title );
}

return 1;
