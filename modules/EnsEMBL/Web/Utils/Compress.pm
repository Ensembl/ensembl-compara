package EnsEMBL::Web::Utils::Compress;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(ecompress euncompress);

my $chars =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-";
my %unchars;
$unchars{substr($chars,$_,1)} = $_ for(0..length($chars)-1);

sub logfloor {
  my ($x) = @_;
  my $v=0;
  while($x) { $x>>=1; $v++; }
  return $v;
}

# This package is ver javascripty to keep the two implementations in sync
sub emitter {
  my $out = "";
  my $stream_bits_left = 0;
  my $next_char = 0;

  my $fn;
  $fn = {
    stream => sub {
      if($stream_bits_left!=6) { $out .= substr($chars,$next_char,1); }
      return substr($out,1);
    },
    emit_bits => sub {
      my ($input,$input_bits_left) = @_;

      while($input_bits_left) {
        $input_bits_left -= $stream_bits_left;
        if($input_bits_left>0) {
          $out .= substr($chars,$next_char|($input>>$input_bits_left),1);
          $input &= (1<<$input_bits_left)-1;
          $next_char = 0;
          $stream_bits_left = 6;
        } else {
          $next_char |= $input<<-$input_bits_left;
          $stream_bits_left = -$input_bits_left;
          last;
        }
      } 
    },
    max_emitter => sub {
      my ($M) = @_;
      my ($b,$g) = (-1,$M);
      while($g) { $g>>=1; $b++; }
      $g = 1<<$b;
      return sub {
        my ($r) = @_;
        if($r>=2*$g-$M) {
          $fn->{'emit_bits'}($r+2*$g-$M,$b+1);
        } else {
          $fn->{'emit_bits'}($r,$b);
        } 
      };
    },
    golomb_emitter => sub {
      my ($M) = @_;
      my $mx = $fn->{'max_emitter'}($M);
      return sub {
        my ($v) = @_;
        my $r = $v%$M;
        my $q = ($v-$r)/$M;
        while($q>16) { $fn->{'emit_bits'}((1<<15)-1,15); $q -= 15; }
        $fn->{'emit_bits'}(((1<<$q)-1)<<1,$q+1);
        $mx->($r);
      };
    },
    gamma_bits => sub {
      my ($v) = @_;
      my $d = logfloor($v+1)-1;
      $fn->{'emit_bits'}(((1<<$d)-1)<<1,$d+1);
      if($d) { $fn->{'emit_bits'}($v+1-(1<<$d),$d); }
    },
    huffman_encoder => sub {
      my ($counts) = @_;
      my ($code,$b,$n) = (0,-1,0);
      my @symbols;
      while($b<@$counts) {
        if(!$n) {
          do { $code *= 2; $b++ } until($b==@$counts || $counts->[$b]);
          last if($b==@$counts);
          $n = $counts->[$b];
        }
        push @symbols,[$code++,$b];
        $n--;
      } 
      return sub {
        my ($v) = @_;
        $fn->{'emit_bits'}($symbols[$v]->[0],$symbols[$v]->[1]);
      }
    },
    b_encoder => sub {
      my ($b) = @_;
      my ($b_init,$c) = ($b,0);
      return sub {
        my ($v) = @_;
        my $r = $v%(1<<$b);
        my $q = ($v-$r)/(1<<$b);
        if($q<3) {
          $fn->{'emit_bits'}(((1<<$q)-1)<<1,$q+1);
        } else {
          $fn->{'emit_bits'}(7,3);
          $fn->{'gamma_bits'}($q-3);
        }
        $fn->{'emit_bits'}($r,$b);
        if($q>0) { $c+=2; } else { $c--; }
        if($c>=2) { $b++; $c=0; }
        elsif($c<=-2) { $c=0; $b-- if $b>$b_init; }
      };
    },
  };
  return $fn;
}

