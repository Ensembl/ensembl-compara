package EnsEMBL::Web::Configuration::Server;

use strict;
use base qw( EnsEMBL::Web::Configuration );

sub populate_tree {
  my $self = shift;
  $self->create_node( 'Information', 'Server information',
    [qw(information EnsEMBL::Web::Component::Server::Information)],
    {'availability'=>1}
  );
  $self->create_node( 'Colourmap', 'Colour map',
    [qw(colourmap EnsEMBL::Web::Component::Server::ColourMap)],
    {'availability'=>1}
  );
}

sub user_context   { return $_[0]->_user_context; }
sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }
sub configurator   { return $_[0]->_configurator;   }

1;

__END__
sub tree {
  my $self = shift;
  my $panel = new EnsEMBL::Web::Document::Panel(
    'caption' => 'Packed tree',
    'object'  => $self->{object}
  );
  $panel->add_form( $self->{page},
    qw(tree EnsEMBL::Web::Component::Server::tree_form)
  );
  $panel->add_components(
    qw(tree EnsEMBL::Web::Component::Server::tree)
  );
  $self->{page}->content->add_panel( $panel );
  $self->{page}->title->set( 'Configuration dumping' );
}

sub urlsource {
  my $self = shift;
  my $panel = new EnsEMBL::Web::Document::Panel(
    'caption' => 'Attach URL based data',
    'object'  => $self->{object}
  );
  $panel->add_form( $self->{page},
    qw(urlsource EnsEMBL::Web::Component::Server::urlsource_form)
  );
  $panel->add_components(
    qw(urlsource EnsEMBL::Web::Component::Server::urlsource)
  );
  $self->{page}->content->add_panel( $panel );
  $self->{page}->title->set( 'Adding URL source data to EnsEMBL' );
}

sub colourmap {
  my $self = shift;
  my $panel1 = new EnsEMBL::Web::Document::Panel::SpreadSheet(
    'code'    => "colours",
    'caption' => 'ColourMap',
    'object'  => $self->{object}
  );
  $panel1->add_components( qw(species EnsEMBL::Web::Component::Server::spreadsheet_Colours));
  $self->{page}->content->add_panel( $panel1 );
  my $panel2 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => 'Usage',
    'object'  => $self->{object}
  );
  $panel2->add_components( qw(
    usage EnsEMBL::Web::Component::Server::colourmap_usage
  ));
  $self->{page}->content->add_panel( $panel2 );

}

sub status {
  my $self = shift;
  my $panel1 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "info",
    'caption' => 'Current server information',
    'object'  => $self->{object}
  );
  $panel1->add_components(qw(
    name       EnsEMBL::Web::Component::Server::name
    url        EnsEMBL::Web::Component::Server::url
    version    EnsEMBL::Web::Component::Server::version
    webserver  EnsEMBL::Web::Component::Server::webserver
    perl       EnsEMBL::Web::Component::Server::perl
    database   EnsEMBL::Web::Component::Server::database
    contact    EnsEMBL::Web::Component::Server::contact
  ));
  $self->{page}->content->add_panel( $panel1 );
  my $panel2 = new EnsEMBL::Web::Document::Panel::SpreadSheet(
    'code'    => 'species',
    'caption' => 'Configured species',
    'object'  => $self->{object},
    'status'  => 'panel_species'
  );
  $panel2->add_components( qw(species EnsEMBL::Web::Component::Server::spreadsheet_Species));

  $self->{page}->content->add_panel( $panel2 );

}

sub context_menu {
  my $self = shift;
  my $sp = $self->{object}->species;
  $self->add_block( 'server', 'bulleted', 'Server information' );
  $self->add_entry( 'server', 'text' => 'Server information', 'href' => "/$sp/status" );
  my $CM_URL = "/$sp/colourmap";
  my @CM_OPT = (
    ['Sorted by Red, Green'  => $CM_URL.'?sort=rgb'],
    ['Sorted by Red, Blue'   => $CM_URL.'?sort=rbg'],
    ['Sorted by Green, Red'  => $CM_URL.'?sort=grb'],
    ['Sorted by Green, Blue' => $CM_URL.'?sort=gbr'],
    ['Sorted by Blue, Red'   => $CM_URL.'?sort=brg'],
    ['Sorted by Blue, Green' => $CM_URL.'?sort=bgr'],
    ['Sorted by Hue, Saturation'   => $CM_URL.'?hls=hsl'],
    ['Sorted by Hue, Luminosity'   => $CM_URL.'?hls=hls'],
    ['Sorted by Luminosity, Hue'   => $CM_URL.'?hls=lhs'],
    ['Sorted by Luminosity, Saturation'  => $CM_URL.'?hls=lsh'],
    ['Sorted by Saturation, Hue'   => $CM_URL.'?hls=shl'],
    ['Sorted by Saturation, Luminosity'  => $CM_URL.'?hls=slh'],
  );
  $self->add_entry( 'server', 'text' => 'ColourMap', 
                 'href' => $CM_URL,
                 'options' => [map {{ 'href' => $_->[1], 'text' => $_->[0] }} @CM_OPT ]
  );
}

1;
