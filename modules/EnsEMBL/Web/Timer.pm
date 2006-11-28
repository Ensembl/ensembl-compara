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
  sub BUILD {
  ### c
    my( $class, $ident, $arg_ref ) = @_;
    $Times_of{      $ident } = [];
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

sub clear_benchmarks {
  my $self = shift;
  @{$Times_of{ ident $self }} = [];
}
sub push {
### Push a new tag onto the "heirarchical diagnsotics"
### Message is message to display and level is the depth of the tree
### for which the timing is recorded
  my( $self, $message, $level ) = @_;
  $level ||= 0;
  push @{$Times_of{ ident $self }}, [ time(), $message, $level ];
}

sub render {
### Render both diagnostic tables if any data - tree timings from Push and diagnostic repeats from start/end
  my $self = shift;
  $self->push("Page rendered");
  my $base_time = shift @{$Times_of{ ident $self }};

  my $diagnostics = "
================================================================
Script /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}
-----------------------------------------------------------------
Cumulative     Section\n";
  my @previous  = ();
  my $max_depth = 0;
  foreach( @{$Times_of{ ident $self }} ) { $max_depth = $_->[2] if $max_depth < $_->[2]; }

  $diagnostics .= ('           ' x (2+$max_depth) ) . $base_time->[1]; 
  $base_time = $base_time->[0];
  foreach( @{ $Times_of{ ident $self }} ) {
    $diagnostics .= sprintf( "\n" );
    foreach my $i (0..($max_depth+1)) {
      if( $i<=$_->[2] ) {
        $diagnostics .= sprintf( "%10.6f ", $_->[0]-($previous[$i]||$base_time) );
      } elsif( $i == $_->[2]+1 ) {
        $diagnostics .= sprintf( "%10.6f ", $_->[0]-($previous[$i]||$base_time) );
        $previous[$i] = $_->[0];
      } else {
        $diagnostics .= '           ';
        $previous[$i] = $_->[0];
      }
    }
    $diagnostics .= ("  | " x $_->[2]).$_->[1];
  }
  my $benchmarks = '';
  foreach (keys %{$self->{_benchmarks}} ) {
    my $T = $self->{_benchmarks}{$_};
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
=================================================================
";
}

}
1;

