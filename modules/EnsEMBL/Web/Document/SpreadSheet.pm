package EnsEMBL::Web::Document::SpreadSheet;

use strict;
use Exporter;
use EnsEMBL::Web::Root;

our @ISA = qw(Exporter EnsEMBL::Web::Root);
our @EXPORT = qw(FORMAT_BOLD FORMAT_ITALIC FORMAT_BOLDITALIC FORMAT_NDP ALIGN_LEFT ALIGN_CENTER ALIGN_RIGHT ALTERNATING_BACKGROUND FORMAT_THOUSANDIFY);
our @EXPORT_OK = qw(FORMAT_BOLD FORMAT_ITALIC FORMAT_BOLDITALIC FORMAT_NDP ALIGN_LEFT ALIGN_CENTER ALIGN_RIGHT ALTERNATING_BACKGROUND FORMAT_THOUSANDIFY);
our %EXPORT_TAGS = (
  'FORMATS' => [qw(FORMAT_BOLD FORMAT_ITALIC FORMAT_BOLDITALIC FORMAT_NDP ALIGN_LEFT ALIGN_CENTER ALIGN_RIGHT ALTERNATING_BACKGROUND FORMAT_THOUSANDIFY)]
);

sub FORMAT_BOLD       { format => sub { "<strong>$_[0]</strong>" } }
sub FORMAT_ITALIC     { format => sub { "<em>$_[0]</em>" } }
sub FORMAT_BOLDITALIC { format => sub { "<strong><em>$_[0]</em></strong>" } }
sub FORMAT_NDP        { my $T = shift; sub { sprintf "%0.${T}f", $_[0] } }
sub FORMAT_THOUSANDIFY  { sprintf $_[0]->thousandify( $_[1] ); }
sub ALIGN_LEFT        { align => 'left' }
sub ALIGN_CENTER      { align => 'center' }
sub ALIGN_RIGHT       { align => 'right' }
sub ALTERNATING_BACKGROUND { my $self = shift ; rows => [qw(bg1 bg2)] };

sub new { # All now configured by the component!!
  my $class = shift;
  my ($c, $d, $o, $s) = @_;
  
  $c ||= [];
  $d ||= [];
  $o ||= {};
  $s ||= [];
  
  my $self = {
    '_columns'  => $c,
    '_spanning' => $s,
    '_data'     => $d,
    '_options'  => $o
  };
  
  bless $self, $class;
}

sub strip_HTML {
  my ($self, $string) = @_;
  $string =~ s/<[^>]+>//g;
  return $string;
}

sub render {
  my $self = shift;
  
  return unless @{$self->{'_columns'} || []};
  
  my $options = $self->{'_options'} || {};
  my $align = $options->{'align'} || 'autocenter';
  my $width = $options->{'width'} || '100%';
  my $margin = $options->{'margin'} || '0px';
  my $padding = $options->{'cellpadding'} || 0;
  my $spacing = $options->{'cellspacing'} || 0;

  $align .= ' top-border' if $options->{'header'} eq 'no';
  
  my $output = qq{\n<table class="ss $align" style="width:$width;margin:$margin" cellpadding="$padding" cellspacing="$spacing">};

  if (scalar(@{$self->{'_spanning'}})) {
    $output .= qq{\n  <tr class="ss_header">};
    
    foreach my $header (@{$self->{'_spanning'}}) {
      my $span = $header->{'colspan'} || 1;
      $output .= qq{<th colspan="$span"><em>$header->{'title'}</em></th>};
    }
    
    $output .= "</tr>\n";
  }

  foreach my $row (@{$self->_process}) {
    my $tag = 'td';
    
    if ($row->{'style'} eq 'header') {
      $output .= qq{\n  <tr class="ss_header">};
      $tag = 'th';
    } elsif ($row->{'style'} eq 'total') {
      $output .= "\n  <tr>";
      $tag = 'th';
    } else {
      my $valign = $row->{'valign'} || 'top';
      my $class = $row->{'class'} ? qq{ class="$row->{'class'}"} : '';
      
      $output .= qq{\n  <tr style="vertical-align:$valign"$class>};
    }
    
    foreach my $cell (@{$row->{'cols'}}) {
      my $extra = $cell->{'class'} ? qq{ class="$cell->{'class'}"} : '';
      $extra .= $cell->{'style'} ? qq{ style="$cell->{'style'}"} : '';
      $extra .= $cell->{'colspan'} ? qq{ colspan="$cell->{'colspan'}"} : '';
      
      my $val = defined ($cell->{'value'}) && $cell->{'value'} ne '' ? $cell->{'value'} : '<span style="display:none">-</span>';
         
      $output .= "\n    <$tag$extra>$val</$tag>";
    }

    $output .= "\n  </tr>";
  }
  
  $output .= "\n</table>";
  
  return $output;
}

