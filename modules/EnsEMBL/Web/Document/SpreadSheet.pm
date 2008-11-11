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

sub new { ## All now configured by the component!!
  my $class = shift;
  my( $c,$d,$o,$s ) = @_;
  $c||=[];
  $d||=[];
  $o||={};
  $s||=[];
  my $self = {
    '_columns'  => $c,
    '_spanning' => $s,
    '_data'     => $d,
    '_options'  => $o
  };
  bless $self, $class ;
}

sub strip_HTML {
  my ( $self, $string ) = @_;
  $string =~ s/<[^>]+>//g;
  return $string;
}

sub render {
  my $self    = shift;
  return unless @{$self->{_columns} || []};
  my $options = $self->{_options} || {};
  my $align = $options->{align} ? $options->{align} : 'autocenter';
  my $width = $options->{width} ? $options->{width} : '100%';
  my $margin = $options->{margin} ? $options->{margin} : '0px';

  $align .= ' top-border' if $options->{'header'} eq 'no';
  my $output = qq(\n<table class="ss $align" style="width:$width;margin:$margin" cellpadding="0" cellspacing="0">);

  if (scalar(@{$self->{_spanning}})) {
    $output .= qq(\n  <tr class="ss_header">);
    foreach my $header (@{$self->{_spanning}}) {
      my $span = $header->{'colspan'} || 1;
      $output .= '<th colspan="'.$span.'"><em>'.$header->{'title'}.'</em></th>';
    }
    $output .= "</tr>\n";
  }

  foreach my $row ( @{ $self->_process()} ) {
    my $tag = 'td';
    if($row->{style} eq 'header') {
      $output .= qq(\n  <tr class="ss_header">);
      $tag = 'th';
    } elsif($row->{style} eq 'total' ) {
      $output .= qq(\n  <tr>);
      $tag = 'th';
    } else {
      $output .= qq(\n  <tr style="vertical-align:@{[ $row->{'valign'} || 'top' ]}"@{[$row->{'class'}?qq( class="$row->{'class'}") : ""]}>);
    }
    my $counter = 0;
    my $no_columns = @{$row->{'cols'}};
    foreach my $cell ( @{$row->{'cols'}} ) {
      my $extra = ( $cell->{'class'} ? qq( class="$cell->{class}") : '' ).
                  ( $cell->{'style'} ? qq( style="$cell->{style}") : '' ).
                  ( $cell->{'colspan'} ? qq( colspan="$cell->{colspan}") : '' );
      $output .= qq(\n    <$tag$extra>@{[ (defined($cell->{'value'}) && $cell->{'value'} ne '' ) ? $cell->{'value'}: '<span style="display:none">-</span>' ]}</$tag>);
    }

    $output .= qq(\n  </tr>);
  }
  $output .= qq(\n</table>);
  return $output;
}

sub render_Text {
  my $self    = shift;
#  use Data::Dumper;
#  warn Data::Dumper::Dumper( $self );
  return unless @{$self->{_columns} || []};
  my $options = $self->{_options} || {};
  my $align = $options->{align} ? $options->{align} : 'autocenter';
  my $width = $options->{width} ? $options->{width} : '100%';

  my $output = '';
  foreach my $row ( @{ $self->_process()} ) {
    $output .= join "\t", map { $self->strip_HTML( $_->{'value'} ) } @{$row->{'cols'}};
    $output .= "\n";
  }
  return $output;
}

