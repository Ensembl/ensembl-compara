# $Id$

package EnsEMBL::Web::ViewConfig::Matrix;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::ViewConfig);

# TODO: Support z dimension - popup with extra options on each square
# TODO: Support other datahub dimensions as filters?

sub init {
  my $self = shift;
  my $defaults;
  
  while (my ($menu, $conf_set) = each %{$self->{'matrix_config'}}) {
    while (my ($set, $conf) = each %$conf_set) {
      foreach my $x (keys %{$conf->{'features'}}) {
        $defaults->{"opt_matrix_${menu}_${set}_$x:$_"} = [ "$x - $_", $conf->{'defaults'}{$x}{$_} eq 'on' ? 'on' : 'off' ] for keys %{$conf->{'features'}{$x}};
      }
    }
  }
  
  $self->set_defaults($defaults);
}

sub form {
  my $self = shift;
  
  if ($self->hub->function eq 'Matrix') {
    $self->form_matrix;
  } else {
    my $func = $self->{'form_func'};
    
    $self->$func if $func && $self->can($func);
    
    foreach my $menu (sort keys %{$self->{'matrix_config'}}) {
      $self->add_fieldset("${menu}_$_", 'empty', 1) for sort keys %{$self->{'matrix_config'}{$menu}};
    }
  }
}

sub add_image_config {
  my $self = shift;
  $self->set_columns(@_);
  $self->SUPER::add_image_config(@_) if $self->hub->function ne 'Matrix';
}

sub reset {
  my $self = shift;
  
  $_->{'columns'} = [] for map values %$_, values %{$self->{'matrix_config'}};
  
  $self->SUPER::reset(@_);
  $self->set_columns(@_);
}

sub set_columns {
  my ($self, $image_config) = @_;
  my $tree = (ref $image_config ? $image_config : $self->hub->get_imageconfig($image_config))->tree;
  
  foreach (grep $_->data->{'label_x'}, $tree->nodes) {
    my $set       = $_->data->{'set'};
    my $label_x   = $_->data->{'label_x'};
    my $menu      = $tree->clean_id($_->data->{'menu_key'});
    my $renderers = $_->get('renderers');
    my %renderers = @$renderers;
    my $conf      = $self->{'matrix_config'}{$menu}{$set} ||= {
      menu         => $set,
      track_prefix => $set,
      section      => $tree->get_node($menu)->get('caption'),
      header       => $_->data->{'header'},
      description  => $_->data->{'description'},
      axes         => $_->data->{'axes'},
    };
    
    push @{$conf->{'columns'}}, { display => $_->get('display'), renderers => $renderers, x => $label_x };
    
    $conf->{'features'}{$label_x} = $_->data->{'features'};
    $conf->{'renderers'}{$_}++ for keys %renderers;
  }
}

sub matrix_data {
  my ($self, $menu, $set) = @_;
  my %data = map { $_ => 1 } map keys %$_, values %{$self->{'matrix_config'}{$menu}{$set}{'features'}};
  return map { id => $_ }, sort keys %data;
}

sub build_imageconfig_form {
  my $self         = shift;
  my $image_config = shift;
  my $hub          = $self->hub;
  my $tree         = $self->tree;
  my %counts;
  
  $self->SUPER::build_imageconfig_form($image_config);
  
  while (my ($menu, $conf_set) = each %{$self->{'matrix_config'}}) {
    while (my ($set, $conf) = each %$conf_set) {
      my $node = $tree->get_node($conf->{'menu'});
      
      next unless $node;
      
      $counts{$set}{'total'} = scalar @{$conf->{'columns'}};
      $counts{$set}{'on'}    = scalar grep { $_->{'display'} ne 'off' } @{$conf->{'columns'}}; 
      
      my $menu_data = {
        url          => $hub->url('Config', { function => 'Matrix', partial => 1, set => $set, menu => $menu }),
        count        => qq{(<span class="on">$counts{$set}{'on'}</span>/$counts{$set}{'total'})},
        class        => $conf->{'subset'},
        class        => "${menu}_$set",
        availability => 1,
      };
      
      $node->set($_, $menu_data->{$_}) for keys %$menu_data;
    }
  }
}

