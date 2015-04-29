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

package EnsEMBL::Web::Text::Feature::PSL;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

use List::Util qw(min);
use List::MoreUtils qw(pairwise);

sub new {
  my( $class, $args ) = @_;
  my $extra      = {
    'matches'        => [$args->[0]],
    'miss_matches'   => [$args->[1]],
    'rep_matches'    => [$args->[2]],
    'n_matches'      => [$args->[3]],
    'q_num_inserts'  => [$args->[4]],
    'q_base_inserts' => [$args->[5]],
    't_num_inserts'  => [$args->[6]],
    'q_base_inserts' => [$args->[7]],
    'q_size'         => [$args->[10]],

  };

  return bless { '__raw__' => $args, '__extra__' => $extra }, $class;
}

sub check_format {
  my ($self, $data) = @_;
  my @lines = split(/\n/,$data);
  my $count=0;
	my $COLUMNS=21;
	map s/^\s+//,@lines;
  foreach my $line (@lines){
    $count++;
		if($line =~ /^\s*$/){next;}
    if($line !~ /^[0-9]+/){
			#allow some metadata
			if($line =~ /browser position/i){next;}
			if($line =~ /^track\s+/i){next;}
			else{
				return "File format incorrect at line $count:\"$line\"\n";
			}
		}
    my @fields = split(/\s+/,$line);
    my $numcols = scalar @fields;
    if($numcols < $COLUMNS){
      $line = join(",",@fields);
      return "\nWrong number of columns($numcols/$COLUMNS) in line $count:\"$line\"\n";
    }
  }
  return 0;
}

sub coords {
  my ($self, $data) = @_;
  return ($data->[13], $data->[15]+1, $data->[16]);
}

sub _seqname { my $self = shift; return $self->{'__raw__'}[13]; }
sub strand   { my $self = shift; return $self->_strand( substr($self->{'__raw__'}[8],-1) ); }
sub rawstart { my $self = shift; return $self->{'__raw__'}[15]+1; }
sub rawend   { my $self = shift; return $self->{'__raw__'}[16]; }
sub id       { my $self = shift; return $self->{'__raw__'}[9]; }

sub hstart   { my $self = shift; return $self->{'__raw__'}[11]; }
sub hend     { my $self = shift; return $self->{'__raw__'}[12]; }
sub hstrand  { my $self = shift; return $self->_strand( substr($self->{'__raw__'}[8],0,1)); }
sub external_data { my $self = shift; return $self->{'__extra__'} ? $self->{'__extra__'} : undef ; }

sub cigar_string {
  my $self = shift;
  return $self->{'_cigar'} if $self->{'_cigar'};
  my $raw = $self->{'__raw__'}; # readonly alias to simplify code
  # extract lists
  my ($len,$qst,$tst) = map [ split /,/, $raw->[$_] ], 18..20;
  my $num_blocks = min($raw->[17], map { scalar @$_ } ($len,$qst,$tst)); 
  splice(@$_,$num_blocks) for ($len,$qst,$tst);
  # Sort all three into tst order (may be in any order) (paranoia)
  # Uses modified Schwartzian Transform
  $qst = [ map { $_->[1] } sort { $a->[0] <=> $b->[0] } pairwise { [$a,$b] } @$tst,@$qst ];
  $len = [ map { $_->[1] } sort { $a->[0] <=> $b->[0] } pairwise { [$a,$b] } @$tst,@$len ];
  $tst = [ sort @$tst ];
  return "" unless $num_blocks;
  # If multiplying size of last block by three would take us to the end,
  # do so (assuming AA-block sizes rather than bases). Same hack at UCSC.
  my $block_end = $raw->[16]; # +ve strand
  $block_end = $raw->[14]-$raw->[15] if($self->strand < 0); # -ve strand, uses a == x-b iff x-a == b
  if(($tst->[-1]+$len->[-1]*3) == $block_end) {
    $_*= 3 for(@$qst,@$len);
  }
  # Roll cigar
  my @cigar;
  foreach (0..$num_blocks-1) {
    push @cigar,[$len->[$_],"M"];
    if($_ < $num_blocks-1) {
      push @cigar,[$tst->[$_+1] - $tst->[$_] - $len->[$_],"I"];
      push @cigar,[$qst->[$_+1] - $qst->[$_] - $len->[$_],"D"];
    }
  }
  @cigar = grep { $_->[0] } @cigar; # delete 0X
  for(@cigar) { $_->[0]='' if($_->[0] == 1); } # map 1X to X
  return $self->{'_cigar'} = join("",map { join("",@$_) } @cigar);
}

1;
