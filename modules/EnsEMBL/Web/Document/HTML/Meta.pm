package EnsEMBL::Web::Document::HTML::Meta;
use strict;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Document::HTML);

sub new      { return shift->SUPER::new( 'tags' => {}, 'equiv' =>{} ); }
sub add      { $_[0]{'tags'}{$_[1]} = $_[2]; }
sub addequiv { $_[0]{'equiv'}{$_[1]} = $_[2]; }
sub render   {
  foreach (keys %{$_[0]{'tags'}}) {
    $_[0]->printf( qq(  <meta name="%s" content="%s" />\n), encode_entities($_), encode_entities($_[0]{'tags'}{$_}));
  }
  foreach (keys %{$_[0]{'equiv'}}) {
    $_[0]->printf( qq(  <meta http-equiv="%s" content="%s" />\n), encode_entities($_), encode_entities($_[0]{'equiv'}{$_}));
  }
}

1;

