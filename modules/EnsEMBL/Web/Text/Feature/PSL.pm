package EnsEMBL::Web::Text::Feature::PSL;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

use List::Util qw(min);

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
  my @raw = @{$self->{'__raw__'}};
  # extract lists
  my @qst = split /,/,$raw[19];
  my @tst = split /,/,$raw[20];
  my @len = split /,/,$raw[18];
  my $num_blocks = min($raw[17],scalar @qst,scalar @tst,scalar @len); 
  # rearrange into (q,t,l),(q,t,l),.... Easier to process.
  my @aligns = map { { qst => $qst[$_]+0, 
                       tst => $tst[$_]+0, 
                       len => $len[$_]+0} } (0 .. $num_blocks-1);
  return "" unless @aligns;
  # Sort into tst order (may be in any order) (paranoia)
  @aligns = sort { $a->{'tst'} <=> $b->{'tst'} } @aligns;
  # If multiplying size of last block by three would take us to the end,
  # do so (assuming AA-block sizes rather than bases). Same hack at UCSC.
  my $multiplier = 1;
  my $block_end = $raw[16]; # +ve strand
  $block_end = $raw[14]-$raw[15] if($self->strand < 0); # -ve strand, uses a == x-b iff x-a == b
  $multiplier = 3 if(($aligns[-1]->{'tst'}+$aligns[-1]->{'len'}*3) == $block_end);
  # Roll cigar
  my @cigar;
  foreach (0..$num_blocks-1) {
    push @cigar,[$aligns[$_]->{'len'} * $multiplier,"M"];
    if($_ < $num_blocks-1) {
      push @cigar,[$aligns[$_+1]->{'tst'} - $aligns[$_]->{'tst'} - $aligns[$_]->{'len'} * $multiplier,"I"];
      push @cigar,[$aligns[$_+1]->{'qst'} - $aligns[$_]->{'qst'} - $aligns[$_]->{'len'},"D"];
    }
  }
  @cigar = grep { $_->[0] } @cigar; # delete 0X
  for(@cigar) { $_->[0]='' if($_->[0] == 1); } # map 1X to X
  return $self->{'_cigar'} = join("",map { $_->[0].$_->[1] } @cigar);
}

1;
