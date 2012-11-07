package EnsEMBL::Web::Document::Renderer::File;

use strict;
use IO::File;
sub new {
  my $class = shift;
  my $filename = shift;
  my $fh = IO::File->new;
  my $self;
  if( $fh->open( ">$filename") ) {
    $self = { 'file' => $fh };
  } else {
    $self = { 'file' => undef };
  }
  bless $self, $class;
  return $self;
}

sub fh {
  my $self = shift;
  return $self->'file';
}

sub valid  { return $_[0]->{'file'}; }
sub printf { my $self = shift; my $FH = $self->{'file'}; printf $FH @_ if $FH; }
sub print  { my $self = shift; my $FH = $self->{'file'}; print  $FH @_ if $FH; }

sub close  { my $FH = $_[0]->{'file'}; close $FH; $_[0]->{'file'} = undef; }
sub DESTROY { my $FH = $_[0]->{'file'}; close $FH; }
1;
