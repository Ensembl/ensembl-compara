=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

sub new {
  my ($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    adlookup => {},
    adlookid => {},
    flourishes => {},
    adseq => {},
    adseqc => {},
    adref => {},
    maxchar => {}
  };
  bless $self,$class;
  return $self;
}

sub adorn {
  my ($self,$line,$char,$k,$v) = @_; 

  $self->{'maxchar'}{$line} = max($self->{'maxchar'}{$line}||0,$char);
  return unless $v; 
  $self->{'adlookup'}{$k} ||= {}; 
  $self->{'adlookid'}{$k} ||= 1;
  my $id = $self->{'adlookup'}{$k}{$v};
  unless(defined $id) {
    $id = $self->{'adlookid'}{$k}++;
    $self->{'adlookup'}{$k}{$v} = $id;
    ($self->{'adref'}{$k}||=[""])->[$id] = $v;
  }
  $self->{'adseq'}{$line}{$k}[$char] = $id;
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
  foreach my $a (keys %{$self->{'adseq'}}) {
    foreach my $k (keys %{$self->{'adseq'}{$a}}) {
      my @rle;
      my $lastval;
      foreach my $i (0..@{$self->{'adseq'}{$a}{$k}}) {
        my $v = $self->{'adseq'}{$a}{$k}[$i];
        $v = -1 if !defined $v;
        if(@rle > 1 and $v == $lastval) {
          if((defined $rle[-1]) and $rle[-1] < 0) { $rle[-1]--; }
          else { push @rle,-1; }
        } elsif($v == -1) {
          push @rle,undef;
        } else {
          push @rle,$v;
        }
        $lastval = $v;
      }
      pop @rle if @rle and $rle[-1] and $rle[-1] < 0;
      if(@rle > 1 and !defined $rle[0] and defined $rle[1] and $rle[1]<0) {
        shift @rle;
        $rle[0]--;
      }
      if(@rle == 1 and !defined $rle[0]) {
        delete $self->{'adseq'}{$a}{$k};
      } else {
        $self->{'adseq'}{$a}{$k} = \@rle;
      }
    }
    delete $self->{'adseq'}{$a} unless keys %{$self->{'adseq'}{$a}};
  }

  # PREFIX
  foreach my $k (keys %{$self->{'adref'}}) {
    # ... sort
    my @sorted;
    foreach my $i (0..$#{$self->{'adref'}{$k}}) {
      push @sorted,[$i,$self->{'adref'}{$k}[$i]];
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
      $self->{'adref'}{$k} = \@prefixes;
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
    ref => $self->{'adref'},
    flourishes => $self->{'flourishes'}
  };
}

1;