sub receiver {
  my ($raw) = @_;

  my $p = -1;
  my $f = 0;
  my $v = 0;
  my $b = 4;

  my $bit = sub {
    $f >>= 1;
    if(!$f) { $p++; $v = $unchars{substr($raw,$p,1)}; $f = 32; }
    return $v&$f;
  };

  my $fn;
  $fn = {
    fixed => sub {
      my ($n) = @_;
      my $r = 0;
      $r = ($r<<1)|!!$bit->() for(0..$n-1);
      return $r;
    },
    max_receiver => sub {
      my ($M) = @_;
      my ($b,$g) = (-1,$M);
      while($g) { $g>>=1; $b++; }
      $g = 1<<$b;
      return sub {
        my $r=0;
        $r = ($r<<1)|!!$bit->() for(0..$b-1);
        if($r>=2*$g-$M) {
          $r = (($r<<1)|!!$bit->())-(2*$g-$M);
        }
        return $r;
      }; 
    },
    golomb_receiver => sub {
      my ($M) = @_;
      my $mx = $fn->{'max_receiver'}($M);
      return sub {
        my $q=0;
        while($bit->()) { $q++; }
        my $r = $mx->();
        return $q*$M+$r;
      }
    },
    gamma_bits => sub {
      my ($q,$r) = (0,0);
      while($bit->()) { $q++; }
      $r = ($r<<1)|!!$bit->() for(0..$q-1);
      return (1<<$q)+$r-1;
    },
    huffman_decoder => sub {
      my ($counts) = @_;
      my ($code,$bnum) = (0,0);
      my (@boff,@bst);
      foreach my $c (@$counts) {
        push @bst,$bnum;
        push @boff,$code;
        $code = ($code+$c)*2;
        $bnum += $c;
      }
      return sub {
        my ($x,$b) = (0,0);
        while(1) {
          if($x<$counts->[$b]+$boff[$b]) {
            return $x-$boff[$b]+$bst[$b];
          }
          $b++;
          $x = ($x<<1)|!!$bit->();
        }
      };
    },
    b_decoder => sub {
      my ($b) = @_;
      my ($c,$b_init) = (0,$b);
      return sub {
        my ($q,$r) = (0,0);
        while($q<3 && $bit->()) { $q++; }
        if($q==3) { $q = $fn->{'gamma_bits'}()+3; }
        $r = ($r<<1)|!!$bit->() for(0..$b-1);
        my $out = $q*(1<<$b)+$r;
        if($q>0) { $c+=2; } else { $c--; }
        if($c>=2) { $b++; $c=0; }
        elsif($c<=-2) { $c=0; $b-- if($b>$b_init); }
        return $out;
      };
    },
  };
  return $fn;
}

sub data_freqs {
  my ($data) = @_;

  my %rfreqs;
  foreach my $d (@$data) {
    my $e = $d; # Avoid co-ercing data to string
    ($rfreqs{$e}||=0)++;
  }
  return \%rfreqs;
}

sub extract_supremes {
  my ($rfreqs,$length) = @_;

  return [] unless $length;
  my (%hit,@supremes);
  while($length>0) {
    my $supreme;
    foreach my $k (keys %$rfreqs) {
      next if $hit{$k};
      $supreme = $k if !defined($supreme) or $rfreqs->{$k}>$rfreqs->{$supreme};
    }
    last if !defined($supreme) or 
            $rfreqs->{$supreme}<$length/2 or
            $rfreqs->{$supreme}<2;
    my $p = $rfreqs->{$supreme}/$length;
    my $M=128;
    $M = int(0.5-log(2)/log($p)) unless $p==1;
    if($M<2) { last; }
    push @supremes,{ value => $supreme, M => $M };
    $hit{$supreme} = 1;
    $length -= $rfreqs->{$supreme};
  }
  return \@supremes;
}

sub compile_hapax {
  my ($data,$rfreqs) = @_;

  return [ grep { my $e=$_; $rfreqs->{$e}==1 } @$data ];
}

sub compile_napax {
  my ($data,$rfreqs,$hapax,$supremes) = @_;

  my (%rsup,%codes,@library,@freqs);
  my $next_code = 0;
  $rsup{$_->{'value'}} = 1 for @$supremes;
  foreach my $dd (@$data) {
    my $d = $dd;
    next if $rfreqs->{$d}==1 or $rsup{$d} or defined $codes{$d};
    $codes{$d} = $next_code++;
    push @library,['r',$d];
    $freqs[$codes{$d}] = $rfreqs->{$d};
  }
  $freqs[$next_code] = $hapax;
  push @library,['h'];
  return { freqs => \@freqs, codes => \%codes, library => \@library };
}
  
