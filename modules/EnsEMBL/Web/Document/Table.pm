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

package EnsEMBL::Web::Document::Table;

use strict;

use JSON qw(from_json);
use Scalar::Util qw(looks_like_number);
use HTML::Entities qw(encode_entities);

use EnsEMBL::Draw::Utils::ColourMap;
use EnsEMBL::Web::Attributes;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $cols, $rows, $options, $spanning) = @_;
  
  $cols     ||= [];
  $rows     ||= [];
  $options  ||= {};
  $spanning ||= [];
  
  my $self = {
    columns    => $cols,
    rows       => $rows,
    options    => $options,
    spanning   => $spanning,
    format     => 'HTML',
  };
  
  bless $self, $class;
  
  $self->preprocess_widths;
  $self->preprocess_hyphens;
  
  return $self;
}

sub hub :AccessorMutator;
sub code       :lvalue { $_[0]{'code'}        }
sub format     :lvalue { $_[0]{'format'};     }
sub filename   :lvalue { $_[0]{'filename'};   }

sub has_rows { return ! !@{$_[0]{'rows'}}; }

sub preprocess_widths {
  my $self           = shift;
  my $perc_remaining = 100;
  my $units_used     = 0;
  my @unitcols;
  
  foreach my $column (@{$self->{'columns'}}) {
    local $_  = $column->{'width'};
    my $units = -1;
    
    if (/(\d+)%/) {
      $perc_remaining -= $1;
    } elsif (/(\d+)px/) {
      return;
    } elsif (/(\d+)u/) {
      $units_used += $1;
      push @unitcols, { units => $1, column => $column, percent => 0 };
    }
  }
  
  return unless $units_used;
  
  # careful alg. to avoid 99%, 101% tables due to rounding.
  my $perc_per_unit = $perc_remaining / $units_used;
  my $total         = -0.5; # correct for rounding bias
  
  foreach (@unitcols) {
    $_->{'total'} = $_->{'units'} * $perc_per_unit + $total;
    $total       += $_->{'units'} * $perc_per_unit;
  }
  
  my $col = 0;
  
  for (my $i = 0; $i < $perc_remaining; $i++) {
    $col++ if $i > $unitcols[$col]->{'total'} && $col < @unitcols;
    $unitcols[$col]->{'percent'}++;
  }
  
  $_->{'column'}{'width'} = "$_->{'percent'}%" for @unitcols;
}

