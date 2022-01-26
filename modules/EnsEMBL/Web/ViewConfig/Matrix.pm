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

package EnsEMBL::Web::ViewConfig::Matrix;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use base qw(EnsEMBL::Web::ViewConfig);

# TODO: Support other track hub dimensions as filters?
# TODO - fix json key since it's moved to ViewConfigForm now

sub _new {
  ## @override
  ## TODO - re-bless existing view config instead of copying keys
  my $self  = shift->SUPER::_new(@_);
  my $hub   = $self->hub;
  my $code  = $hub->type.'::'.$hub->function;

  my $module_name = "EnsEMBL::Web::ViewConfig::$code";
  my $view_config = $module_name->new($hub, $hub->type, $self->component) if dynamic_require($module_name, 1);

  $self->{$_}     = $view_config->{$_} for keys %$view_config;
  $self->{'code'} = $code;

  return $self;
}

sub init_cacheable {};

sub init_form {
  my $self          = shift;
  my $hub           = $self->hub;
  my $img_url       = $self->species_defs->img_url;
  my $image_config  = $hub->get_imageconfig($self->image_config_type);
  my $user_settings = $image_config->get_user_settings;
  my $tree          = $image_config->tree;
  my $menu          = $hub->param('menu');
  my $menu_node     = $tree->get_node($menu);
  my $matrix_data   = $menu_node->data->{'matrix'};
  my @matrix_rows   = sort { $a->{'group_order'} <=> $b->{'group_order'} || lc ($a->{'group'} || 'zzzzz') cmp lc ($b->{'group'} || 'zzzzz') || lc $a->{'id'} cmp lc $b->{'id'} } values %{$matrix_data->{'rows'}};
  my @filters       = ([ '', 'All classes' ]);
  my (@columns, %renderer_counts, %cells, %features);

  $self->{'json'} = $self->form->{'json'} ||= {};

  foreach (@{$menu_node->child_nodes}) {
    my $x = $_->data->{'label_x'};

    if ($x) {
      my $renderers     = $_->data->{'renderers'};
      my %renderer_hash = @$renderers;

      push @columns, {
        name      => $_->id,
        display   => $_->get('display'),
        x         => $x,
        renderers => $renderers,
        column_order => $_->data->{'column_order'},
      };

      $cells{$x} = { map { $_->data->{'name'} => $_ } $_->nodes };
      $renderer_counts{$_}++ for keys %renderer_hash;
    } else {
      push @{$features{$_->data->{'option_key'}}}, $_;
    }
  }

  @columns = sort { $a->{'column_order'} <=> $b->{'column_order'} } @columns;

  %renderer_counts = reverse %renderer_counts;

  my $width = (scalar @columns * 26) + 107; # Each td is 25px wide + 1px border. The first cell (th) is 90px + 1px border + 16px padding-right
  my (@rows, $rows_html, @headers_html, $last_group, %gaps, $track_style_header, $k, $v, $renderer_html);

  $self->{'panel_type'} = 'ConfigMatrix';

  my $select_all_col = qq(
    <div class="select_all_column floating_popup">
      Select features for %s<br />
      <div><input type="radio" name="%s" class="default">Default</input></div>
      <div><input type="radio" name="%s" class="all">All</input></div>
      <div><input type="radio" name="%s" class="none">None</input></div>
    </div>
  );

  my $select_all_row = qq(
    <div class="select_all_row_wrapper">
      <div class="select_all_row floating_popup">
        Select all<br />
        %s
        <input type="checkbox" />
      </div>
    </div>
  );

  my @renderer_template = (
    qq(<ul class="popup_menu"><li class="header">Change track style<img class="close" src="${img_url}close.png" title="Close" alt="Close" /></li>),
    qq(<li class="%s">%s</li>),
    '</ul>'
  );

  if (scalar keys %renderer_counts != 1) {
    $renderer_html .= sprintf $renderer_template[1], @$_ for [ 'off', 'Off' ], [ 'all_on', 'On' ];
  } else {
    my @renderers      = @{$columns[0]{'renderers'}};
       $renderer_html .= sprintf $renderer_template[1], $k, $v, while ($k, $v) = splice @renderers, 0, 2;
  }

  $headers_html[1] = "$renderer_template[0]$renderer_html$renderer_template[2]";

  foreach (@matrix_rows) {
    my $id       = $_->{'id'};
    my $y        = $_->{'y'} || $id;
    my $group    = $_->{'group'};
    (my $y_class = lc $y)     =~ s/[^\w-]/_/g;
    (my $class   = lc $group) =~ s/[^\w-]/_/g;
    my @row      = ("$y_class $class", { tag => 'th', class => 'first', html => sprintf("$y$select_all_row", $y) });
    my $exists;

    foreach (@columns) {
      my $x            = $_->{'x'};
      (my $x_class     = lc $x) =~ s/[^\w-]/_/g;
      my $cell         = { tag => 'td' };
      my $col_renderer = $_->{'display'};

      if (exists $cells{$x}{$id}) {
        my $node          = $cells{$x}{$id};
        my $node_id       = $node->id;
        my $cell_features = exists $features{$node_id} && ref $features{$node_id} eq 'ARRAY' ? $features{$node_id} : undef;

        $cell->{'title'}  = "$x:$y";
        $cell->{'class'}  = "opt $x_class $y_class";
        $cell->{'class'} .= ' on'      if $node->get('display')    eq 'on';
        $cell->{'class'} .= ' default' if $node->data->{'display'} eq 'on';

        if ($cell_features) {
          # TODO: renderers. Currently assuming that subtrack renderers match parent renderers.
          my @renderers = @{$_->{'renderers'}};
          my $total     = scalar @$cell_features;
          my $on        = 0;
          my ($subtracks, $select_all);

          unshift @renderers, 'default', 'Default';

          foreach my $feature (@$cell_features) {
            my $feature_id = $feature->id;
            my $display    = $user_settings->{$feature_id}{'display'} || 'default';
            my $renderer   = $user_settings->{$feature_id}{'display'} || $col_renderer;
            my $li_class   = $renderer eq 'off' ? '' : ' on';
            my $popup_menu;

            for (my $i = 0; $i < scalar @renderers; $i += 2) {
              $popup_menu .= sprintf $renderer_template[1], $renderers[$i], ($renderers[$i] eq 'default' ? qq(<div class="$col_renderer"></div>) : '') . $renderers[$i + 1];
            }

            $subtracks .= sprintf(
              qq(<li id="$feature_id" class="$x_class$li_class $display track">%s$renderer_template[0]$popup_menu$renderer_template[2]<div class="$col_renderer"></div></li>),
              $feature->data->{'source_name'}
            );

            $on++ if $renderer ne 'off';
            $select_all ||= "$renderer_template[0]$popup_menu$renderer_template[2]";

            $self->{'json'}{'defaultRenderers'}{"$x:$id"}++ if $display eq 'default';
            push @{$self->{'json'}{'trackIds'}}, $feature_id;
            push @{$self->{'json'}{'tracks'}}, {
              id       => $feature_id,
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
            $total > 1 ? qq(<div class="select_all config_menu">$select_all<strong class="menu_option">Enable/disable all $cell->{'title'}</strong></div>) : '',
            $subtracks
          );

          $cell->{'html'}   = qq(<p><span class="off">0</span><span class="on">$on</span>$total</p>$cell->{'html'});
          $cell->{'class'} .= ' st';

          $track_style_header ||= 'Default';
        } else {
          $cell->{'html'} = '<p></p>';
        }

        $exists = 1;
      }

      push @row, $cell;
    }

    next unless $exists;

    if ($group ne $last_group) {
      # No versions of IE are capable of correctly drawing borders when there is an interaction between colspan on a cell and border-collapse, so we must draw empty cells instead of using colspan
      push @rows, [ 'gap' . ($group ? '' : ' empty'), { tag => 'th', html => $group, class => 'first' }, map { tag => 'th' }, @columns ];
      $gaps{$#rows} = 1;
      $last_group   = $group;

      push @filters, [ $class, $group ];
    }

    push @rows, \@row;
  }

  my $cols           = scalar @{$rows[0]} - 1;
  my $tutorial_col   = $cols > 5 ? 6 : $cols;
  my ($tutorial_row) = sort { $a <=> $b } 5, scalar(grep { $_->[0] !~ /gap/ } @rows) - 1;
  my $wrapper_class  = scalar @rows - $tutorial_row < 3 ? ' short' : '';

  $tutorial_row++ for grep { $_ < $tutorial_row } sort { $a <=> $b } keys %gaps;

  $track_style_header ||= 'Track';

  my %help      = $hub->species_defs->multiX('ENSEMBL_HELP');
  my %tutorials = (
    row       => 'Hover to select or deselect cells in the row',
    col       => 'Hover to select or deselect cells in the column',
    style     => sprintf('Click the boxes to choose %s style', lc $track_style_header),
    fil       => sprintf('%s search terms', scalar @filters > 1 ? sprintf 'Choose a filter class and/or enter' : 'Enter'),
    drag      => 'Click and drag with your mouse to turn on/off more than one box',
    all_track => 'Click to change all track styles at once',
    video     => sprintf('<a href="%s" class="popup">Click to view a tutorial video</a>', $hub->url({ type => 'Help', action => 'View', id => $help{'Config/Matrix'}, __clear => 1 })),
  );

  $tutorials{$_} = qq(<b class="tutorial $_"><span class="close"></span>$tutorials{$_}</b>) for keys %tutorials;

  if ($tutorial_row < 3) {
    my $margin = $tutorial_row == 0 ? 70 : 60;
    $tutorials{'row'} =~ s/row">/row" style="margin-top:${margin}px">/;
  }

  $rows[$tutorial_row][1]{'html'}                  = "$tutorials{'row'}$rows[$tutorial_row][1]{'html'}";
  $rows[$tutorial_row - 1][$tutorial_col]{'html'} .= $tutorials{'drag'};

  foreach (@rows) {
    my $row_class = shift @$_;
    my $row_html;

    foreach (@$_) {
      $row_html .= sprintf('<%s%s%s>%s</%s>',
        $_->{'tag'},
        $_->{'class'} ? qq( class="$_->{'class'}") : '',
        $_->{'title'} ? qq( title="$_->{'title'}") : '',
        $_->{'html'},
        $_->{'tag'}
      );
    }

    $rows_html .= qq(<tr class="$row_class">$row_html</tr>);
  }

  my $c = 0;

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
      qq(<th class="$x_class"><p>$x</p>$select_all_col%s</th>),
      $x, $x_class, $x_class, $x_class, $c == $tutorial_col - 2 ? $tutorials{'col'} : ''
    );

    # FIXME: don't double up class with id
    $headers_html[2] .= sprintf qq(<th id="$name" class="$x_class $name $display track%s">%s</th>), $display eq 'off' ? '' : ' on', $c++ ? '' : $tutorials{'style'};

    push @{$self->{'json'}{'trackIds'}}, $name;
    push @{$self->{'json'}{'tracks'}}, {
      id              => $name,
      renderer        => $display,
      rendererClasses => $classes,
      colClass        => $x_class,
      popup           => $popup_menu,
    };
  }

  my $html = sprintf(qq(
    <h1>$matrix_data->{'section'}</h1>
    <div class="toggle_tutorial"></div>
    $tutorials{'video'}
    <div class="header_wrapper">
      <h2>%s</h2>
      %s
    </div>
    <div class="filter_wrapper">
      <h2>Filter by</h2>
      %s
      <input type="text" class="filter" value="Enter terms to filter by" />
      $tutorials{'fil'}
    </div>
    <div class="config_matrix_scroller"><div></div></div>
    <div class="config_matrix_wrapper$wrapper_class">
    <div class="matrix_key">
      <h2>Key</h2>
      <div class="key"><div>Shown</div><div class="cell on"></div></div>
      <div class="key"><div>Hidden</div><div class="cell off"></div></div>
      <div class="key"><div>No Data</div><div class="cell disabled"></div></div>
      <div class="key"><h2>Filtered:</h2></div>
      <div class="key"><div>Shown</div><div class="cell filter on"><p></p></div></div>
      <div class="key"><div>Hidden</div><div class="cell off filter"><p></p></div></div>
    </div>

      <div class="table_wrapper" style="width:${width}px">
        <table class="config_matrix" cellspacing="0" cellpadding="0">
          <thead>
            <tr>
              <th class="first axes">%s</th>
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
    ),
    encode_entities($matrix_data->{'header'}),
    $matrix_data->{'description'} ? qq(<div class="sprite info_icon help" title="Click for more information">&nbsp;</div><div class="desc">$matrix_data->{'description'}</div>) : '',
    scalar @filters > 1 ? sprintf('<select class="filter">%s</select>', join '', map qq(<option value="$_->[0]">$_->[1]</option>), @filters) : '',
    $matrix_data->{'axes'} ? qq(<div><i class="x">$matrix_data->{'axes'}{'x'}</i><b class="x">&#9658;</b><i class="y">$matrix_data->{'axes'}{'y'}</i><b class="y">&#9660;</b></div>) : '',
    @headers_html
  );

  $self->form->append_child('div', { inner_HTML => $html, class => 'js_panel config_matrix', id => $menu });
}

1;
