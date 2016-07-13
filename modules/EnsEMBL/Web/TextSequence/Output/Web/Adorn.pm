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

package EnsEMBL::Web::TextSequence::Output::Web::Adorn;

use strict;
use warnings;

use JSON qw(encode_json);

sub new {
  my ($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    addata => {},
    adlookup => {},
    adlookid => {},
    flourishes => {},
  };
  bless $self,$class;
  return $self;
}

sub adorn {
  my ($self,$line,$char,$k,$v) = @_; 

  $self->{'addata'}{$line}[$char]||={};
  return unless $v; 
  $self->{'adlookup'}{$k} ||= {}; 
  $self->{'adlookid'}{$k} ||= 1;
  my $id = $self->{'adlookup'}{$k}{$v};
  unless(defined $id) {
    $id = $self->{'adlookid'}{$k}++;
    $self->{'adlookup'}{$k}{$v} = $id;
  }
  $self->{'addata'}{$line}[$char]{$k} = $id;
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

sub adorn_convert {
  my ($self) = @_;

  my $adlookup = $self->{'adlookup'};
  my $addata = $self->{'addata'};
  my %adref;
  foreach my $k (keys %$adlookup) {
    $adref{$k} = [""];
    $adref{$k}->[$adlookup->{$k}{$_}] = $_ for keys $adlookup->{$k};
  }

  my %adseq;
  foreach my $ad (keys %$addata) {
    $adseq{$ad} = {};
    foreach my $k (keys %adref) {
      $adseq{$ad}{$k} = [];
      foreach (0..@{$addata->{$ad}}-1) {
        $adseq{$ad}{$k}[$_] = $addata->{$ad}[$_]{$k}//undef;
      }
    }
  }
  return (\%adseq,\%adref);
}

sub adorn_compress {
  my ($self,$adseq,$adref) = @_;

  # RLE
  foreach my $a (keys %$adseq) {
    foreach my $k (keys %{$adseq->{$a}}) {
      my @rle;
      my $lastval;
      foreach my $v (@{$adseq->{$a}{$k}}) {
        $v = -1 if !defined $v;
        if(@rle and $v == $lastval) {
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
        delete $adseq->{$a}{$k};
      } else {
        $adseq->{$a}{$k} = \@rle;
      }
    }
    delete $adseq->{$a} unless keys %{$adseq->{$a}};
  }

  # PREFIX
  foreach my $k (keys %$adref) {
    # ... sort
    my @sorted;
    foreach my $i (0..$#{$adref->{$k}}) {
      push @sorted,[$i,$adref->{$k}[$i]];
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
    foreach my $a (keys %$adseq) {
      next unless $adseq->{$a}{$k};
      my @seq;
      foreach my $v (@{$adseq->{$a}{$k}}) {
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
      $adseq->{$a}{$k} = \@seq;
      $adref->{$k} = \@prefixes;
    }
  }

  # Compress sequence
  my (@adseq_raw,@adseq);
  foreach my $k (keys %$adseq) { $adseq_raw[$k] = $adseq->{$k}; }
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

  my ($adseq,$adref) = $self->adorn_convert;
  $adseq = $self->adorn_compress($adseq,$adref);

  return {
    seq => $adseq,
    ref => $adref,
    flourishes => $self->{'flourishes'}
  };
}

1;
