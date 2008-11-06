package EnsEMBL::Web::Timer;
use Time::HiRes qw(time);

### Useful little high-res timer package for profiling/benchmarking...
### Two sorts of timer created:
### * Diagnostics to count/time inner loops ({{start}}/{{end}})
### * Heirarchical diagnostics for timing execution of parts of pages ({{new}})
use strict;
use Class::Std;
{
  my %Benchmarks_of :ATTR( :get<benchmarks> );
  my %Times_of      :ATTR( :get<times>      );
  my %script_start_time_of  :ATTR( :get<script_start_time>  :set<script_start_time>  );
  my %process_start_time_of :ATTR( :get<process_start_time> :set<process_start_time> );
  my %process_child_count_of :ATTR( :get<process_child_count> :set<process_child_count> );
  my %Totals_of     :ATTR( :get<totals>     );
  my %Name_of       :ATTR( :get<name> :set<name> );
  sub BUILD {
  ### c
    my( $class, $ident, $arg_ref ) = @_;
    $Times_of{      $ident } = [];
    $Totals_of{     $ident } = {};
    $Benchmarks_of{ $ident } = {};
  }

sub new_child {
  my $self = shift;
  $process_child_count_of{ ident $self }++;
  $self->set_script_start_time( time );
}

#---------------------------------------------------------------
# Functions related to timing of method calls / low-level code..
#---------------------------------------------------------------

sub start {
### Start a new inner loop
  my( $self, $tag ) = @_;
## Only push new start time if actually started!!
  unless( $Benchmarks_of{ ident $self }{$tag}{'last_start'} ) { 
    $Benchmarks_of{ ident $self }{$tag}{'last_start'} = time();
  }
}

sub end {
### Mark inner loop as finished
  my( $self, $tag ) = @_;
## Can't push if there is no start!
  my $temp_ref = $Benchmarks_of{ ident $self }{$tag};
  if( $temp_ref->{'last_start'} ) {
    my $time = time()-$temp_ref->{'last_start'};
    if( exists( $temp_ref->{'min'} ) ) {
      $temp_ref->{'min'} = $time if $temp_ref->{'min'} > $time;
      $temp_ref->{'max'} = $time if $temp_ref->{'max'} < $time;
    } else {
      $temp_ref->{'min'} = $time;
      $temp_ref->{'max'} = $time;
    }
    $temp_ref->{ 'count' }++;
    $temp_ref->{ 'time'  }+= $time;
    $temp_ref->{ 'time2' }+= $time * $time;
    delete( $temp_ref->{ 'last_start' } );
  }
}

#---------------------------------------------------------------
# Functions related to timing blocks of page
#---------------------------------------------------------------

sub clear_times {
  my $self = shift;
  $Times_of{ ident $self } = [];
  $Totals_of{ ident $self } = {};
}
sub push {
### Push a new tag onto the "heirarchical diagnsotics"
### Message is message to display and level is the depth of the tree
### for which the timing is recorded
  my( $self, $message, $level, $flag ) = @_;
  my $i = ident $self;
  $level ||= 0;
  $flag  ||= 'web';
  my $last = @{$Times_of{$i}} ? $Times_of{$i}[-1][0] : 0;
  my $time = time; 
  CORE::push @{$Times_of{ ident $self }}, [ $time, $message, $level, $flag ];
  $Totals_of{ ident $self }{$flag} += $time-$last if $last;
}

sub render {
### Render both diagnostic tables if any data - tree timings from Push and diagnostic repeats from start/end
  my $self = shift;

  #$self->push("Page rendered");
  my $base_time = shift @{$Times_of{ ident $self }};

  my $diagnostics = '
================================================================================
'.$self->get_name.'
--------------------------------------------------------------------------------
Flag      Cumulative     Section
';
  my @previous  = ();
  my $max_depth = 0;
  foreach( @{$Times_of{ ident $self }} ) { $max_depth = $_->[2] if $max_depth < $_->[2]; }

  $diagnostics .= '           '.('           ' x (2+$max_depth) ) . $base_time->[1]; 
  $base_time = $base_time->[0];
  foreach( @{ $Times_of{ ident $self }} ) {
    $diagnostics .= sprintf( "\n%10s ",substr($_->[3],0,10) );
    foreach my $i (0..($max_depth+1)) {
      if( $i<=$_->[2] ) {
        $diagnostics .= sprintf( "%10.5f ", $_->[0]-($previous[$i]||$base_time) );
      } elsif( $i == $_->[2]+1 ) {
        $diagnostics .= sprintf( "%10.5f ", $_->[0]-($previous[$i]||$base_time) );
        $previous[$i] = $_->[0];
      } else {
        $diagnostics .= '           ';
        $previous[$i] = $_->[0];
      }
    }
    $diagnostics .= ("  | " x $_->[2]).$_->[1];

  }
  my %X = %{$Totals_of{ ident $self }};
  $diagnostics .='
--------------------------------------------------------------------------------
      Time       %age   Category
---------- ----------   -----------
';
  my $T = 0;
  foreach ( sort keys %X ) {
    $T+=$X{$_};
  }
  foreach ( sort keys %X ) {
    $diagnostics .= sprintf( "%10.5f %9.3f%%   %s\n", $X{$_}, 100*$X{$_}/$T, $_ );
  }
  $diagnostics .='---------- ----------   -----------
'.sprintf( '%10.5f',$T ),'           TOTAL
--------------------------------------------------------------------------------';
    
  my $benchmarks = '';
  foreach (keys %{$Benchmarks_of{ ident $self}} ) {
    my $T = $Benchmarks_of{ ident $self }{$_};
    next unless $T->{'count'};
    my $var = '**';
    if( $T->{'count'} > 1 ) {
      $var = sprintf "%10.6f", 
        sqrt( ($T->{'time2'}-$T->{'time'}*$T->{'time'}/$T->{'count'})/($T->{'count'}-1) );
    }
    $benchmarks .= sprintf "| %6d | %12.6f | %10.6f | %10s | %10.6f | %10.6f | %30s |\n",
      $T->{'count'},$T->{'time'},$T->{'time'}/$T->{'count'},
      $var, $T->{'min'},$T->{'max'},
      $_;
  }
  if($benchmarks) {
    $benchmarks = "
+--------+--------------+------------+------------+------------+------------+--------------------------------+
| Count  |   Total time | Ave. time  | Std dev.   | Min time   | Max time   | Tag                            |
+--------+--------------+------------+------------+------------+------------+--------------------------------+
$benchmarks".
"+--------+--------------+------------+------------+------------+------------+--------------------------------+
";
  }
  return "$diagnostics
$benchmarks
================================================================================
";
}

}
1;

