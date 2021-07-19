=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::StaticTabs;

# Generates the global context navigation menu, used in static pages

use strict;

use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Document::Element::Tabs);

sub _tabs {
  return {
    tab_order => [qw(website data about)],
    tab_info  => {
      about     => {
                    title => 'About us',
                    },
      data      => {
                    title => 'Data access',
                    },
      website   => {
                    title => 'Using this website',
                    },
    },
  };
}

sub init {
  my $self          = shift;
  my $controller    = shift;
  my $hub           = $controller->hub;
  my $species_defs  = $hub->species_defs;  
   
  my $here = $ENV{'REQUEST_URI'};

  my $tabs = $self->_tabs;

  foreach my $section (@{$tabs->{'tab_order'}}) {
    my $info = $tabs->{'tab_info'}{$section};
    next unless $info;
    my $url   = "/info/$section/";
    my $class = ($here =~ /^$url/) ? ' active' : '';
    $self->add_entry({
      'type'    => $section,
      'caption' => $info->{'title'},
      'url'     => $url,
      'class'   => $class,
    });
  }
}

1;
