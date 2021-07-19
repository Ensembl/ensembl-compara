=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

# Data appears as a 4-tuple (line,char,key,value) in the adorn method.
# The data is stored as (line,key,char,id) in the adseq structure where
# id is an integer representing the value. adlookup maps (key,value) to
# id, and addlookid maintains the next available id. ids start at 1.
# adref is the reverse mapping from id to string.
#
# adseq and adref are then passed on to the next stage, which is to compress
# these values.
# Next RLE is applied to adseq: negative numbers denote a repeat of the
# previous value. The first value is implicitly undef. If the last value is
# a repeat, it is deleted as such repeats are implicit on decoding. If
# all values are undef, then the key is removed altogether.
# Next prefix coding is applied to adref. First the values are sorted, and
# pmap created which maps an id from earlier into its new position. Now
# prefixes are created by mapping adref to a list of pairs. The first
# member represents how many more or fewer characters to preserve, and
# the second value the remainder.
# The references in adseq are then updated to equal the new sorted ids.
# Finally each of the new adseq keys is compared to the last to see if it
# is identical and, if so, is RLEd.

package EnsEMBL::Web::TextSequence::Output::Web::Adorn;

use strict;
use warnings;

use List::Util qw(max);
use JSON qw(encode_json);

use EnsEMBL::Web::TextSequence::Output::Web::AdornLine;
use EnsEMBL::Web::TextSequence::Output::Web::AdornKey;

sub new {
  my ($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    curline => undef,
    keys => {},
    flourishes => {},
    adseqc => {},
    refo => {},
    domain => [],
  };
  bless $self,$class;
  return $self;
}

sub domain { $_[0]->{'domain'} = $_[1] if @_>1; return $_[0]->{'domain'}; }
sub linelen {$_[0]->{'linelen'} = $_[1] if @_>1; return $_[0]->{'linelen'};}

sub line {
  my ($self) = @_;

  $self->{'curline'} ||=
    EnsEMBL::Web::TextSequence::Output::Web::AdornLine->new($self);
  return $self->{'curline'};
}

sub akeys {
  my ($self,$k) = @_;

  $self->{'keys'}{$k} ||=
    EnsEMBL::Web::TextSequence::Output::Web::AdornKey->new($self,$k);
  return $self->{'keys'}{$k};
}

sub line_done {
  my ($self,$line) = @_;

  $self->{'adseqc'}{$line} = {};
  $self->line->done;
  foreach my $k (@{$self->line->linekeys}) {
    $self->{'adseqc'}{$line}{$k} = $self->line->key($k)->data;
  }
  $self->{'curline'} = undef;
}

sub flourish {
  my ($self,$type,$line,$value) = @_;

  ($self->{'flourishes'}{$type}||={})->{$line} =
    encode_json({ v => $value });
}

# Internal compression methods
sub adseq_eq {
  my ($a,$b) = @_;

  return 1 if !defined $a and !defined $b;
  return 0 if !defined $a or !defined $b;
  foreach my $k (keys %$a) { return 0 unless exists $b->{$k}; }
  foreach my $k (keys %$b) { return 0 unless exists $a->{$k}; }
  foreach my $k (keys %$a) {
    return 0 unless @{$a->{$k}} == @{$b->{$k}};
    foreach my $i (0..$#{$a->{$k}}) {
      next if !defined $a->{$k}[$i] and !defined $b->{$k}[$i];
      return 0 if !defined $b->{$k}[$i];
      return 0 if !defined $a->{$k}[$i];
      return 0 unless $a->{$k}[$i] == $b->{$k}[$i];
    }
  }
  return 1;
}

sub adorn_compress {
  my ($self) = @_;

  # RLE
  foreach my $a (keys %{$self->{'adseqc'}}) {
    foreach my $k (keys %{$self->{'adseqc'}{$a}}) {
      pop @{$self->{'adseqc'}{$a}{$k}} if @{$self->{'adseqc'}{$a}{$k}} and $self->{'adseqc'}{$a}{$k}[-1] and $self->{'adseqc'}{$a}{$k}[-1] < 0;
      my $rle = $self->{'adseqc'}{$a}{$k};
      if(@$rle > 1 and !$rle->[0] and $rle->[1]<0) {
        shift @$rle;
        $rle->[0]--;
      }
      if(@$rle == 1 and !$rle->[0]) {
        delete $self->{'adseqc'}{$a}{$k};
      } else {
        $self->{'adseq'}{$a}{$k} = $rle;
      }
    }
    delete $self->{'adseq'}{$a} unless keys %{$self->{'adseq'}{$a}};
  }

  # PREFIX
  foreach my $k (keys %{$self->{'keys'}}) {
    my $kv = $self->akeys($k)->adref;
    # ... sort
    my @sorted;
    foreach my $i (0..$#$kv) {
      push @sorted,[$i,$kv->[$i]];
    }
    @sorted = sort { $a->[1] cmp $b->[1] } @sorted;
    my %pmap;
    foreach my $i (0..$#sorted) {
      $pmap{$sorted[$i]->[0]} = $i;
    }
    @sorted = map { $_->[1] } @sorted;
    # ... calculate prefixes
    my @prefixes;
    my $prev = "";
    my $prevlen = 0;
    foreach my $s (@sorted) {
      if($prev) {
        my $match = "";
        while(substr($s,0,length($match)) eq $match and
              length($match) < length($prev)) {
          $match .= substr($prev,length($match),1);
        }
        my $len = length($match)-1;
        push @prefixes,[$len-$prevlen,substr($s,length($match)-1)];
        $prevlen = $len;
      } else {
        push @prefixes,[-$prevlen,$s];
        $prevlen = 0;
      }
      $prev = $s;
    }
    # ... fix references
    foreach my $a (keys %{$self->{'adseq'}}) {
      next unless $self->{'adseq'}{$a}{$k};
      my @seq;
      foreach my $v (@{$self->{'adseq'}{$a}{$k}}) {
        if(defined $v) {
          if($v>0) {
            push @seq,$pmap{$v};
          } else {
            push @seq,$v;
          }
        } else {
          push @seq,undef;
        }
      }
      $self->{'adseq'}{$a}{$k} = \@seq;
      $self->{'refo'}{$k} = \@prefixes;
    }
  }

  # Compress sequence
  my (@adseq_raw,@adseq);
  foreach my $k (keys %{$self->{'adseq'}}) {
    $adseq_raw[$k] = $self->{'adseq'}{$k};
  }
  my $prev;
  foreach my $i (0..$#adseq_raw) {
    if($i and adseq_eq($prev,$adseq_raw[$i])) {
      if(defined $adseq[-1] and !ref($adseq[-1])) { $adseq[-1]--; } else { push @adseq,-1; }
    } else {
      $prev = $adseq_raw[$i];
      push @adseq,$prev;
    }
  }
  return \@adseq;
}

sub adorn_data {
  my ($self) = @_;

  my $adseq = $self->adorn_compress;

  return {
    seq => $adseq,
    ref => $self->{'refo'},
    flourishes => $self->{'flourishes'}
  };
}

1;
