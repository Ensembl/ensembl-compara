package EnsEMBL::Web::Timer;
use Time::HiRes qw(time);

### Useful little high-res timer package for profiling/benchmarking...
### Two sorts of timer created:
### * Diagnostics to count/time inner loops ({{start}}/{{end}})
### * Heirarchical diagnostics for timing execution of parts of pages ({{new}})
use strict;

sub start {
### Start a new inner loop
  my( $self, $tag ) = @_;
## Only push new start time if actually started!!
  unless( $self->{'_benchmarks'}{$tag}{'last_start'} ) { 
    $self->{'_benchmarks'}{$tag}{'last_start'} = time();
  }
}

sub end {
### Mark inner loop as finished
  my( $self, $tag ) = @_;
## Can't push if there is no start!
  if( $self->{'_benchmarks'}{$tag}{'last_start'} ) {
    my $time = time()-$self->{'_benchmarks'}{$tag}{'last_start'};
    if( exists( $self->{'_benchmarks'}{$tag}{'min'} ) ) {
      $self->{'_benchmarks'}{$tag}{'min'} = $time if $self->{'_benchmarks'}{$tag}{'min'} > $time;
      $self->{'_benchmarks'}{$tag}{'max'} = $time if $self->{'_benchmarks'}{$tag}{'max'} < $time;
    } else {
      $self->{'_benchmarks'}{$tag}{'min'} = $time;
      $self->{'_benchmarks'}{$tag}{'max'} = $time;
    }
    $self->{'_benchmarks'}{$tag}{'count'}++;
    $self->{'_benchmarks'}{$tag}{'time'}+= $time;
    $self->{'_benchmarks'}{$tag}{'time'}+= $time;
    $self->{'_benchmarks'}{$tag}{'time'}+= $time;
    $self->{'_benchmarks'}{$tag}{'time2'}+= $time*$time;
    delete( $self->{'_benchmarks'}{$tag}{'last_start'} );
  }
}

sub new {
### c
  my $class = shift;
  my $self = {'times'=>[],'_benchmarks'=>{}};
  bless $self, $class;
  $self->push( 'Script started' );
  return $self;
}

sub push {
### Push a new tag onto the "heirarchical diagnsotics"
### Message is message to display and level is the depth of the tree
### for which the timing is recorded
  my( $self, $message, $level ) = @_;
  $level ||= 0;
  push @{$self->{'times'}}, [ time(), $message, $level ];
}

sub render {
### Render both diagnostic tables if any data - tree timings from Push and diagnostic repeats from start/end
  my $self = shift;
  $self->push("Page rendered");
  my $base_time = shift @{$self->{times}};

  my $diagnostics = "
================================================================
Script /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}
-----------------------------------------------------------------
Cumulative     Section\n";
  my @previous  = ();
  my $max_depth = 0;
  foreach( @{$self->{'times'}} ) { $max_depth = $_->[2] if $max_depth < $_->[2]; }

  $diagnostics .= ('           ' x (2+$max_depth) ) . $base_time->[1]; 
  $base_time = $base_time->[0];
  foreach( @{ $self->{'times'}} ) {
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
    $benchmarks .= sprintf "| %6d | %10.6f | %10.6f | %10s | %10.6f | %10.6f | %30s |\n",
      $T->{'count'},$T->{'time'},$T->{'time'}/$T->{'count'},
      $var, $T->{'min'},$T->{'max'},
      $_;
  }
  if($benchmarks) {
    $benchmarks = "
+--------+------------+------------+------------+------------+------------+--------------------------------+
| Count  | Total time | Ave. time  | Std dev.   | Min time   | Max time   | Tag                            |
+--------+------------+------------+------------+------------+------------+--------------------------------+
$benchmarks".
"+--------+------------+------------+------------+------------+------------+--------------------------------+
";
  }
  return "$diagnostics
$benchmarks
=================================================================
";
}

1;

