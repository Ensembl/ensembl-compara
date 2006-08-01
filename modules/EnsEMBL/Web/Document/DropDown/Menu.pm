package EnsEMBL::Web::Document::DropDown::Menu;

use strict;
use EnsEMBL::Web::Document::DropDown::MenuItem::Checkbox;
use EnsEMBL::Web::Document::DropDown::MenuItem::Link;
use EnsEMBL::Web::Document::DropDown::MenuItem::Text;
use EnsEMBL::Web::Document::DropDown::MenuItem::Radiobutton;
use Data::Dumper;

sub new {
  my $class = shift;
  my $menu_container = shift;
  my $self = {
## To grab from the configuration of the menu container....
    'panel'        => $menu_container->{'panel'}        || '',
    'extra'        => $menu_container->{'extra'}        || '',
    'image_height' => $menu_container->{'height'}       || 25,
    'species'      => $menu_container->{'species'}      || '',
    'script'       => $menu_container->{'script'}       || '',
    'config'       => $menu_container->{'config'}       || undef,
    'configs'      => $menu_container->{'configs'}      || [],
    'scriptconfig' => $menu_container->{'scriptconfig'} || undef,
    'location'     => $menu_container->{'location'}     || undef,
    'object'       => $menu_container->{'object'}       || undef,
## Set to "empty"
    'menuitems'      => [],
    'missing_tracks' => 0,

## Image name bits (these should be over-written...
    'image_name'   => '',
    'alt'          => '',
    'image_width'  => 40,
## Values to over-write 
    @_
  };
  bless $self, $class;
  return $self;
}

sub add_item {
  my( $self, $menu_item ) = @_;
  push @{$self->{'menuitems'}}, $menu_item;
}

sub add_link {
  my $self = shift;
  $self->add_item( new EnsEMBL::Web::Document::DropDown::MenuItem::Link( @_ ) );
}

sub add_text {
  my $self = shift;
  $self->add_item( new EnsEMBL::Web::Document::DropDown::MenuItem::Text( @_ ) );
}

sub add_checkbox {
  my( $self, $name, $label, $c ) = @_;
    $c ||= $self->{'config'};
  my $sc = $self->{'scriptconfig'};

  if( $name eq 'imagemap' || $name =~ /^format_/ || $name =~/^opt_/ ) { ## Display option setting
    $self->add_item( new EnsEMBL::Web::Document::DropDown::MenuItem::Checkbox(
      $label, $name, ( $sc && defined $sc->get($name) ) ? ($sc->get($name) eq 'on'?1:0) : $c->get('_settings', $name) 
    ) );
  } else { ## Track 
    my $value = ( $c->get($name, 'on') eq 'on' ) ? 1 : 0;
    $self->add_item( new EnsEMBL::Web::Document::DropDown::MenuItem::Checkbox(
      $label, $name, $value
    ) );
    $self->{'missing_tracks'}++ if $value==0;
  }
}
sub add_radiobutton {
  my( $self, $name, $label, $c ) = @_;
  $c ||= $self->{'config'};
  my $sc = $self->{'scriptconfig'};
  my $value = ( $sc && defined $sc->get($name) ) ? ($sc->get($name) eq 'on' ? 1 : 0) : ( $c->get($name, 'on') eq 'on' ) ? 1 : 0;

  $self->add_item( new EnsEMBL::Web::Document::DropDown::MenuItem::Radiobutton(	$label, $name, $value ) );

}

sub render_html {
  my $self = shift;
  return qq(<a
  onmouseover="i_on('b_$self->{'index'}','$self->{'image_name'}')"
  onmouseout="i_off('b_$self->{'index'}','$self->{'image_name'}')"
  onclick="if(LOADED) { if(dd_showDetails($self->{'index'},0)) { document.forms['$self->{'panel'}'].submit(); } else { void(0); } } else {void(0);} "><img
  alt="$self->{'alt'}" id="b_$self->{'index'}" name="b_$self->{'index'}"
  height="$self->{'image_height'}" width="$self->{'image_width'}"
  src="/img/dd_menus/$self->{'image_name'}.gif" /></a>);
}

sub render_js {
  my $self = shift;
  return qq(  new dd_Menu("$self->{'image_name'}","$self->{'panel'}",new Array(@{[join ",\n",map {$_->render} @{$self->{'menuitems'}} ]})));
}

1;