sub _process {
  my $self    = shift;

  my $counter = 0;
  my $data    = $self->{_data}    || [];
  my $columns = $self->{_columns} || [];
  my $options = $self->{_options} || {};

  my $no_cols = @$columns;
# Start the table...
  my $return = [];
  foreach (0..($no_cols-1)) {
    my $col = $columns->[$_];
    $col = $columns->[$_] = { 'key' => $col } unless ref($col) eq 'HASH';
    $counter++;
  }

# Draw the header row unless the "header" options is set to "no"
  unless( $options->{header} eq 'no' ) {
    $counter = 0;
    my $border;
    my $row = { 'style' => 'header', 'cols' => [] };
    foreach( @$columns ) {
      push @{$row->{'cols'}}, { 'class' => 'text-align:'.( $options->{alignheader}||'center'), 'value' => defined $_->{title} ? $_->{title} : $_->{key}, 'class' => 'bottom-border' } 
    }
    push @$return, $row;
  }

  # Display each row in the table
  my $SORT_BLOB;
  my $row_count = 0;
  my @sorted_data = ( 
           $options->{'sort'} ? (
      ref( $options->{'sort'} ) eq 'CODE' ?
        ( sort { &{$options->{'sort'}}( $a, $b)}  @$data ) :
        ( sort { $self->_sort_array( $SORT_BLOB ||= $self->_sort_pars( $options->{'sort'} , $columns ), $a, $b ) } @$data )
    ) : @$data); 
  my @previous_row = ();
  my @totals = ();
  my @row_colours = exists $options->{'rows'} ? @{$options->{rows}} : qw(bg1 bg2);
  foreach my $row (@sorted_data) {
    my $flag = 0;
    my $out_row = { 'style' => 'row', 'class' => $row_colours[0], 'col' => [] };
    $counter = 0;
    foreach my $col ( @$columns ) {
      my $value = ref( $row ) eq 'ARRAY' ? $row->[$counter] :
        ( ref( $row ) eq 'HASH'    ? $row->{$col->{key}} :
          ( $row->can( $col->{key} ) ? $row->${\$col->{key}}() : '--'  )
        );
      my $hidden_value = $value;
      if( exists $col->{hidden_key} ) {
        $hidden_value = ref( $row ) eq 'ARRAY' ? $row->[$counter] :
          ( ref( $row ) eq 'HASH'    ? $row->{$col->{hidden_key}} :
            ( $row->can( $col->{hidden_key} ) ? $row->${\$col->{hidden_key}}() : '--'  )
          );
      }
      my $class = '';
      if( $row_count == $#sorted_data && !$options->{'total'}) {
        $class .= ' bottom-border';
      }
      my $style =  join ' ',
        exists $col->{align} ? qq(text-align:$col->{align};) : ( $col->{type} eq 'numeric' ? 'text-align:right;' : () ).
        exists $col->{width} ? qq(width:$col->{width};) : ();
      my $TV = lc($hidden_value);
      if( $flag == $counter ) {
        if( $TV eq $previous_row[$counter] ) {
          $flag = $counter+1;
          if( $options->{'triangular'} ) {
            $value = '';
          }
        }
      }
      $previous_row[$counter] = $TV;
      my $T = $col->{format};
      push @{$out_row->{'cols'}}, { 
        'value' => ( $value eq '' ? '' : (
          exists( $col->{format} ) ? ( ref $T eq 'CODE' ? $T->( $value, $row ) : ( $self->can($T) ? $self->$T($value,$row) : $value ) ) : $value
        ) ),
        'class' => $class,
        'style' => $style
      };
      $counter++;
    }
    next if( $flag == $counter ) ; ## SKIP WHOLY BLANK LINES
    push @row_colours, shift @row_colours;

    $row_count++;
    if( $options->{'total'}>0 ) { ### SUMMARY TOTALS.... ###
      if($flag<$options->{'total'}) {
        for(my $i=$options->{'total'}-1;$i>$flag;$i--) {
          next unless @totals;
          my $TOTAL_ROW = pop @totals;
          my $total_row = { 'style' => 'total', 'cols' => [] };
          my $counter = 0;
          foreach my $col( @$columns ) {
            my $class = $i==$flag+1 ? 'bottom-border' : '';
            my $value = '';
            my $style = '';
            if( $counter == @totals ) {
              $value = 'TOTAL';
            } elsif( $counter > @totals && $col->{type} eq 'numeric' ) {
              $style = 'text-align:right';
              $value = $self->thousandify( $TOTAL_ROW->[$counter] );
            }
            push @{$total_row->{'cols'}}, { 'value' => $value, 'style' => $style, 'class' => $class };
            $counter ++;
          }
          push @$return, $total_row;
        }
      }
      my $counter = 0;
      foreach my $col ( @$columns ) {
        if( $col->{type} eq 'numeric' ) {
          my $value = ref( $row ) eq 'ARRAY' ? $row->[$counter] :
            ( ref( $row ) eq 'HASH'    ? $row->{$col->{key}} :
            ( $row->can( $col->{key} ) ? $row->${\$col->{key}}() : '--'  )
          );
          for( my $i=0;$i<$options->{'total'};$i++ ) {
            $totals[$i][$counter] += $value;
          }
        }
        $counter++;
      }
    }
    push @$return, $out_row;
  }
  if( $options->{'total'}>0 ) { ### SUMMARY TOTALS.... ###
    while( @totals ) {
      my $TOTAL_ROW = pop @totals;
      my $total_row = { 'style' => 'total', 'cols' => [] };
      my $counter = 0;
      foreach my $col( @$columns ) {
        my $class = @totals ? 'bottom-border' :'';
        my $value = '';
        my $style = '';
        if( $counter == @totals ) {
          $value = 'TOTAL';
        } elsif( $counter > @totals && $col->{type} eq 'numeric' ) {
          $value = $self->thousandify( $TOTAL_ROW->[$counter] );
          $style = 'text-align:right';
        }
        push @{$total_row->{'cols'}}, { 'value' => $value, 'style' => $style, 'class' => $class };
        $counter++;
      }
      push @$return , $total_row;
    }
  }
  foreach ( @$return ) {
    $_->{'cols'}[0]{'class'} .= ( $_->{'cols'}[0]{'class'} ? " " : "" ). 'left-border';
    $_->{'cols'}[-1]{'class'} .= ( $_->{'cols'}[-1]{'class'} ? " " : "" ). 'right-border';
  }
  return $return;
}

sub add_option {        
  my $self = shift;     
  push @{$self->{_options}}, @_;        
}       
         
sub add_columns {        
  my $self = shift;     
  push @{$self->{_columns}}, @_;        
}       
         
sub add_spanning_headers {        
  my $self = shift;     
  push @{$self->{_spanning}}, @_;        
}       
         
sub add_row {   
  my( $self, $data ) = @_;      
  push @{$self->{_data}}, $data;        
}       
        
1;