sub form_matrix {
  my $self      = shift;
  my $hub       = $self->hub;
  my $set       = $hub->param('set');
  my $menu      = $hub->param('menu');
  my $img_url   = $self->img_url;
  my $conf      = $self->{'matrix_config'}{$menu}{$set};
  my @columns   = @{$conf->{'columns'}};
  my $width     = (scalar @columns * 26) + 107; # Each td is 25px wide + 1px border. The first cell (th) is 90px + 1px border + 16px padding-right
  my %filters   = ( '' => 'All classes' );
  my $tick      = qq{<img class="tick" src="${img_url}tick.png" alt="Selected" title="Selected" />};
  my (@rows, $rows_html, @headers_html, $last_class);
  
  $self->{'panel_type'} = 'ConfigMatrix';
  
  my $select_all_col = qq{
    <div class="select_all_column floating_popup">
      Select features for %s<br />
      <div><input type="radio" name="%s" class="default">Default</input></div>
      <div><input type="radio" name="%s" class="all">All</input></div>
      <div><input type="radio" name="%s" class="none">None</input></div>
    </div>
  };
  
  my $select_all_row = qq{
    <div class="select_all_row floating_popup">
      Select all<br />
      %s
      <input type="checkbox" />
    </div>
  };
  
  my @renderer_template = (
    qq{<ul class="popup_menu"><li class="header">Change track style<img class="close" src="${img_url}close.png" title="Close" alt="Close" /></li>},
    qq{<li class="%s"><img title="%s" alt="%s" src="${img_url}render/%s.gif" class="$conf->{'menu'}_$set" />%s<span%s>%s</span></li>},
    '</ul>'
  );
  
  my %counts = reverse %{$conf->{'renderers'}};
  my ($k, $v, $renderer_html);
  
  if (scalar keys %counts != 1) {
    $renderer_html .= sprintf $renderer_template[1], $_->[2], $_->[1], $_->[1], $_->[0], '', '', $_->[1] for [ 'off', 'Off', 'off' ], [ 'normal', 'On', 'all_on' ];
  } else {
    my $renderers = $self->deepcopy($conf->{'columns'}[0]{'renderers'});
    $renderer_html .= sprintf $renderer_template[1], $k, $v, $v, $k, '', '', $v while ($k, $v) = splice @$renderers, 0, 2;
  }
  
  $headers_html[1] = "$renderer_template[0]$renderer_html$renderer_template[2]";
  
  foreach ($self->matrix_data($menu, $set)) {
    my $id       = $_->{'id'};
    my $y        = $_->{'y'} || $id;
    my $class    = $_->{'class'};
    (my $y_class = lc $y)     =~ s/[^\w-]/_/g;
    (my $cls     = lc $class) =~ s/[^\w-]/_/g;
    my @row      = ("$y_class $cls", { tag => 'th', class => 'first', html => sprintf("$y$select_all_row", $y) });
    my $exists;
    
    push @rows, [ 'gap', { tag => 'td' }] if $last_class && $class ne $last_class;
    
    $last_class    = $class;
    $filters{$cls} = $class if $class;
    
    foreach (@columns) {
      my $x    = $_->{'x'};
      my $cell = { tag => 'td', html => '<p></p>' };
      
      if (exists $conf->{'features'}{$x}{$id}) {
        $cell->{'title'}  = "$x:$y";
        $cell->{'class'}  = "option $x $y_class";
        $cell->{'class'} .= ' on'      if $self->get("opt_matrix_${menu}_${set}_$x:$id") eq 'on';
        $cell->{'class'} .= ' default' if $self->{'options'}{"opt_matrix_${menu}_${set}_$x:$id"}{'default'} eq 'on';
        
        $exists = 1;
      } else {
        $cell->{'class'} = 'disabled';
      }
      
      push @row, $cell;
    }
    
    push @rows, \@row if $exists;
  }
    
  foreach (@rows) {
    my $row_class = shift @$_;
    my $row_html;
    
    foreach (@$_) {
      $row_html .= sprintf('<%s%s%s%s>%s</%s>',
        $_->{'tag'},
        $_->{'class'}   ? qq{ class="$_->{'class'}"}     : '',
        $_->{'title'}   ? qq{ title="$_->{'title'}"}     : '',
        $_->{'colspan'} ? qq{ colspan="$_->{'colspan'}"} : '',
        $_->{'html'},
        $_->{'tag'}
      );
    }
    
    $rows_html .= qq{<tr class="$row_class">$row_html</tr>};
  }
  
  foreach (@columns) {
    my $x         = $_->{'x'};
    my $display   = $_->{'display'};
    my %renderers = @{$_->{'renderers'}};
    my $name      = join '_', $conf->{'track_prefix'} eq $set ? () : $conf->{'track_prefix'}, $set, $x;
       $name      =~ s/[^\w-]/_/g;
    my $menu      = $renderer_template[0];
       $menu     .= sprintf $renderer_template[1], $k, $v, $v, $k, $k eq $display ? ('', '') : ($tick, ' class="current"'), $v while ($k, $v) = splice @{$_->{'renderers'}}, 0, 2;
       $menu     .= $renderer_template[2];
    
    $headers_html[0] .= sprintf qq{<th class="$x"><p>$x</p>$select_all_col</th>}, $x, $x, $x, $x;
    $headers_html[2] .= qq{
      <th class="$x $name">
        <img class="menu_option" title="$renderers{$display}" alt="$renderers{$display}" src="${img_url}render/$display.gif">
        <input type="hidden" class="track_name" name="$name" value="$display">
        $menu
      </th>
    };
  }
  
  my $html = sprintf('
    <h1>%s</h1>
    <div class="toggle_tutorial"></div>
    <div class="header_wrapper">
      <h2>%s</h2> 
      <div class="sprite info_icon help" title="Click for more information">&nbsp;</div>
      <div class="desc">%s</div>
    </div>
    <div class="filter_wrapper">
      <h2>Filter by</h2>
      %s
      <input type="text" class="filter" value="Enter %s or %s" />
      <div class="tutorial fil"></div>
    </div>
    <div class="matrix_key">
      <h2>Key</h2>
      <div class="key"><div>On</div><div class="cell on"></div></div>
      <div class="key"><div>Off</div><div class="cell off"></div></div>
      <div class="key"><div>No Data</div><div class="cell disabled"></div></div>
      <div class="key"><h2>Filtered:</h2></div>
      <div class="key"><div>On</div><div class="cell on filter"><p></p></div></div>
      <div class="key"><div>Off</div><div class="cell off filter"><p></p></div></div>
    </div>
    <div class="config_matrix_scroller"><div></div></div>
    <div class="config_matrix_wrapper">
      <div class="tutorial track"></div>
      <div class="tutorial all_track"></div>
      <div class="tutorial col"></div>
      <div class="tutorial row"></div>
      <div class="tutorial drag"></div>
      <div style="width:%spx; margin-top: 50px">
        <table class="config_matrix" cellspacing="0" cellpadding="0">
          <thead>
            <tr><th class="first"></th>%s</tr>
            <tr class="renderers"><th class="first select_all"><div class="menu_option"><h2>Track style:</h2><em>Enable/disable all</em></div>%s</th>%s</tr>
          </thead>
          <tbody>
            %s
          </tbody>
        </table>
      </div>
      <div class="no_results">No results found</div>
    </div>
    ',
    $conf->{'section'},
    encode_entities($conf->{'header'}),
    $conf->{'description'},
    scalar keys %filters > 1 ? sprintf('<select class="filter">%s</select>', join '', map qq{<option value="$_">$filters{$_}</option>}, sort keys %filters) : '',
    map({ s/([a-z])([A-Z])([a-z])/$1_$2$3/g; s/_/ /g; lc; } $conf->{'axes'}{'x'}, $conf->{'axes'}{'y'}),
    $width,
    @headers_html,
    $rows_html
  );
  
  $self->get_form->append_children(
    [ 'div', { inner_HTML => $html, class => 'js_panel config_matrix', id => "${menu}_$set" }]
  );
}

1;