# \f -- optional hyphenation point
# \a -- optional break point (no hyphen)
sub hyphenate {
  my ($self, $data, $key) = @_;

  return unless exists $data->{$key};
  
  my $any = ($data->{$key} =~ s/\f/&shy;/g | $data->{$key} =~ s/\a/&#8203;/g);
  
  return $any;
}

sub preprocess_hyphens {
  my $self = shift;

  foreach (@{$self->{'columns'}}) {
    my $h = $_->{'label'} ? $self->hyphenate($_, 'label') : 0;
    $_->{'class'} .= ' hyphenated' if $h;
  }
}

sub export_options {
  my $self  = shift;
  my $index = -1;
  my @options;
  
  foreach (@{$self->{'columns'}}) {
    $index++;
    $options[$index] = $_->{'export_options'} if defined $_->{'export_options'};
  }

  return $self->jsonify(\@options);
}

sub render {
  my $self = shift;
  
  return unless @{$self->{'columns'}};
  
  my $func = 'render_' . $self->format;
  
  return $self->$func if $self->can($func);
  
  my $options     = $self->{'options'}        || {};
  my $style       = [ split(';', $options->{'style'} || ''), $options->{'margin'} ? "margin: $options->{'margin'}" : ()];
  my $width       = $options->{'width'}       || '100%';
  my $padding     = $options->{'cellpadding'} || 0;
  my $spacing     = $options->{'cellspacing'} || 0;
  my $align       = $options->{'align'}       || 'autocenter';
  my $table_id    = $options->{'id'} ? qq( id="$options->{'id'}" ) : '';
  my $data_table  = $options->{'data_table'};
  my $toggleable  = $options->{'toggleable'};
  my %table_class = map { $_ => 1 } split ' ', $options->{'class'};
  my $config;
  
  if ($table_class{'fixed_width'}) {
    $width = 'auto';
    $align = '';
  }
  
  $table_class{$align}         = 1 if $align;
  $table_class{'toggle_table'} = 1 if $toggleable;
  $table_class{'toggleable'}   = 1 if $toggleable && !$data_table;
  $table_class{'ss'}           = 1;
  
  if ($data_table) {
    $table_class{'data_table'} = 1;
    $table_class{$data_table}  = 1 if $data_table =~ /[a-z]/i;
    $table_class{'exportable'} = 1 unless $options->{'exportable'} eq '0';
    $config = $self->data_table_config;
  }
  
  my $class   = join ' ', keys %table_class;
  my $wrapper = join ' ', grep $_, $options->{'wrapper_class'}, $width ne '100%' && $table_class{'autocenter'} ? 'autocenter_wrapper' : '', $toggleable && $options->{'id'} ? $options->{'id'} : '';
  my ($head, $body) = $self->process;
  my ($thead, $tbody);
  
  if ($options->{'header'} ne 'no') {
    if (scalar @{$self->{'spanning'}}) {
      $thead .= '<tr class="ss_header">';
      
      foreach my $header (@{$self->{'spanning'}}) {
        my $span = $header->{'colspan'} || 1;
        $thead .= sprintf q(<th colspan="%s"><em>%s</em></th>), $span, encode_entities($header->{'title'});
      }
      
      $thead .= '</tr>';
    }
    
    $thead .= sprintf '<tr%s>%s</tr>', $head->[1], join('', @{$head->[0]});
  }

  if ($options->{'header_repeat'} && !$data_table) { ## can't use both these options together
    my $repeat = $options->{'header_repeat'};
    my $i      = 1;
    
    foreach (@$body) {
      $tbody .= sprintf '<tr%s>%s</tr>', $_->[1], join('', @{$_->[0]});
      $tbody .= $thead unless ($i % $repeat);
      $i++;
    }
  } else { 
    $tbody = join '', map { sprintf '<tr%s>%s</tr>', $_->[1], join('', @{$_->[0]}) } @$body;
  }
   
  $thead  = "<thead>$thead</thead>" if $thead;
  $tbody  = "<tbody>$tbody</tbody>" if $tbody;
  $style  = join ';', @$style, "width: $width";
  
  my $table = qq(
    <table$table_id class="$class" style="$style" cellpadding="$padding" cellspacing="$spacing">
      $thead
      $tbody
    </table>
    $config
  );
  
  if ($data_table && $options->{'exportable'} ne '0') {
    my $id       = $options->{'id'};
       $id       =~ s/[\W_]table//g;
    my $filename = join '-', grep $_, $id, $self->filename;
    my $options  = sprintf '<input type="hidden" name="expopts" value="%s" />', encode_entities($self->export_options);
    
    $table .= qq{
      <form class="data_table_export" action="/Ajax/table_export" method="post">
        <input type="hidden" name="filename" value="$filename" />
        <input type="hidden" class="data" name="data" value="" />
        $options
      </form>
    };
  }
   
  # A wrapper div is needed for data tables so that export and config forms can be found by checking the table's siblings
  if ($data_table) {
    $wrapper = qq{ class="$wrapper"} if $wrapper; 
    $table   = qq{<div$wrapper>$options->{'wrapper_html'}$table</div>};
  }
  
  return $table;
}

sub render_Text {
  my $self = shift;
  
  return unless @{$self->{'columns'} || []};
  
  my ($head, $body) = $self->process;
  my $output;
  
  foreach my $row ([ @$head ], @$body) {
    $output .= sprintf qq{%s\n}, join "\t", map $self->strip_HTML($_), @{$row->[0]};
  }
  
  return $output;
}

sub _strip_outer_HTML {
  my $self = shift;
  local $_ = shift;
  
  s/^\s*<.*?>//;
  s/<.*?>\s*$//;
  
  return $_;
}

sub render_JSON {
  my $self = shift;
  
  return unless @{$self->{'columns'} || []};
  
  my ($head, $body) = $self->process;
  my @json;
  
  foreach my $row ([ @$head ], @$body) {
    push @json, [ map $self->_strip_outer_HTML($_), @{$row->[0]} ];
  }
  
  return $self->jsonify(\@json);
}

sub render_Excel {
  my $self = shift;
  
  return unless @{$self->{'columns'} || []};
  
  my $options = $self->{'options'} || {};
  my $align   = $options->{'align'} ? $options->{'align'} : 'autocenter';
  my $width   = $options->{'width'} ? $options->{'width'} : '100%';
  my ($head, $body) = $self->process;
  my $output;
  
  foreach my $row ([ @$head ], @$body) {
    $output .= sprintf qq{"%s"\n}, join '","', map $self->csv_escape($_), @{$row->[0]};
  }
  
  return $output;
}

sub csv_escape {
  my $self  = shift;
  my $value = $self->strip_HTML(shift);
     $value =~ s/"/""/g;
     $value =~ s/^\s+|\s+$//g; # trim white space on both ends of the string
  
  return $value;
}

# Returns a hidden input used to configure the sorting options for a javascript data table
sub data_table_config {
  my $self      = shift;
  my $code      = $self->code;
  my $col_count = scalar @{$self->{'columns'}};
  
  return unless $code && $col_count;
  
  my $i              = 0;
  my %columns        = map { $_->{'key'} => $i++ } @{$self->{'columns'}};
  my $record_data    = $code && $self->hub ? $self->hub->session->get_record_data({type => 'data_table', code => $code}) : {};
  my $sorting        = $record_data->{'sorting'} ?        from_json($record_data->{'sorting'})        : $self->{'options'}{'sorting'}        || [];
  my $hidden_cols    = [ keys %{{ map { $_ => 1 } @{$self->{'options'}{'hidden_columns'} || []}, map { $_->{'hidden'} ? $columns{$_->{'key'}} : () } @{$self->{'columns'}} }} ];
  my $hidden         = $record_data->{'hidden_columns'} ? from_json($record_data->{'hidden_columns'}) : $hidden_cols;
  my $config         = sprintf '<input type="hidden" name="code" value="%s" />', encode_entities($code);
  my $sort           = [];

  foreach (@$sorting) {
    my ($col, $dir) = split / /;
    $col = $columns{$col} unless $col =~ /^\d+$/ && $col < $col_count;
    push @$sort, [ $col, $dir ] if defined $col;
  }
  
  if (scalar @$sort) {
    $config .= sprintf '<input type="hidden" name="aaSorting" value="%s" />', encode_entities($self->jsonify($sort));
  }

  if (scalar @$hidden) {
    $config .= sprintf '<input type="hidden" name="hiddenColumns" value="%s" />', encode_entities($self->jsonify($hidden));
  }

  foreach (keys %{$self->{'options'}{'data_table_config'}}) {
    my $option = $self->{'options'}{'data_table_config'}{$_};
    my $val;
    
    if (ref $option) {
      $val = encode_entities($self->jsonify($option));
    } else {
      $val = $option;
    }
    
    $config .= qq(<input type="hidden" name="$_" value="$val" />);
  }
  
  $config .= sprintf '<input type="hidden" name="expopts" value="%s" />', encode_entities($self->export_options);
 
  return qq{<div class="data_table_config">$config</div>};
}

sub process {
  my $self        = shift;
  my $columns     = $self->{'columns'};
  my @row_colours = $self->{'options'}{'data_table'} ? () : exists $self->{'options'}{'rows'} ? @{$self->{'options'}{'rows'}} : ('bg1', 'bg2');
  my $heatmap     = $self->{'options'}{'heatmap'};
  my (@head, @body, $colourmap, @gradient);
  
  if ($heatmap) {
    $colourmap = EnsEMBL::Draw::Utils::ColourMap->new;
    @gradient  = $colourmap->build_linear_gradient(@{$heatmap->{'settings'}});
  } 
  
  foreach my $col (@$columns) {
    my $label = exists $col->{'label'} ? $col->{'label'} : exists $col->{'title'} ? $col->{'title'} : $col->{'key'};
    my %style = $col->{'style'} ? ref $col->{'style'} eq 'HASH' ? %{$col->{'style'}} : map { s/(^\s+|\s+$)//g; split ':' } split ';', $col->{'style'} : ();
    
    $style{'text-align'} ||= $col->{'align'} if $col->{'align'};
    $style{'width'}      ||= $col->{'width'} if $col->{'width'};
    
    $col->{'style'}  = join ';', map { join ':', $_, $style{$_} } keys %style;
    $col->{'class'} .= ($col->{'class'} ? ' ' : '') . "sort_$col->{'sort'}" if $col->{'sort'};
    
    if ($col->{'help'}) {
      delete $col->{'title'};
      $label = sprintf '<span class="ht _ht"><span class="_ht_tip hidden">%s</span>%s</span>', encode_entities($col->{'help'}), $label;
    }

    if ($col->{'extra_HTML'}) {
      $label .= $col->{'extra_HTML'};
    }
    
    push @{$head[0]}, sprintf '<th%s>%s</th>', join('', map { $col->{$_} ? qq( $_="$col->{$_}") : () } qw(id class title style colspan rowspan)), $label;
  }
      
  $head[1] = ' class="ss_header"';
  
  foreach my $row (@{$self->{'rows'}}) {
    my ($options, @cells) = ref $row eq 'HASH' ? ($row->{'options'}, map $row->{$_->{'key'}}, @$columns) : ({}, @$row);
    my $i = 0;
    
    if (scalar @row_colours) {
      $options->{'class'} .= ($options->{'class'} ? ' ' : '') . $row_colours[0];
      push @row_colours, shift @row_colours
    }
    
    foreach my $cell (@cells) {
      $cell = { value => $cell } unless ref $cell eq 'HASH';
      
      my %style = $cell->{'style'} ? ref $cell->{'style'} eq 'HASH' ? %{$cell->{'style'}} : map { s/(^\s+|\s+$)//g; split ':' } split ';', $cell->{'style'} : ();
      
      $style{'text-align'} ||= $columns->[$i]{'align'} if $columns->[$i]{'align'};
      $style{'width'}      ||= $columns->[$i]{'width'} if $columns->[$i]{'width'};
      
      if ($heatmap && looks_like_number($cell->{'value'})) {
        my $i = abs($cell->{'value'} * $heatmap->{'settings'}[0]);
        
        $style{'background-color'} = "#$gradient[$i]";
        
        if ($heatmap->{'mode'} eq 'text') {
          my ($r, $g, $b) = $colourmap->rgb_by_hex($gradient[$i]);
          my $brightness  = (($r * 299) + ($g * 587) + ($b * 114)) / 1000;
          $style{'color'} = $brightness > 120 ? '#000000' : '#FFFFFF';
        } else {
          $style{'color'} = 'transparent';
        }
      } 

      $cell->{'style'} = join ';', map { join ':', $_, $style{$_} } keys %style;

      $cell = sprintf '<td%s>%s</td>', join('', map { $cell->{$_} ? qq( $_="$cell->{$_}") : () } qw(id class title style colspan rowspan)), $cell->{'value'};
      
      $i++;
    }
    
    push @body, [ \@cells, join('', map { $options->{$_} ? qq( $_="$options->{$_}") : () } qw(id class style valign)) ];
  }
  
  return (\@head, \@body);
}

sub add_option {
  my $self = shift;
  my $key  = shift;
  
  if ($key eq 'class') {
    $self->{'options'}{'class'} .= ($self->{'options'}{'class'} ? ' ' : '') . $_[0];
  } elsif (ref $self->{'options'}{$key} eq 'HASH') {
    $self->{'options'}{$key} = { %{$self->{'options'}{$key}}, %{$_[0]} };
  } elsif (ref $self->{'options'}{$key} eq 'ARRAY') {
    push @{$self->{'options'}{$key}}, @_;
  } elsif (scalar @_ == 1) {
    $self->{'options'}{$key} = ref $_[0] eq 'ARRAY' ? [ $_[0] ] : $_[0];
  } else {
    $self->{'options'}{$key} = \@_;
  }
}

sub add_columns {
  my $self = shift;
  push @{$self->{'columns'}}, @_;
}

sub add_spanning_headers {
  my $self = shift;
  push @{$self->{'spanning'}}, @_;
}

sub add_row {
  my ($self, $data) = @_;
  push @{$self->{'rows'}}, $data;
}

sub add_rows {
  my $self = shift;
  push @{$self->{'rows'}}, @_;
}
   
1;
