package EnsEMBL::Web::Text::Feature;

use strict;
use warnings;
no warnings "uninitialized";

sub new {
  return bless {'__raw__'=>$_[1],'__extra__'=>{} },$_[0];
}

sub seqname { my $self = shift; (my $T = $self->_seqname) =~s/^chr//; return $T; }
sub start   { my $self = shift; return $self->{'start'}; }
sub end     { my $self = shift; return $self->{'end'}; }
sub strand        { return undef; }
sub cigar_string  { return undef; }
sub hstart        { return undef; }
sub hend          { return undef; }
sub hstrand       { return undef; }
sub type          { return undef; }
sub note          { return undef ;}
sub score         { return undef; }  
sub link          { return undef; }  

sub extra_data { return $_[0]{__extra__}; }

sub coords {
  ## Default parser for raw data - this is the commonest format
  my ($self, $data) = @_;
  (my $chr = $data->[0]) =~ s/chr//;
  return ($chr, $data->[1], $data->[2]);
}

sub id { my $self = shift; return undef; }
sub _strand { 
  my($self,$str) = @_;
  return $str eq '-' ? -1 : ( $str eq '+' ? 1 : 0 ) ;
}

sub seq_region_start  { return shift->rawstart; }
sub seq_region_end    { return shift->rawend;   }
sub seq_region_strand { return shift->strand;   }

sub map {
  my( $self, $slice ) = @_;
  my $chr = $self->seqname(); 
  $chr=~s/^chr//;
  return () unless $chr eq $slice->seq_region_name;
  my $start = $self->rawstart();
  my $slice_end = $slice->end();
  return () unless $start < $slice_end;
  my $end   = $self->rawend();
  my $slice_start = $slice->start();
  return () unless $slice_start < $end;
  $self->slide( 1 - $slice_start );
  return $self;
}

sub slide    {
  my $self = shift;
  my $offset = shift;
  $self->{'start'} = $self->rawstart + $offset;
  $self->{'end'}   = $self->rawend + $offset;
}


1;
