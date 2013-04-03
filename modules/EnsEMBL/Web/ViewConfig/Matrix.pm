# $Id$

package EnsEMBL::Web::ViewConfig::Matrix;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::ViewConfig);

# TODO: Support other datahub dimensions as filters?

sub matrix_image_config :lvalue { $_[0]->{'matrix_image_config'}; }

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
  
  foreach (map values %$_, values %{$self->{'matrix_config'}}) {
    $_->{'columns'}  = [];
    $_->{'features'} = {};
  }
  
  $self->SUPER::reset(@_);
  $self->set_columns(@_);
}

sub set_columns {
  my ($self, $image_config) = @_;
  
  $self->matrix_image_config = ref $image_config ? $image_config : $self->hub->get_imageconfig($image_config);
  
  my $tree = $self->matrix_image_config->tree;
  
  foreach my $node (grep $_->data->{'label_x'}, $tree->nodes) {
    my $data      = $node->data;
    my $set       = $data->{'set'};
    my $label_x   = $data->{'label_x'};
    my $menu      = $tree->clean_id($data->{'menu_key'});
    my $renderers = $node->get('renderers');
    my %renderers = @$renderers;
    my $conf      = $self->{'matrix_config'}{$menu}{$set} ||= {
      menu         => $set,
      track_prefix => $menu,
      section      => $tree->get_node($menu)->get('caption'),
      header       => $data->{'header'},
      description  => $data->{'info'},
      axes         => $data->{'axes'},
    };
    
    push @{$conf->{'columns'}}, { name => $tree->clean_id(join '_', $conf->{'track_prefix'}, $set, $label_x), x => $label_x, display => $node->get('display'), renderers => $renderers };
    push @{$conf->{'features'}{$label_x}{$_}}, @{$data->{'features'}{$_}} for keys %{$data->{'features'}};
    $conf->{'renderers'}{$_}++ for keys %renderers;
  }
}

sub matrix_data {
  my ($self, $menu, $set) = @_;
  my %data = map { lc $_ => $_ } map keys %$_, values %{$self->{'matrix_config'}{$menu}{$set}{'features'}};
  return map { id => $data{$_} }, sort keys %data;
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
      
      my ($total, $on);
      
      foreach (grep ref, map values %$_, values %{$conf->{'features'}}) {
        foreach (@$_) {
          $total++;
          
          if ($self->get($_->{'option_key'}) eq 'on') {
            my $d = $image_config->get_node($_->{'name'})->get('display');
            $on++ if $d ne 'off' || ($d eq 'default' && $image_config->get_node($_->{'column_key'})->get('display') ne 'off');
          }
        }
      }
      
      $counts{$set} = {
        node  => $node,
        #total => $total || scalar @{$conf->{'columns'}}, # FIXME: get counts working properly in JS
        total => $total ? 0 : scalar @{$conf->{'columns'}},
        on    => $total ? $on : scalar grep $_->{'display'} ne 'off', @{$conf->{'columns'}}
      };
      
      if ($total) {
        my $parent = $node->parent_key;
        $counts{$parent}{'node'} ||= $node->parent_node;
        $counts{$parent}{'total'} = 0; # FIXME: get counts working properly in JS
        #$counts{$parent}{'total'} += $total;
        #$counts{$parent}{'on'}    += $on;
      }
      
      my $menu_data = {
        url          => $hub->url('Config', { function => 'Matrix', partial => 1, set => $set, menu => $menu }),
        class        => "${menu}_$set",
        availability => 1,
      };
      
      $node->set($_, $menu_data->{$_}) for keys %$menu_data;
    }
  }
  
  #$_->{'node'}->set('count', sprintf '(<span class="on">%s</span>/%s)', $_->{'on'} || 0, $_->{'total'}) for values %counts; # FIXME: get counts working properly in JS
  $_->{'node'}->set('count', $_->{'total'} ? sprintf '(<span class="on">%s</span>/%s)', $_->{'on'} || 0, $_->{'total'} : '') for values %counts;
}

