package EnsEMBL::Web::URLfeature;

use strict;
sub new {
  return bless {'__raw__'=>$_[1]},$_[0];
}

sub display_id { return $_[0]->id; }
sub hseqname { my $self = shift; return $self->id; }
sub strand  { my $self = shift; return 1; }
sub seqname { my $self = shift; (my $T = $self->_seqname) =~s/^chr//; return $T; }
sub start   { my $self = shift; return $self->{'start'}; }
sub end     { my $self = shift; return $self->{'end'}; }
sub score   { return $_[0]->{'score'}; } 

sub id { my $self = shift; return undef; }
sub _strand { my($self,$str) = @_;
#  warn $str;
  return $str eq '-' ? -1 : ( $str eq '+' ? 1 : 0 ) ;
}

sub map {
  my( $self, $slice ) = @_;
  my $chr = $self->seqname();
     $chr=~s/^chr//;
  return () unless $chr eq $slice->seq_region_name;
#  return () unless $self->rawstart < $slice->end;
  return () unless $self->start <= $slice->end;
  my $slice_start = $slice->start();
  return () unless $slice_start < $self->rawend;
  $self->slide( 1 - $slice_start );
  return $self;
}
  
1;
