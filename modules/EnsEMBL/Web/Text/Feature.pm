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

package EnsEMBL::Web::Text::Feature;

use strict;
use warnings;
no warnings "uninitialized";

sub new {
  return bless {'__raw__'=>$_[1],'__extra__'=>{} },$_[0];
}

sub _seqname { return ''; } # Override me
sub seqname { my $self = shift; (my $T = ($self->_seqname)) =~s/^chr//; return $T; }
sub start   { my $self = shift; return $self->{'start'}; }
sub end     { my $self = shift; return $self->{'end'}; }
sub strand        { return 0; }
sub cigar_string  { return undef; }
sub hstart        { return undef; }
sub hend          { return undef; }
sub hstrand       { return 0; }
sub type          { return undef; }
sub note          { return undef ;}
sub score         { return undef; }  
sub link          { return undef; }  
sub slice         { return undef; }  
sub attribs       { return {}; }

sub extra_data { return $_[0]{__extra__}; }
sub extra_data_order { return undef; }

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
  return () unless $start <= $slice_end;
  my $end   = $self->rawend();
  my $slice_start = $slice->start();
  return () unless $slice_start <= $end;
  $self->slide( 1 - $slice_start );
  
  if ($slice->strand == -1) {
    my $flip = $slice->length + 1;
    ($self->{'start'}, $self->{'end'}) = ($flip - $self->{'end'}, $flip - $self->{'start'});
  }
  
  return $self;
}

sub slide    {
  my $self = shift;
  my $offset = shift;
  $self->{'start'} = $self->rawstart + $offset;
  $self->{'end'}   = $self->rawend + $offset;
}

sub display_id {
  return undef; # override
}

1;