sub form_matrix {
  my $self          = shift;
  my $hub           = $self->hub;
  my $set           = $hub->param('set');
  my $menu          = $hub->param('menu');
  my $image_config  = $self->matrix_image_config;
  my $user_settings = $image_config->get_user_settings;
  my $img_url       = $self->img_url;
  my $conf          = $self->{'matrix_config'}{$menu}{$set};
  my @columns       = @{$conf->{'columns'}};
  my @axis_labels   = map { s/([a-z])([A-Z])([a-z])/$1_$2$3/g; s/_/ /g; s/( [Tt]ype|s$)//g; lc; } $conf->{'axes'}{'x'}, $conf->{'axes'}{'y'};
  my $width         = (scalar @columns * 26) + 107; # Each td is 25px wide + 1px border. The first cell (th) is 90px + 1px border + 16px padding-right
  my %filters       = ( '' => 'All classes' );
  my (@rows, $rows_html, @headers_html, $last_class, %gaps, $track_style_header);
  
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
    qq{<li class="%s">%s</li>},
    '</ul>'
  );
  
  my %counts = reverse %{$conf->{'renderers'}};
  my ($k, $v, $renderer_html);
  
  if (scalar keys %counts != 1) {
    $renderer_html .= sprintf $renderer_template[1], @$_ for [ 'off', 'Off' ], [ 'all_on', 'On' ];
  } else {
    my $renderers = $self->deepcopy($conf->{'columns'}[0]{'renderers'});
    $renderer_html .= sprintf $renderer_template[1], $k, $v, while ($k, $v) = splice @$renderers, 0, 2;
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
    
    if ($last_class && $class ne $last_class) {
      push @rows, [ 'gap', { tag => 'td' }];
      $gaps{$#rows} = 1;
    }
    
    $last_class = $class;
    
    foreach (@columns) {
      my $x            = $_->{'x'};
      (my $x_class     = lc $x) =~ s/[^\w-]/_/g;
      my $cell         = { tag => 'td' };
      my $col_renderer = $_->{'display'};
      
      if (exists $conf->{'features'}{$x}{$id}) {
        my $on = $self->get("opt_matrix_${menu}_${set}_$x:$id") eq 'on';
        
        $cell->{'title'}  = "$x:$y";
        $cell->{'class'}  = "opt $x_class $y_class";
        $cell->{'class'} .= ' on'      if $on;
        $cell->{'class'} .= ' default' if $self->{'options'}{"opt_matrix_${menu}_${set}_$x:$id"}{'default'} eq 'on';
        
        if (ref $conf->{'features'}{$x}{$id} eq 'ARRAY') {
          # TODO: renderers. Currently assuming that subtrack renderers match parent renderers.
          my @renderers = @{$self->deepcopy($_->{'renderers'})};
          my $total     = scalar @{$conf->{'features'}{$x}{$id}};
          my $on        = 0;
          my ($subtracks, $select_all);
          
          unshift @renderers, 'default', 'Default';
          
          foreach my $feature (@{$conf->{'features'}{$x}{$id}}) {
            my $display  = $user_settings->{$feature->{'name'}}{'display'} || 'default';
            my $renderer = $user_settings->{$feature->{'name'}}{'display'} || $col_renderer;
            my $li_class = $renderer eq 'off' ? '' : ' on';
            my $popup_menu;
            
            for (my $i = 0; $i < scalar @renderers; $i += 2) {
              $popup_menu .= sprintf $renderer_template[1], $renderers[$i], ($renderers[$i] eq 'default' ? qq{<div class="$col_renderer"></div>} : '') . $renderers[$i+1];
            }
            
            $subtracks .= sprintf(
              qq{<li id="$feature->{'name'}" class="$x_class$li_class $display track">%s$renderer_template[0]$popup_menu$renderer_template[2]$feature->{'source_name'}</li>},
              $display eq 'default' ? qq{<div class="$col_renderer"></div>} : ''
            );
            
            $on++ if $renderer ne 'off';
            $select_all ||= "$renderer_template[0]$popup_menu$renderer_template[2]";
            
            $self->{'json'}{'defaultRenderers'}{"$x:$id"}++ if $display eq 'default';
            push @{$self->{'json'}{'trackIds'}}, $feature->{'name'};
            push @{$self->{'json'}{'tracks'}}, {
              id       => $feature->{'name'},
              renderer => $display,
            };
          }
          
          $self->{'json'}{'defaultRenderers'}{"$x:$id"} ||= 0;
          $self->{'json'}{'cellTracks'}{"$x:$id"}         = sprintf('
            <div class="subtracks info_popup">
              <span class="close"></span>
              %s
              <ul class="config_menu">%s</ul>
            </div>',
            $total > 1 ? qq{<div class="select_all config_menu">$select_all<strong class="menu_option">Enable/disable all $cell->{'title'}</strong></div>} : '',
            $subtracks
          );
          
          $cell->{'html'}   = qq{<p><span class="on">$on</span>$total</p>$cell->{'html'}};
          $cell->{'class'} .= ' st';
          
          $track_style_header ||= 'Default';
        } else {
          $cell->{'html'} = '<p></p>';
        }
        
        $exists = 1;
      }
      
      push @row, $cell;
    }
    
    if ($exists) {
      push @rows, \@row;
      $filters{$cls} = $class if $class;
    }
  }
  
  my $cols           = scalar @{$rows[0]} - 1;
  my $tutorial_col   = $cols > 5 ? 6 : $cols;
  my ($tutorial_row) = sort { $a <=> $b } 5, scalar grep { $_->[0] ne 'gap' } @rows;
  my $wrapper_class  = scalar @rows - $tutorial_row < 3 ? ' short' : '';
  
  $tutorial_row++ for grep { $_ < $tutorial_row } sort { $a <=> $b } keys %gaps;
  
  $track_style_header ||= 'Track';
  
  my %tutorials = (
    row       => sprintf('Hover on %s names to select or deselect %s types', @axis_labels),
    col       => sprintf('Hover on %s names to select or deselect %s types', reverse @axis_labels),
    style     => sprintf('Click the boxes to choose %s style', lc $track_style_header),
    fil       => sprintf('%s %s or %s type search terms', scalar keys %filters > 1 ? sprintf 'Choose a%s %s class and/or enter', $axis_labels[1] =~ /^[aeiou]/ ? 'n' : '', $axis_labels[1] : 'Enter', @axis_labels),
    drag      => 'Click and drag with your mouse to turn on/off more than one box',
    all_track => 'Click to change all track styles at once',
  );
  
  $tutorials{$_} = qq{<b class="tutorial $_">$tutorials{$_}</b>} for keys %tutorials;
  
  $rows[$tutorial_row][1]{'html'}                  = "$tutorials{'col'}$rows[$tutorial_row][1]{'html'}";
  $rows[$tutorial_row - 1][$tutorial_col]{'html'} .= $tutorials{'drag'};
  
  foreach (@rows) {
    my $row_class = shift @$_;
    my $row_html;
    
    foreach (@$_) {
      $row_html .= sprintf('<%s%s%s>%s</%s>',
        $_->{'tag'},
        $_->{'class'} ? qq{ class="$_->{'class'}"} : '',
        $_->{'title'} ? qq{ title="$_->{'title'}"} : '',
        $_->{'html'},
        $_->{'tag'}
      );
    }
    
    $rows_html .= qq{<tr class="$row_class">$row_html</tr>};
  }
  
  my $i = 0;
  
  foreach (@columns) {
    my $x           = $_->{'x'};
    (my $x_class    = lc $x) =~ s/[^\w-]/_/g;
    my $display     = $_->{'display'};
    my $name        = $_->{'name'};
    my $i           = 0;
    my $classes     = join ' ', grep { ++$i % 2 } @{$_->{'renderers'}};
    my $popup_menu  = $renderer_template[0];
       $popup_menu .= sprintf $renderer_template[1], $k, $v while ($k, $v) = splice @{$_->{'renderers'}}, 0, 2;
       $popup_menu .= $renderer_template[2];
    
    $headers_html[0] .= sprintf(
      qq{<th class="$x_class"><p>$x</p>$select_all_col%s</th>},
      $x, $x_class, $x_class, $x_class, $i == $tutorial_col - 2 ? $tutorials{'row'} : ''
    );
    
    # FIXME: don't double up class with id
    $headers_html[2] .= sprintf qq{<th id="$name" class="$x_class $name $display track%s">%s</th>}, $display eq 'off' ? '' : ' on', $i++ ? '' : $tutorials{'track'};
    
    push @{$self->{'json'}{'trackIds'}}, $name;
    push @{$self->{'json'}{'tracks'}}, {
      id              => $name,
      renderer        => $display,
      rendererClasses => $classes,
      colClass        => $x_class,
      popup           => $popup_menu,
    };
  }
  
  my $html = sprintf(qq{
    <h1>$conf->{'section'}</h1>
    <div class="toggle_tutorial"></div>
    <div class="header_wrapper">
      <h2>%s</h2> 
      <div class="sprite info_icon help" title="Click for more information">&nbsp;</div>
      <div class="desc">$conf->{'description'}</div>
    </div>
    <div class="filter_wrapper">
      <h2>Filter by</h2>
      %s
      <input type="text" class="filter" value="Enter %s or %s type" />
      $tutorials{'fil'}
    </div>
    <div class="matrix_key">
      <h2>Key</h2>
      <div class="key"><div>On</div><div class="cell on"></div></div>
      <div class="key"><div>Off</div><div class="cell off"></div></div>
      <div class="key"><div>No Data</div><div class="cell disabled"></div></div>
      <div class="key"><h2>Filtered:</h2></div>
      <div class="key"><div>On</div><div class="cell filter on"><p></p></div></div>
      <div class="key"><div>Off</div><div class="cell off filter"><p></p></div></div>
    </div>
    <div class="config_matrix_scroller"><div></div></div>
    <div class="config_matrix_wrapper$wrapper_class">
      <div class="table_wrapper" style="width:${width}px; margin-top: 50px">
        <table class="config_matrix" cellspacing="0" cellpadding="0">
          <thead>
            <tr>
              <th class="first"></th>
              %s
            </tr>
            <tr class="config_menu">
              <th class="first select_all">
                <div class="menu_option"><h2>$track_style_header style:</h2><em>Enable/disable all</em></div>
                %s
                $tutorials{'all_track'}
              </th>
              %s
            </tr>
          </thead>
          <tbody>
            $rows_html
          </tbody>
        </table>
      </div>
      <div class="no_results">No results found</div>
    </div>
    },
    encode_entities($conf->{'header'}),
    scalar keys %filters > 1 ? sprintf('<select class="filter">%s</select>', join '', map qq{<option value="$_">$filters{$_}</option>}, sort keys %filters) : '',
    @axis_labels,
    @headers_html
  );
  
  $self->get_form->append_child('div', { inner_HTML => $html, class => 'js_panel config_matrix', id => "${menu}_$set" });
}

1;
