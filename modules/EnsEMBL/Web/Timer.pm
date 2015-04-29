=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Timer;
use Time::HiRes qw(time);

### Useful little high-res timer package for profiling/benchmarking...
### Two sorts of timer created:
### * Diagnostics to count/time inner loops ({{start}}/{{end}})
### * Heirarchical diagnostics for timing execution of parts of pages ({{new}})
use strict;

sub new {
  my $class = shift;
  my $self = {
    'benchmarks'          => {},
    'times'               => [],
    'script_start_time'   => undef,
    'process_start_time'  => undef,
    'process_child_count' => undef,
    'totals'              => undef,
    'name'                => undef,
  };
  bless $self, $class;
  return $self;
}

sub get_benchmark { return $_[0]->{'benchmarks'}; }

sub get_times { return $_[0]->{'times'}; }
sub get_totals { return $_[0]->{'totals'}; }

sub get_script_start_time { return $_[0]->{'script_start_time'}; }
sub set_script_start_time { $_[0]->{'script_start_time'} = $_[1]; }

sub get_process_start_time { return $_[0]->{'process_start_time'}; }
sub set_process_start_time { $_[0]->{'process_start_time'} = $_[1]; }

sub get_process_child_count { return $_[0]->{'process_child_count'}; }
sub set_process_child_count { $_[0]->{'process_child_count'} = $_[1]; }

sub get_name { return $_[0]->{'name'}; }
sub set_name { $_[0]->{'name'} = $_[1]; }

sub new_child {
  my $self = shift;
  $self->{'process_child_count'}++;
  $self->set_script_start_time( time );
}

#---------------------------------------------------------------
# Functions related to timing of method calls / low-level code..
#---------------------------------------------------------------

sub start {
### Start a new inner loop
  my( $self, $tag ) = @_;
## Only push new start time if actually started!!
  unless( $self->{'benchmarks'}{$tag}{'last_start'} ) { 
    $self->{'benchmarks'}{$tag}{'last_start'} = time();
  }
}

sub end {
### Mark inner loop as finished
  my( $self, $tag ) = @_;
## Can't push if there is no start!
  my $temp_ref = $self->{'benchmarks'}{$tag};
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
  ### Resets values of times and total times
  my $self = shift;
  $self->{'times'} = [];
  $self->{'totals'} = {};
}

sub push {
### Push a new tag onto the "hierarchical diagnostics"
### Message is message to display and level is the depth of the tree
### for which the timing is recorded
  my( $self, $message, $level, $flag ) = @_;
  $level ||= 0;
  $flag  ||= 'web';
  my $last = @{$self->{'times'}} ? $self->{'times'}[-1][0] : 0;
  my $time = time; 
  CORE::push @{$self->{'times'}}, [ $time, $message, $level, $flag ];
  $self->{'totals'}{$flag} += $time-$last if $last;
}

sub render {
### Render both diagnostic tables if any data - tree timings from Push and diagnostic repeats from start/end
  my $self = shift;

  #$self->push("Page rendered");
  my $base_time = shift @{$self->{'times'}};

  my $diagnostics = '
================================================================================
'.$self->get_name.'
--------------------------------------------------------------------------------
Flag      Cumulative     Section
';
  my @previous  = ();
  my $max_depth = 0;
  foreach( @{$self->{'times'}} ) { $max_depth = $_->[2] if $max_depth < $_->[2]; }

  $diagnostics .= '           '.('           ' x (2+$max_depth) ) . $base_time->[1]; 
  $base_time = $base_time->[0];
  foreach( @{$self->{'times'}} ) {
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
  my %X = %{$self->{'totals'}};
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
  foreach (keys %{$self->{'benchmarks'}} ) {
    my $T = $self->{'benchmarks'}{$_};
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

1;

