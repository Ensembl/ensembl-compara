# $Id$

package EnsEMBL::Web::Document::Element::Stylesheet;

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    media       => {},
    media_order => [],
    conditional => {}
  });
}

sub add_sheet {
  my ($self, $media, $css, $condition) = @_;
  
  push @{$self->{'media_order'}}, $media unless $self->{'media'}{$media};
  push @{$self->{'media'}{$media}}, $css;
  $self->{'conditional'}->{$css} = $condition if $condition;
}

sub content {
  my $self = shift;
  my $content;
  
  foreach my $media (@{$self->{'media_order'}}) {
    foreach (@{$self->{'media'}{$media}}) {
      if ($self->{'conditional'}->{$_}) {
        $content .= qq{  <!--[if $self->{'conditional'}->{$_}]><link rel="stylesheet" type="text/css" media="$media" href="$_" /><![endif]-->\n};
      } else {
        $content .= qq{  <link rel="stylesheet" type="text/css" media="$media" href="$_" />\n};
      }
    }
  }
  
  return $content;
}

sub init {
  my $self         = shift;
  my $controller   = shift;
  my $species_defs = $self->species_defs;
  
  $self->add_sheet('all', sprintf '/%s/%s.css', $species_defs->ENSEMBL_JSCSS_TYPE, $species_defs->ENSEMBL_CSS_NAME);  
  $self->add_sheet('all', '/components/ie.css', 'lte IE 7'); # IE 7/6 only stylesheet
  
  if ($controller->request eq 'ssi') {
    my $head = $controller->content =~ /<head>(.*?)<\/head>/sm ? $1 : '';
    
    while ($head =~ s/<style(.*?)>(.*?)<\/style>//sm) {
      my ($attr, $cont) = ($1, $2);
      
      next unless $attr =~ /text\/css/;
      
      my $media = $attr =~ /media="(.*?)"/ ? $1 : 'all';
      
      if ($attr =~ /src="(.*?)"/) {
        $self->add_sheet($media, $1);
      } else {
        $self->add_sheet($media, $cont);
      }
    }
  }
}

1;