sub build_library {
  my ($data) = @_;

  my $rfreqs = data_freqs($data);
  my $supremes = extract_supremes($rfreqs,scalar(@$data));
  my $hapax = compile_hapax($data,$rfreqs);
  my $napax = compile_napax($data,$rfreqs,scalar @$hapax,$supremes);
  return { lib => $napax->{'library'}, hapax => $hapax, freqs => $napax->{'freqs'}, supremes => $supremes };
}

sub calc_lengths {
  my ($freqs) = @_;

  # Initially we have n nodes. Building a tree leads to n-1 more, ie
  # 2*n-1 in n-1 steps, with the root node being the last.
  my @parents;
  my $count = $#$freqs;
  foreach my $i (0..$count-1) {
    my ($a,$b) = (-1,-1);
    foreach my $j (0..$#$freqs) {
      next if $parents[$j];
      if($a==-1 or $freqs->[$j]<$freqs->[$a]) { $b = $a; $a = $j; }
      elsif($b==-1 or $freqs->[$j]<$freqs->[$b]) { $b = $j; }
    }
    $parents[$a] = $parents[$b] = @$freqs;
    push @$freqs,$freqs->[$a]+$freqs->[$b];
  }
  # The length of the root is 0. The length of other nodes is one more
  # than their parent. All patent links are to the right, so descend.
  my @lengths;
  $lengths[$#$freqs] = 0;
  for(my $i=$#$freqs-1;$i>=0;$i--) {
    $lengths[$i] = $lengths[$parents[$i]]+1;
  }
  return [ @lengths[0..$count] ];
}

sub make_canonical {
  my ($lengths) = @_;

  my @lens = @$lengths;
  my @sorder = sort { $lens[$a] <=> $lens[$b] } (0..$#lens);
  my @cnum;
  $cnum[$_]++ for @lens;
  $cnum[$_]||=0 for(0..$#cnum); 
  return { counts => \@cnum, order => \@sorder };
}

sub sort_library {
  my ($lib,$cnums) = @_;

  return [ map { $lib->[$cnums->[$_]] } (0..$#$lib) ];
}

sub build_map {
  my ($slib,$hapax) = @_;

  my (%map,$hcode);
  foreach my $i (0..$#$slib) {
    if($slib->[$i][0] eq 'r') { $map{$slib->[$i][1]} = ['r',$i]; }
    elsif($slib->[$i][0] eq 'h') { $hcode = $i; }
  }
  foreach my $h (@$hapax) {
    $map{$h} = ['r',$hcode];
  }
  $map{'EOF'} = ['r',$hcode];
  return \%map;
}

sub emit_supremes {
  my ($em,$b,$supremes) = @_;

  $em->{'gamma_bits'}(scalar @$supremes);
  foreach my $s (@$supremes) {
    $em->{'gamma_bits'}($s->{'M'});
    my $v = $s->{'value'};
    $b->($v>=0?$v*2+1:$v*2);
  }
}

sub emit_library {
  my ($em,$b,$slib,$hapax,$supreme) = @_;

  foreach my $s (@$slib) {
    if($s->[0] eq 'r') {
      my $v = $s->[1];
      $b->($v>=0?$v*2+1:2-$v*2);
    } elsif($s->[0] eq 'h') {
      $b->(0);
    }
  }
  $b->(0);
  foreach my $h (@$hapax) {
    $b->($h>=0?$h*2+1:2-$h*2);
  }
  $b->(0);
}

sub emit_counts {
  my ($em,$counts) = @_;

  my ($i,$n) = (0,1);
  while($n) {
    my $x = $em->{'max_emitter'}($n+1);
    $x->($counts->[$i]);
    $n = ($n-$counts->[$i])*2;
    $i++;
  }
}

sub data_to_codes {
  my ($em,$data,$map,$supremes,$counts) = @_;

  my (@out,@w);
  my $v = @$supremes;
  foreach my $d ((@$data,undef)) {
    for my $j (0..$v-1) {
      $w[$j] = @out;
      push @out,[$j,0];
    }
    unless(defined $d) {
      push @out,[-1,'EOF'];
      last;
    }
    $v = -1;
    for my $j (0..$#$supremes) {
      if($d == $supremes->[$j]{'value'}) { $v = $j; last; }
    }
    if($v==-1) {
      push @out,[-1,$d];
      $v = @$supremes;
    } else {
      $out[$w[$v]]->[1]++;
    }
  }
  my $huff = $em->{'huffman_encoder'}($counts);
  my @gol;
  push @gol,$em->{'golomb_emitter'}($_->{'M'}) for @$supremes;
  foreach my $v (@out) {
    if($v->[0]==-1) {
      $huff->($map->{$v->[1]}[1]);
    }
    else { $gol[$v->[0]]->($v->[1]); }
  }
}

sub receive_library {
  my ($rc,$b) = @_;

  my @out;
  my ($n,$h,$i) = (0,-1,0);
  while(1) {
    my $v = $b->();
    if($v%2) {
      push @out,['r',($v-1)/2];
    } elsif($v) {
      push @out,['r',(2-$v)/2];
    } else {
      $n++;
      if($n==3) { last; }
      elsif($n==2) { $h = $i; }
      else { push @out,['h']; }
    }
    $i++;
  }
  my @hapax = map { $_->[1] } splice(@out,$h);
  return { lib => \@out, hapax => \@hapax };
}

sub receive_counts {
  my ($rc) = @_;

  my @out;
  my ($i,$n) = (0,1);
  while($n) {
    my $v = $rc->{'max_receiver'}($n+1)->();
    push @out,$v;
    $n = ($n-$v)*2;
  }
  return \@out;
}

sub codes_to_data {
  my ($rc,$library,$hapax,$supremes,$counts) = @_;

  my (@out,@gol);
  my $huff = $rc->{'huffman_decoder'}($counts);
  push @gol,$rc->{'golomb_receiver'}($_->{'M'}) for @$supremes;
  my @w = map { $_->() } @gol;
  my $i = 0;
  while(1) {
    my $v = -1;
    for my $j (0..$#$supremes) {
      if($w[$j]--) { $v = $j; last; }
    }
    if($v==-1) {
      $v = $library->[$huff->()];
      if($v->[0] eq 'r') { push @out,$v->[1]; }
      elsif(@$hapax) { push @out,(shift @$hapax); }
      else { last; }
      $v = @$supremes;
    } else {
      push @out,$supremes->[$v]{'value'};
    }
    $w[$_] = $gol[$_]->() for(0..$v-1);
  }
  return \@out;
}

sub receive {
  my ($rc) = @_;

  my $nsup = $rc->{'gamma_bits'}();
  my @supremes;
  my $b = $rc->{'b_decoder'}(2);
  for my $i (0..$nsup-1) {
    my $M = $rc->{'gamma_bits'}();
    my $v = $b->();
    if($v%2) { $v = ($v-1)/2; } else { $v = 1-($v/2); }
    push @supremes,{ value => $v, M => $M };
  }
  my $library = receive_library($rc,$b);
  my $counts = receive_counts($rc);
  my $out = codes_to_data($rc,$library->{'lib'},$library->{'hapax'},\@supremes,$counts);
  return $out;
}

sub ecompress {
  my ($data) = @_;

  my $lib = build_library($data);
  my $lens = calc_lengths($lib->{'freqs'});
  my $canon = make_canonical($lens);
  my $sorted = sort_library($lib->{'lib'},$canon->{'order'});
  my $map = build_map($sorted,$lib->{'hapax'});
  my $em = emitter();
  my $b = $em->{'b_encoder'}(2);
  emit_supremes($em,$b,$lib->{'supremes'});
  emit_library($em,$b,$sorted,$lib->{'hapax'});
  emit_counts($em,$canon->{'counts'});
  data_to_codes($em,$data,$map,$lib->{'supremes'},$canon->{'counts'});
  return $em->{'stream'}();
}

sub euncompress {
  my ($data) = @_;

  my $rc = receiver($data);
  return receive($rc);
}

1;
