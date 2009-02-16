package EnsEMBL::Web::Document::HTML::Links;
use strict;
use warnings;

use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Document::HTML);

# <link rel="icon" type="image/png" href="/mail/check-favicon.png">

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( 'links' => [] );
  return $self;
}

sub add_link { 
  my $self = shift;
  push @{ $self->{'links'} }, shift;
}

sub render { 
  my $self = shift ;

  foreach my $l ( @{$self->{'links'}} ) {
    $self->print( '  <link ',join( ' ', map {
      sprintf '%s="%s"', escapeHTML($_), escapeHTML($l->{$_}) }
      keys %$l
    ),"/>\n" );
      
  }
}
1;


