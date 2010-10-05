# $Id$

package EnsEMBL::Web::Document::SpreadSheet;

use strict;

use base qw(EnsEMBL::Web::Root);

# All now configured by the component
sub new {
  my ($class, $c, $d, $o, $s) = @_;
  
  $c ||= [];
  $d ||= [];
  $o ||= {};
  $s ||= [];
  
  my $self = {
    _columns  => $c,
    _data     => $d,
    _options  => $o,
    _spanning => $s
  };
  
  bless $self, $class;
}

sub has_rows { return !!@{$_[0]->{'_data'}}; }

sub render {
  my $self = shift;
  
  return unless @{$self->{'_columns'} || []};
  
  my $options = $self->{'_options'}       || {};
  my $width   = $options->{'width'}       || '100%';
  my $margin  = $options->{'margin'}      || '0px';
  my $padding = $options->{'cellpadding'} || 0;
  my $spacing = $options->{'cellspacing'} || 0;
  
  my $table_class = 'ss ' . ($options->{'align'} || 'autocenter');
  my $config;
  
  if ($options->{'data_table'}) {
    $table_class .= ' data_table';
    $table_class .= " $options->{'data_table'}" if $options->{'data_table'} =~ /[a-z]/i;
    $config      .= $self->sort_config;
  }
  
  my %elements = ( thead => '', tbody => '', tfoot => '');
  
  if (scalar @{$self->{'_spanning'}}) {
    $elements{'thead'} .= qq{\n  <tr class="ss_header">};
    
    foreach my $header (@{$self->{'_spanning'}}) {
      my $span = $header->{'colspan'} || 1;
      $elements{'thead'} .= qq{<th colspan="$span"><em>$header->{'title'}</em></th>};
    }
    
    $elements{'thead'} .= "</tr>\n";
  }

  foreach my $row (@{$self->_process}) {
    my $tag    = 'td';
    my $output = 'tbody';
    
    if ($row->{'style'} eq 'header') {
      $elements{'thead'} .= qq{\n  <tr class="ss_header">};
      $tag    = 'th';
      $output = 'thead';
    } elsif ($row->{'style'} eq 'total') {
      $elements{'tfoot'} .= "\n  <tr>";
      $tag    = 'th';
      $output = 'tfoot';
    } else {
      my $valign = $row->{'valign'} || 'top';
      my $class  = $row->{'class'} ? qq{ class="$row->{'class'}"} : '';
      
      $elements{'tbody'} .= qq{\n  <tr style="vertical-align:$valign"$class>};
    }
    
    foreach my $cell (@{$row->{'cols'}}) {
      my $extra = $cell->{'class'}   ? qq{ class="$cell->{'class'}"}     : '';
      $extra   .= $cell->{'style'}   ? qq{ style="$cell->{'style'}"}     : '';
      $extra   .= $cell->{'colspan'} ? qq{ colspan="$cell->{'colspan'}"} : '';
      
      my $val = defined $cell->{'value'} && $cell->{'value'} ne '' ? $cell->{'value'} : ' ';
         
      $elements{$output} .= "\n    <$tag$extra>$val</$tag>";
    }

    $elements{$output} .= "\n  </tr>";
  }
  
  $elements{$_} = "<$_>$elements{$_}</$_>" for grep $elements{$_}, keys %elements;
  $config       = qq{<form class="data_table_config">$config</form>} if $config;
  
  # Yes, tfoot does come before tbody. Confusing I know, but that's the spec.
  my $table = qq{
    <table class="$table_class" style="width:$width;margin:$margin" cellpadding="$padding" cellspacing="$spacing">
      $elements{'thead'}
      $elements{'tfoot'}
      $elements{'tbody'}
    </table>
    $config
  };
  
  $table = qq{<div class="autocenter_wrapper">$table</div>} if $width ne '100%' && $table_class =~ /\s*autocenter\s*/;
  
  return $table;
}

