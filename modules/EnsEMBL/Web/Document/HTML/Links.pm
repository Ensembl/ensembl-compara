package EnsEMBL::Web::Document::HTML::Links;
use strict;
use warnings;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

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
      sprintf '%s="%s"', encode_entities($_), encode_entities($l->{$_}) }
      keys %$l
    ),"/>\n" );
      
  }
}
1;


