# $Id$

package EnsEMBL::Web::Document::Element::StaticTabs;

# Generates the global context navigation menu, used in static pages

use strict;

use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Document::Element::Tabs);

sub _tabs {
  return {
    tab_order => [qw(website genome data docs about)],
    tab_info  => {
      about     => {
                    title => 'About us',
                    },
      data      => {
                    title => 'Data access',
                    },
      docs      => {
                    title => 'API & software',
                    },
      genome    => {
                    title => 'Annotation & prediction',
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
