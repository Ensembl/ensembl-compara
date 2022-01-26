=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
  
  if ($species_defs->ENSEMBL_STYLE && $species_defs->ENSEMBL_STYLE->{'SITE_ICON'}) {
    $self->add_link({ 
      rel  => 'icon',
      type => 'image/png',
      href => $species_defs->img_url . $species_defs->ENSEMBL_STYLE->{'SITE_ICON'}
    });
  }

  $self->add_link({ 
    rel  => 'apple-touch-icon',
    type => 'image/png',
    href => '/apple-touch-icon.png'
  });
  
  $self->add_link({
    rel   => 'search',
    type  => 'application/opensearchdescription+xml',
    href  => $species_defs->ENSEMBL_BASE_URL . '/opensearch/all.xml',
    title => $species_defs->ENSEMBL_SITE_NAME_SHORT . ' (All)'
  });
  
  if ($species && $species ne 'common' && $species ne 'Multi') {
    $self->add_link({
      rel   => 'search',
      type  => 'application/opensearchdescription+xml',
      href  => $species_defs->ENSEMBL_BASE_URL . "/opensearch/$species.xml",
      title => sprintf('%s (%s)', $species_defs->ENSEMBL_SITE_NAME_SHORT, substr($species_defs->SPECIES_BIO_SHORT, 0, 5))
    });
  }
}

1;
