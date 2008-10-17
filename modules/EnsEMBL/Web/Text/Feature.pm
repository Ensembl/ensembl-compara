package Data::Bio::Text::Feature;

use strict;
use warnings;
no warnings "uninitialized";

sub new {
  return bless {'__raw__'=>$_[1]},$_[0];
}

sub seqname { my $self = shift; (my $T = $self->_seqname) =~s/^chr//; return $T; }
sub start   { my $self = shift; return $self->{'start'}; }
sub end     { my $self = shift; return $self->{'end'}; }

sub id { my $self = shift; return undef; }
sub _strand { my($self,$str) = @_;
  return $str eq '-' ? -1 : ( $str eq '+' ? 1 : 0 ) ;
}

sub map {
  my( $self, $slice ) = @_;
  my $chr = $self->seqname(); $chr=~s/^chr//;
  return () unless $chr eq $slice->chr_name;
  my $start = $self->rawstart();
  my $slice_end = $slice->chr_end();
  return () unless $start < $slice_end;
  my $end   = $self->rawend();
  my $slice_start = $slice->chr_start();
  return () unless $slice_start < $end;
  $self->slide( 1 - $slice_start );
  return $self;
}

sub strand { return undef; }

sub type { return undef; }

sub note { return undef ;}

sub score { return undef; }  

sub link { return undef; }  

1;
