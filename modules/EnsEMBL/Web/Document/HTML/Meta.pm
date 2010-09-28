# $Id$

package EnsEMBL::Web::Document::HTML::Meta;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

sub new      { return shift->SUPER::new( 'tags' => {}, 'equiv' =>{} ); }
sub add      { $_[0]{'tags'}{$_[1]}  = $_[2]; }
sub addequiv { $_[0]{'equiv'}{$_[1]} = $_[2]; }

sub _content {
  my $self = shift;
  my $content;
  
  $content .= sprintf qq{  <meta name="%s" content="%s" />\n},       encode_entities($_), encode_entities($self->{'tags'}{$_})  for keys %{$self->{'tags'}};
  $content .= sprintf qq{  <meta http-equiv="%s" content="%s" />\n}, encode_entities($_), encode_entities($self->{'equiv'}{$_}) for keys %{$self->{'equiv'}};
  
  return $content;
}

sub init {
  # There's nothing in the codebase. Delete?
}

1;
