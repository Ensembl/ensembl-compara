package EnsEMBL::Web::Document::HTML::Stylesheet;

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new(@_, {'media' => {}, 'media_order' => []} ); }

sub add {
  my ($self, $media, $css) = @_;
  push @{$self->{'media_order'}}, $media unless $self->{'media'}{$media};
  $self->{'media'}{$media} .= "    $css\n";
}

sub add_sheet { $_[0]->add( $_[1], "\@import url($_[2]);" ); }

sub render { 
  foreach my $media (@{$_[0]{'media_order'}}) {
    $_[0]->printf(qq{  <style type="text/css" media="%s">\n%s  </style>\n}, $media, $_[0]{'media'}{$media});
  }
}

1;


