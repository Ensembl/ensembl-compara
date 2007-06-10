package EnsEMBL::Web::Document::DropDown::MenuContainer;

use CGI qw(escapeHTML escape);
use strict;
use EnsEMBL::Web::Root;

our @ISA = qw(EnsEMBL::Web::Root);

sub  new {
  my $class = shift;
  my %param = @_;
  my $width = ( $param{'scriptconfig'} ?
                $param{'scriptconfig'}->get('image_width') : $param{'config'} ? $param{'config'}->get('_settings','width') : 0
              ) || 600;
  #warn $param{'object'};
  my $self = {
    'leftmenus'   => [],
    'rightmenus'  => [],
    'width'       => $width,
    'height'      => 25,     # height of menu bar
    'menuheight'  => 21,     # height of menu entry
    'menuwidth'   => 100,    # width of menu entry
    'checkwidth'  => 20,     # check box width
    'checkheight' => 17,     # check box height
    'endingwidth' => 2,      # width of "left and right of menu bar" images
    'imagepath'   => '/img/dd_menus/', # path to image library.... 
    '_hidden_values' => {},
    '_missing_tracks_' => 0,
    %param
  }; 
  $self->{'width'} = $width;
  $self->{'_spacer_width_'} = $self->{'width'} - 2 * $self->{'endingwidth'};
  bless $self, $class;
  return $self;
}

sub create_menu {
  my $self = shift;
  my $module = shift;
  my $classname = "EnsEMBL::Web::Document::DropDown::Menu::".$module;
  if( $self->dynamic_use( $classname ) ) {
    my $menu;
    $menu = $classname->new( $self, 'LINK' => $self->render_LINK(), @_ );
    if($menu) {
      $self->{'_spacer_width_'} -= $menu->{'image_width'};
      return $menu;
    }
    return undef; 
  } else {
    warn "Unable to compile menu $classname";
  }
  return undef;
}

sub add_left_menu {
  my $self = shift;
  my $menu = $self->create_menu( @_ );
  return unless $menu;
  $menu->{'index'} = $self->{'index'}++;
  push @{$self->{'leftmenus'}} , $menu;
  $self->{'missing_tracks'} += $menu->{'missing_tracks'};
}

sub add_right_menu { 
  my $self = shift;
  my $menu = $self->create_menu( @_ );
  return unless $menu;
  $menu->{'index'} = $self->{'index'}++;
  push @{$self->{'rightmenus'}} ,  $menu;
  $self->{'missing_tracks'} += $menu->{'missing_tracks'};
}

sub hidden_values {
  my $self = shift;
  $self->{'_hidden_values'} = shift;
}

sub render_js {
  my $self = shift;
  return $self->render_js_ajx if $self->{'ajax'};
  return qq(
<script type="text/javascript"><!--
  dd_menuheight  = $self->{'height'};
  dd_menuwidth   = $self->{'menuwidth'};
  dd_checkwidth  = $self->{'checkwidth'};
  dd_checkheight = $self->{'checkheight'};
  dd_imagepath   = '$self->{'imagepath'}';
  dd_menus = new Array( @{[join(',', map { $_->render_js() } @{$self->{'leftmenus'}}, @{$self->{'rightmenus'}} )]} );
  document.writeln(dd_render_all_layers());
//--></script>
  );
}

sub render_js_ajax {
  my $self = shift;
  return qq(
  <div id='menu_container'></div>
  <div id='menu_code' style='display: none;'>
  dd_menuheight  = $self->{'height'};
  dd_menuwidth   = $self->{'menuwidth'};
  dd_checkwidth  = $self->{'checkwidth'};
  dd_checkheight = $self->{'checkheight'};
  dd_imagepath   = '$self->{'imagepath'}';
  dd_menus = new Array( @{[join(',', map { $_->render_js() } @{$self->{'leftmenus'}}, @{$self->{'rightmenus'}} )]} );
  dd_render_all_layers_to_element('menu_container');
  </div>
<script type="text/javascript"><!--
  init_dropdown_menu();
//--></script>
  );
  #document.writeln(dd_render_all_layers_to_element('menu_container'));
}

sub render_hidden { 
  my $self = shift;
  my $T = $self->_fields();
  return map { qq(<input type="hidden" name="$_" value="@{[CGI::escapeHTML($T->{$_})]}" />) } keys %$T;
}

sub render_LINK {
  my $self = shift;
  return $self->{'LINK'} if $self->{'LINK'};
  my $T = $self->_fields();
  return $self->{'LINK'} = join '', map { qq($_=@{[CGI::escape($T->{$_})]};) } keys %$T;
}

sub _fields{
  my $self = shift;
  return $self->{'fields'} || {};
}

sub render_html {
  my $self = shift;
  my $panel = $self->{'panel'};
  #warn "RENDERING CONTAINER HTML WITH WIDTH: " . $self->{'width'};
  my $html = qq(
<div class="autocenter" style="border: solid 1px black; border-width: 1px 1px 0px 1px; width: @{[$self->{'width'}-2]}px;">
<form action="/@{[$self->{'species'}]}/@{[$self->{'script'}]}" name="$panel" id="$panel" method="get" style="white-space: nowrap; width: @{[$self->{'width'}-2]}px; border: 0px; padding: 0px" class="autocenter print_hide_block">
  <input type="hidden" name="$panel" value="" />
  @{[$self->render_hidden]}
  <img alt="" height="$self->{'height'}" width="$self->{'endingwidth'}" src="$self->{'imagepath'}y-left.gif" />@{[
   join '',map { $_->render_html } @{$self->{'leftmenus'}} 
  ]}<a href="javascript:if(dd_showDetails(-1,0)){document.forms['$panel'].submit();}else{void(0);}"><img
    alt="" height="$self->{'height'}" width="@{[$self->{'_spacer_width_'}-2]}" src="$self->{'imagepath'}y-button.gif" /></a>@{[
   join '',map { $_->render_html } @{$self->{'rightmenus'}} 
  ]}<img alt="" height="$self->{'height'}" width="$self->{'endingwidth'}" src="$self->{'imagepath'}y-right.gif" />
</form>
</div>
  );
  #warn "MC HTML:";
  #warn $html;
  return $html;
}

1;