sub render_Text {
  my $self    = shift;
  
  return unless @{$self->{'_columns'} || []};
  
  my $options = $self->{'_options'} || {};
  my $align   = $options->{'align'} ? $options->{'align'} : 'autocenter';
  my $width   = $options->{'width'} ? $options->{'width'} : '100%';

  my $output = '';
  
  $self->sort_config if $options->{'data_table'};
  
  foreach my $row (@{$self->_process}) {
    $output .= join "\t", map $self->strip_HTML($_->{'value'}), @{$row->{'cols'}};
    $output .= "\n";
  }
  
  return $output;
}

# Returns a hidden input used to configure the sorting options for a javascript data table
sub sort_config {
  my $self = shift;
  
  return unless $self->{'_options'}->{'sorting'} && scalar @{$self->{'_data'}} && scalar @{$self->{'_columns'}};
  
  my $i = 0;
  my %columns = map { $_->{'key'} => [ $_->{'sort'}, $i++ ] } @{$self->{'_columns'}};
  my @config;
  
  foreach (@{$self->{'_options'}->{'sorting'}}) {
    my ($col, $dir) = split / /;
    
    if (ref $columns{$col}) {
      push @config, [ $columns{$col}->[1], $dir ];
      $columns{$col} = $columns{$col}->[0];
    }
  }
  
  (my $value = $self->jsonify(\@config)) =~ s/"/'/g;
  return qq{<input type="hidden" name="aaSorting" value="$value" />};
}

sub _process {
  my $self = shift;

  my $counter = 0;
  my $data    = $self->{'_data'}    || [];
  my $columns = $self->{'_columns'} || [];
  my $options = $self->{'_options'} || {};

  my $no_cols = @$columns;
  
  # Start the table...
  my $return = [];
  
  foreach (0..($no_cols-1)) {
    my $col = $columns->[$_];
    $col = $columns->[$_] = { key => $col } unless ref $col eq 'HASH';
    $counter++;
  }

  # Draw the header row unless the "header" options is set to "no"
  if ($options->{'header'} ne 'no') {
    $counter = 0;
    my $border;
    my $row = { style => 'header', cols => [] };
    my $average = int(100 / scalar $columns);
    
    foreach (@$columns) {
      push @{$row->{'cols'}}, {
        style => 'text-align:' . ($options->{'alignheader'} || $_->{'align'} || 'auto') . ';width:' . ($_->{'width'} || $average . '%'), 
        value => defined $_->{'title'} ? $_->{'title'} : $_->{'key'}, 
        class => $_->{'class'} . ($_->{'sort'} ? " sort_$_->{'sort'}" : '')
      };
    }
    
    push @$return, $row;
  }

  # Display each row in the table
  my $row_count    = 0;  
  my @previous_row = ();
  my @totals       = ();
  my $row_colours  = $options->{'data_table'} ? [] : exists $options->{'rows'} ? $options->{'rows'} : [ 'bg1', 'bg2' ];
  
  foreach my $row (@$data) {
    my $flag = 0;
    my $out_row = { style => 'row', class => $row_colours->[0], col => [] };
    $counter = 0;
    
    foreach my $col (@$columns) {
      my $value        = $self->get_value($row, $counter, $col->{'key'});
      my $hidden_value = lc (exists $col->{'hidden_key'} ? $self->get_value($row, $counter, $col->{'hidden_key'}) : $value);
      my $style        = exists $col->{'align'} ? "text-align:$col->{'align'};" : ($col->{'type'} eq 'numeric' ? 'text-align:right;' : '');
      $style          .= exists $col->{'width'} ? "width:$col->{'width'};" : '';
      $style          .= $options->{'row_style'}->[$row_count]->[$counter] if exists $options->{'row_style'} && $options->{'row_style'}->[$row_count];
      
      if ($flag == $counter && $hidden_value eq $previous_row[$counter]) {
        $flag  = $counter + 1;
        $value = '' if $options->{'triangular'};
      }
      
      $previous_row[$counter] = $hidden_value;
      
      my $val = $value;
      my $f   = $col->{'format'};
      
      if ($value ne '' && $f) {
        if (ref $f eq 'CODE') {
          $val = $f->($value, $row);
        } elsif ($self->can($f)) {
          $val = $self->$f($value, $row);
        }
      }
      
      push @{$out_row->{'cols'}}, { 
        value => $val,
        style => $style
      };
      
      $counter++;
    }
    
    next if $flag == $counter; # SKIP WHOLLY BLANK LINES
    
    push @$row_colours, shift @$row_colours;

    $row_count++;
    
    if ($options->{'total'} > 0) { # SUMMARY TOTALS
      if ($flag < $options->{'total'}) {
        for (my $i = $options->{'total'} - 1; $i > $flag; $i--) {
          next unless @totals;
          
          my $TOTAL_ROW = pop @totals;
          my $total_row = { style => 'total', cols => [] };
          my $counter   = 0;
          
          foreach my $col (@$columns) {
            my $value = '';
            my $style = '';
            
            if ($counter == @totals) {
              $value = 'TOTAL';
            } elsif ($counter > @totals && $col->{'type'} eq 'numeric') {
              $style = 'text-align:right';
              $value = $self->thousandify($TOTAL_ROW->[$counter]);
            }
            
            push @{$total_row->{'cols'}}, { value => $value, style => $style };
            
            $counter++;
          }
          
          push @$return, $total_row;
        }
      }
      
      my $counter = 0;
      
      foreach my $col (@$columns) {
        if ($col->{'type'} eq 'numeric') {
          my $value = $self->get_value($row, $counter, $col->{'key'});
            
          for (my $i = 0; $i < $options->{'total'}; $i++) {
            $totals[$i][$counter] += $value;
          }
        }
        
        $counter++;
      }
    }
    
    push @$return, $out_row;
  }
  
  if ($options->{'total'} > 0) { # SUMMARY TOTALS
    while (@totals) {
      my $TOTAL_ROW = pop @totals;
      my $total_row = { style => 'total', cols => [] };
      my $counter   = 0;
      
      foreach my $col (@$columns) {
        my $value = '';
        my $style = '';
        
        if ($counter == @totals) {
          $value = 'TOTAL';
        } elsif ($counter > @totals && $col->{'type'} eq 'numeric') {
          $value = $self->thousandify($TOTAL_ROW->[$counter]);
          $style = 'text-align:right';
        }
        
        push @{$total_row->{'cols'}}, { value => $value, style => $style };
        
        $counter++;
      }
      
      push @$return, $total_row;
    }
  }
  
  return $return;
}

