# $Id$

package EnsEMBL::Web::Document::Element::Links;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    links => []
  });
}

sub add_link { 
  my $self = shift;
  push @{ $self->{'links'} }, shift;
}

sub content { 
  my $self = shift;
  my $content;
  
  foreach my $link (@{$self->{'links'}}) {
    $content .= sprintf "  <link %s />\n", join ' ', map { sprintf '%s="%s"', encode_entities($_), encode_entities($link->{$_}) } keys %$link;
  }
  
  return $content;
}

sub init {
  my $self         = shift;
  my $controller   = shift;
  my $hub          = $controller->hub;
  my $species      = $hub->species;
  my $species_defs = $self->species_defs;
  
  $self->add_link({ 
    rel  => 'icon',
    type => 'image/png',
    href => $species_defs->ENSEMBL_IMAGE_ROOT . $species_defs->ENSEMBL_STYLE->{'SITE_ICON'}
  });
  
  $self->add_link({
    rel   => 'search',
    type  => 'application/opensearchdescription+xml',
    href  => $species_defs->ENSEMBL_BASE_URL . '/opensearch/all.xml',
    title => $species_defs->ENSEMBL_SITE_NAME_SHORT . ' (All)'
  });
  
  if ($species) {
    $self->add_link({
      rel   => 'search',
      type  => 'application/opensearchdescription+xml',
      href  => $species_defs->ENSEMBL_BASE_URL . "/opensearch/$species.xml",
      title => sprintf('%s (%s)', $species_defs->ENSEMBL_SITE_NAME_SHORT, substr($species_defs->SPECIES_BIO_SHORT, 0, 5))
    });
  }
  
  $self->add_link({
    rel   => 'alternate',
    type  => 'application/rss+xml',
    href  => '/common/rss.xml',
    title => 'Ensembl website news feed'
  });
}

1;
