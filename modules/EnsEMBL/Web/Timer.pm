package EnsEMBL::Web::Timer;
use Time::HiRes qw(time);

use strict;

sub new {
  my $class = shift;
  my $self = {'times'=>[]};
  bless $self, $class;
  $self->push( 'Script started' );
  return $self;
}

sub push {
  my( $self, $message, $level ) = @_;
  $level ||= 0;
  push @{$self->{'times'}}, [ time(), $message, $level ];
}

sub render {
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
  return "$diagnostics
=================================================================
";

}

1;

