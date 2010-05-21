package EnsEMBL::Web::Document::HTML::Stylesheet;

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new('media' => {}, 'media_order' => [], 'conditional' => {}); }

sub add_sheet {
  my ($self, $media, $css, $condition) = @_;
  push @{$self->{'media_order'}}, $media unless $self->{'media'}{$media};
  push @{$self->{'media'}{$media}}, $css;
  $self->{'conditional'}->{$css} = $condition if $condition;
}

sub render {
  my $self = shift;
  
  foreach my $media (@{$self->{'media_order'}}) {
    foreach (@{$self->{'media'}{$media}}) {
      if ($self->{'conditional'}->{$_}) {
        $self->print(qq{\n<!--[if $self->{'conditional'}->{$_}]><link rel="stylesheet" type="text/css" media="$media" href="$_" /><![endif]-->});
      } else {
        $self->print(qq{\n<link rel="stylesheet" type="text/css" media="$media" href="$_" />});
      }
    }
  }
}

1;


