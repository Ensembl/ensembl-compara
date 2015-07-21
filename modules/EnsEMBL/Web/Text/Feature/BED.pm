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

package EnsEMBL::Web::Text::Feature::BED;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub new {
  my( $class, $args, $extra, $order, $names ) = @_;

  unless(defined $extra) {
    $extra = {};
  }
  my @default_extras = qw(thick_start thick_end item_colour
                            BlockCount BlockSizes BlockStarts);
  foreach my $i (0..$#default_extras) {
    $extra->{$default_extras[$i]}=$args->[$i+6] if defined $args->[$i+6];
  }
  my $more = { map { $_ => [$extra->{$_}] } keys %$extra };

  return bless { '__raw__' => $args, '__extra__' => $more, '__order__' => $order, '__names__' => $names }, $class;
}

sub extra_data_order { return $_[0]->{'__order__'}; }

sub real_name {
  return $_[0]->{'__names__'}{$_[1]} || $_[1] if $_[0]->{'__names__'};
  return $_[1];
}

sub coords {
  ## BED start coord needs +1 
  my ($self, $data) = @_;
  (my $chr = $data->[0]) =~ s/chr//;
  return ($chr, $data->[1]+1, $data->[2]);
}

sub _seqname { my $self = shift; return $self->{'__raw__'}[0]; }
sub strand   { my $self = shift;
  my $T = ( 0+@{$self->{'__raw__'}}) > 5 
        ? $self->_strand( $self->{'__raw__'}[5] )
        : -1
        ;
}
sub hstrand  { return 1; }
# Note rawstart has +1 because BED is 'semi-open' coordinates
sub rawstart { my $self = shift; return $self->{'__raw__'}[1]+1; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[2]; }
sub id       { my $self = shift; return $self->{'__raw__'}[3]; }

sub _raw_score    { 
  my $self = shift;

  my $score = 0;
  if ( exists($self->{'__raw__'}[4]) && $self->{'__raw__'}[4] =~ /^-*\d+\.?\d*$/) {
    $score = $self->{'__raw__'}[4];
  }
  elsif ($self->{'__raw__'}[3] =~ /^-*\d+\.?\d*$/) { ## Possible bedGraph format
    $score = $self->{'__raw__'}[3];
  } 
  return $score;
}

sub score {
  my $self = shift;

  $self->{'score'} = $_[0] if @_;
  $self->{'score'} = $self->_raw_score unless exists $self->{'score'};
  return $self->{'score'};
}

sub external_data { my $self = shift; return $self->{'__extra__'} ? $self->{'__extra__'} : undef ; }

sub attribs { my $self = shift; return $self->{'__extra__'} ? $self->{'__extra__'} : {} ; }

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'} if $self->{'_cigar'};
  if($self->{'__raw__'}[9]>0) {
    my $strand = $self->strand();
    my $cigar;
    my @block_starts  = split /,/,$self->{'__raw__'}[11];
    my @block_lengths = split /,/,$self->{'__raw__'}[10];
    my $end = 0;
    foreach(0..( $self->{'__raw__'}[9]-1) ) {
      last unless @block_starts and @block_lengths;
      my $start =shift @block_starts;
      my $length = shift @block_lengths;
      if($_) {
        if($strand == -1) {
          $cigar =  ( $start - $end - 1)."I$cigar";
        } else {
          $cigar.= ( $start - $end - 1)."I";
        }
      }
      if($strand == -1) {
        $cigar = $length."M$cigar";
      } else {
        $cigar.= $length.'M';
      }
      $end = $start + $length -1;
    }
    return $self->{'_cigar'}=$cigar;
  } else {
    # Length of Cigar must not have +1 
    return $self->{'_cigar'}=($self->{'__raw__'}[2]-$self->{'__raw__'}[1])."M";
  }
}

1;