sub add_option {
  my $self = shift;
  my $key = shift;
  
  if (ref $self->{'_options'}->{$key} eq 'HASH') {
    $self->{'_options'}->{$key} = { %{$self->{'_options'}->{$key}}, %{$_[0]} };
  } elsif (ref $self->{'_options'}->{$key} eq 'ARRAY') {
    push @{$self->{'_options'}->{$key}}, @_;
  } elsif (scalar @_ == 1) {
    $self->{'_options'}->{$key} = ref $_[0] eq 'ARRAY' ? [ $_[0] ] : $_[0];
  } else {
    $self->{'_options'}->{$key} = \@_;
  }
}

sub add_columns {
  my $self = shift;
  push @{$self->{'_columns'}}, @_;
}

sub add_spanning_headers {
  my $self = shift;
  push @{$self->{'_spanning'}}, @_;
}

sub add_row {
  my ($self, $data) = @_;
  push @{$self->{'_data'}}, $data;
}

sub add_rows {
  my $self = shift;
  push @{$self->{'_data'}}, @_;
}

sub get_value {
  my ($self, $row, $counter, $key) = @_;  
  return unless $row;
  
  my $rtn = '--';
  
  if (ref $row eq 'ARRAY') {
    $rtn = $row->[$counter];
  } elsif (ref $row eq 'HASH') {
    $rtn = $row->{$key}
  } elsif ($row->can($key)) {
    $rtn = $row->${\$key}();
  }
  
  return $rtn;
}
       
1;