sub render_Text {
  my $self    = shift;
  
  return unless @{$self->{'_columns'} || []};
  
  my $options = $self->{'_options'} || {};
  my $align = $options->{'align'} ? $options->{'align'} : 'autocenter';
  my $width = $options->{'width'} ? $options->{'width'} : '100%';

  my $output = '';
  
  foreach my $row (@{$self->_process}) {
    $output .= join "\t", map { $self->strip_HTML($_->{'value'}) } @{$row->{'cols'}};
    $output .= "\n";
  }
  
  return $output;
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
    $col = $columns->[$_] = { 'key' => $col } unless ref $col eq 'HASH';
    $counter++;
  }

  # Draw the header row unless the "header" options is set to "no"
  unless ($options->{'header'} eq 'no') {
    $counter = 0;
    my $border;
    my $row = { 'style' => 'header', 'cols' => [] };
    my $average = int(100/scalar $columns);
    
    foreach (@$columns) {
      push (@{$row->{'cols'}}, {
        'style' => 'text-align:' . ($options->{'alignheader'} || $_->{'align'} || 'center') . ';width:' . ($_->{'width'} || $average.'%'), 
        'value' => defined $_->{'title'} ? $_->{'title'} : $_->{'key'}, 
        'class' => 'bottom-border' 
      });
    }
    
    push (@$return, $row);
  }

  # Display each row in the table
  my $row_count = 0;
  my @sorted_data;
  
  if ($options->{'sort'}) {
    # This doesn't actually work, and _sort_array doesn't exist
    @sorted_data = (sort {
      ref $options->{'sort'} eq 'CODE' ? &{$options->{'sort'}}($a, $b) : $self->_sort_array($self->_sort_pars($options->{'sort'}, $columns), $a, $b)
    } @$data);
  } else {
    @sorted_data = @$data;
  }
  
  my @previous_row = ();
  my @totals = ();
  my $row_colours = exists $options->{'rows'} ? $options->{'rows'} : [ 'bg1', 'bg2' ];
  
  foreach my $row (@sorted_data) {
    my $flag = 0;
    my $out_row = { 'style' => 'row', 'class' => $row_colours->[0], 'col' => [] };
    $counter = 0;
    
    foreach my $col (@$columns) {
      my $value = get_value($row, $counter, $col->{'key'});
      my $hidden_value = lc (exists $col->{'hidden_key'} ? get_value($row, $counter, $col->{'hidden_key'}) : $value);
      my $class = '';
      
      # $#sorted_data is the last index of @sorted_data
      if ($row_count == $#sorted_data && !$options->{'total'}) {
        $class .= ' bottom-border';
      }
            
      my $style = exists $col->{'align'} ? "text-align:$col->{'align'};" : ($col->{'type'} eq 'numeric' ? 'text-align:right;' : '');
      $style .= exists $col->{'width'} ? "width:$col->{'width'};" : '';
      
      if (exists $options->{'row_style'} && $options->{'row_style'}->[$row_count]) {
        $style .= $options->{'row_style'}->[$row_count]->[$counter];
      }
      
      if ($flag == $counter) {
        if ($hidden_value eq $previous_row[$counter]) {
          $flag = $counter+1;
          
          $value = '' if $options->{'triangular'};
        }
      }
      
      $previous_row[$counter] = $hidden_value;
      
      my $val = $value;
      my $f = $col->{'format'};
      
      if ($value ne '' && $f) {
        if (ref $f eq 'CODE') {
          $val = $f->($value, $row);
        } elsif ($self->can($f)) {
          $val = $self->$f($value, $row);
        }
      }
      
      push (@{$out_row->{'cols'}}, { 
        'value' => $val,
        'class' => $class,
        'style' => $style
      });
      
      $counter++;
    }
    
    next if $flag == $counter; # SKIP WHOLLY BLANK LINES
    
    push (@$row_colours, shift @$row_colours);

    $row_count++;
    
    if ($options->{'total'} > 0) { # SUMMARY TOTALS
      if ($flag < $options->{'total'}) {
        for (my $i = $options->{'total'}-1; $i > $flag; $i--) {
          next unless @totals;
          
          my $TOTAL_ROW = pop @totals;
          my $total_row = { 'style' => 'total', 'cols' => [] };
          my $counter = 0;
          
          foreach my $col (@$columns) {
            my $class = ($i == $flag+1) ? 'bottom-border' : '';
            my $value = '';
            my $style = '';
            
            if ($counter == @totals) {
              $value = 'TOTAL';
            } elsif ($counter > @totals && $col->{'type'} eq 'numeric') {
              $style = 'text-align:right';
              $value = $self->thousandify($TOTAL_ROW->[$counter]);
            }
            
            push (@{$total_row->{'cols'}}, { 'value' => $value, 'style' => $style, 'class' => $class });
            
            $counter++;
          }
          
          push (@$return, $total_row);
        }
      }
      
      my $counter = 0;
      
      foreach my $col (@$columns) {
        if ($col->{'type'} eq 'numeric') {
          my $value = get_value($row, $counter, $col->{'key'});
            
          for (my $i = 0; $i < $options->{'total'}; $i++) {
            $totals[$i][$counter] += $value;
          }
        }
        
        $counter++;
      }
    }
    
    push (@$return, $out_row);
  }
  
  if ($options->{'total'} > 0) { # SUMMARY TOTALS
    while (@totals) {
      my $TOTAL_ROW = pop @totals;
      my $total_row = { 'style' => 'total', 'cols' => [] };
      my $counter = 0;
      
      foreach my $col (@$columns) {
        my $class = @totals ? 'bottom-border' : '';
        my $value = '';
        my $style = '';
        
        if ($counter == @totals) {
          $value = 'TOTAL';
        } elsif ($counter > @totals && $col->{'type'} eq 'numeric') {
          $value = $self->thousandify($TOTAL_ROW->[$counter]);
          $style = 'text-align:right';
        }
        
        push (@{$total_row->{'cols'}}, { 'value' => $value, 'style' => $style, 'class' => $class });
        
        $counter++;
      }
      
      push (@$return, $total_row);
    }
  }
  
  foreach (@$return) {
    $_->{'cols'}[0]{'class'} .= ' left-border';
    $_->{'cols'}[-1]{'class'} .= ' right-border';
  }
  
  return $return;
}

sub add_option {
  my $self = shift;
  my $key = shift;
  
  if (ref $self->{'_options'}->{$key} eq 'HASH') {
    $self->{'_options'}->{$key} = {%{$self->{'_options'}->{$key}}, %{$_[0]}};
  } elsif (ref $self->{'_options'}->{$key} eq 'ARRAY') {
    push (@{$self->{'_options'}->{$key}}, @_);
  } elsif (scalar @_ == 1) {
    $self->{'_options'}->{$key} = ref $_[0] eq 'ARRAY' ? [ $_[0] ] : $_[0];
  } else {
    $self->{'_options'}->{$key} = \@_;
  }
}

sub add_columns {
  my $self = shift;
  push (@{$self->{'_columns'}}, @_);
}

sub add_spanning_headers {
  my $self = shift;
  push (@{$self->{'_spanning'}}, @_);
}

sub add_row {
  my ($self, $data) = @_;
  push (@{$self->{'_data'}}, $data);
}

sub get_value {
  my ($row, $counter, $key) = @_;  
  
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
