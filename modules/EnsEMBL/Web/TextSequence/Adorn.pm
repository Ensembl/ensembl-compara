package EnsEMBL::Web::TextSequence::Adorn;

use strict;
use warnings;

# This module is responsible for collecting adornment information for a
# view. There is exactly one per view. It is separate as this
# functionality is complex and independent of the other tasks of a view.
#
# It is not expected that this class will need to be overridden.

sub new {
  my ($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    addata => {},
    adlookup => {},
    adlookid => {},
    flourishes => {}
  };
  bless $self,$class;
  return $self;
}

# Methods to call to contribute adornment

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
      return 0 if defined $a->{$k}[$i] and !defined $b->{$k}[$i];
      return 0 if defined $b->{$k}[$i] and !defined $a->{$k}[$i];
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

sub data {
  my ($self) = @_;

  my ($adseq,$adref) = $self->adorn_convert;
  $adseq = $self->adorn_compress($adseq,$adref);

  return {
    seq => $adseq,
    ref => $adref,
    flourishes => $self->{'flourishes'}
  };
}

sub addata { return $_[0]->{'addata'}; }
sub adlookup { return $_[0]->{'adlookup'}; }
sub flourishes { return $_[0]->{'flourishes'}; }

1;
