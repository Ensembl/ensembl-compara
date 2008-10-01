package EnsEMBL::Web::Blast::Parser;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Blast;
use EnsEMBL::Web::Blast::Result::HSP;
use EnsEMBL::Web::Blast::Result::Alignment;

#use Bio::Search::HSP::EnsemblHSP;

use Benchmark;

our @ISA = qw(EnsEMBL::Web::Blast);

sub new {
  my ($class, $parameters) = @_;
  my $self = $class->SUPER::new($parameters);
  $self->generate_cigar_strings(0);
  return $self;
}

sub parse {
  my ($self) = @_;
  my $start = new Benchmark;
  my @results = ();
  my @warnings= ();
  my $parse = 0;
  my $warning= 0;
  my $alignments = 0;
  my $alignment_stats = 0;
  my $alignment_sequence = "";
  my $parameters = 0;
  my @data = ();
  my $alignment = undef;
  my $hsp = undef;
  my $sequence_display = 0;

  open (INPUT, $self->filename);
  foreach my $line (<INPUT>) {

    if ($line =~ /Parameters:/) {
       $parameters = 1;
       $alignments = 0;
    }

    if ($line =~ /^>/) {
      $parse = 0;
      $hsp = 0;
      $alignments = 1;
      $self->results(@results);
    }

    if ($parse) {
      ## Collect any warnings
      if ($line =~ /^WARNING/) {
        $warning = 1;
      }
      if ($warning) {
        $warning = 0 if (&is_empty_line($line));
        push @warnings, $line;
      }

      if ($hsp) {
        if (&is_empty_line($line)) {
          $hsp--;
        } else {
          ## Collect HSPs from list
          # print $line;
          push @results, EnsEMBL::Web::Blast::Result::HSP->new_from_line($line);
        }
      }

    } ## end of HSP parse loop

    if ($alignments) {
      if ($line =~ /^\>/) {
        my ($ident, $type, $info) = split(/\s+/, $line);
        my ($info_type, $ncbi, $chromosome, $base_start, $base_end, $reading_frame) = split(/:/, $info); 
        $ident =~ s/^>//;
        $hsp = $self->get_hsp_by_ident($ident);
        $hsp->type($type);
        $hsp->chromosome($chromosome);
        $hsp->reading_frame($reading_frame);
      } 

      if ($line =~ /^ Score =/) {

        if ($sequence_display) {
          $sequence_display = 0; 
          $alignment->display($alignment_sequence);
          if ($self->generate_cigar_strings) { 
            $alignment->cigar_string($self->generate_cigar_string($alignment_sequence));
          }
          $hsp->add_alignment($alignment);
          $alignment_sequence = "";
        }

	# Parsing line:
        # Score = 980 (309.7 bits), Expect = 2.5e-174, Sum P(4) = 2.5e-174
        # 1     2 3   4      5      6      7 8         9   10   1112

        @data = split(/\s+/, $line);

        $alignment = (EnsEMBL::Web::Blast::Result::Alignment->new());
        $alignment->score($data[3]);
        $data[8] =~ s/,$//; 
        $alignment->probability($data[8]);
      }

      if ($line =~ /^ Identities =/) {
        # Parsing line:
        # Identities = 116/134 (86%), Positives = 120/134 (89%), Frame = -1
        # 1          2 3       4      5         6 7       8      9     1011

        @data = split(/\s+/, $line);
        my ($identities, $length) = split(/\//, $data[3]);
        my ($positives, $length_pos) = split(/\//, $data[7]);
        $alignment->identities($identities);
        $alignment->length($length);
        $alignment->positives($positives);
        $alignment->reading_frame($data[11]);
      }

      if ($line =~ /^Query: /) {
        $sequence_display++;
        if ($sequence_display == 1) { 
          my %limits = $self->limits_for_alignment_string($line);
          $alignment->query_start($limits{'start'});
        } elsif ($sequence_display > 1) { 
          my %limits = $self->limits_for_alignment_string($line);
          $alignment->query_end($limits{'end'});
        }
      }

      if ($line =~ /^Sbjct: /) {
        if ($sequence_display == 1) { 
          my %limits = $self->limits_for_alignment_string($line);
          $alignment->subject_start($limits{'start'});
        } elsif ($sequence_display > 1) { 
          my %limits = $self->limits_for_alignment_string($line);
          $alignment->subject_end($limits{'end'});
        }
      }
 
      if ($sequence_display) {
        $alignment_sequence .= $line;
      }

    }

    if ($line =~ /Sequences producing High-scoring Segment Pairs/) {
      $parse = 1;
      $hsp = 2;
    }
  }

  $self->results(());
  $self->results(@results);
  $self->warnings(@warnings);
  my $end = new Benchmark;
  #warn timestr(timediff($end,$start));  
  return (@results);
}

sub generate_cigar_string {
  my ($self, $sequence) = @_;

  my $query_sequence = "";
  my $subject_sequence = "";

  foreach my $line (split(/\n/, $sequence)) {
    if ($line =~ /^Query/) {
     $query_sequence .= $self->sequence_for_alignment_string($line);  
    }
    if ($line =~ /^Sbjct/) {
     $subject_sequence .= $self->sequence_for_alignment_string($line);  
    }
  }

  my $cigar_string = $self->prepare_cigar_string($query_sequence, $subject_sequence); 

  return $cigar_string;
}

sub prepare_cigar_string {
  my $GAP_SYMBOL = '-';
    my ($self, $qstr, $hstr) = @_;
    my @qchars = split //, $qstr;
    my @hchars = split //, $hstr;

    unless(scalar(@qchars) == scalar(@hchars)){
        $self->throw("two sequences are not equal in lengths");
    }

    $self->{_count_for_cigar_string} = 0;
    $self->{_state_for_cigar_string} = 'M';

    my $cigar_string = '';
    for(my $i=0; $i <= $#qchars; $i++){
        my $qchar = $qchars[$i];
        my $hchar = $hchars[$i];
        if($qchar ne $GAP_SYMBOL && $hchar ne $GAP_SYMBOL){ # Match
            $cigar_string .= $self->sub_cigar_string('M');
        }elsif($qchar eq $GAP_SYMBOL){ # Deletion
            $cigar_string .= $self->sub_cigar_string('D');
        }elsif($hchar eq $GAP_SYMBOL){ # Insertion
            $cigar_string .= $self->sub_cigar_string('I');
        }else{
            $self->throw("Impossible state that 2 gaps on each seq aligned");
        }
    }
    $cigar_string .= $self->sub_cigar_string('X'); # not forget the tail.
    return $cigar_string;
}

sub sub_cigar_string {
    my ($self, $new_state) = @_;

    my $sub_cigar_string = '';
    if($self->{_state_for_cigar_string} eq $new_state){
        $self->{_count_for_cigar_string} += 1; # Remain the state and increase the counter
    }else{
        $sub_cigar_string .= $self->{_count_for_cigar_string}
            unless $self->{_count_for_cigar_string} == 1;
        $sub_cigar_string .= $self->{_state_for_cigar_string};
        $self->{_count_for_cigar_string} = 1;
        $self->{_state_for_cigar_string} = $new_state;
    }
    return $sub_cigar_string;
}


sub limits_for_alignment_string {
  my ($self, $line) = @_;
  my %results = ( 'start' => undef, 'end' => undef );
  my $temp = $line;
  $temp =~ s/\s+/ /g;
  my ($trash, $start, $sequence, $end) = split(/ /, $temp); 
  $results{'start'} = $start;
  $results{'end'} = $end;
  return %results;
} 

sub sequence_for_alignment_string {
  my ($self, $line) = @_;
  my $temp = $line;
  $temp =~ s/\s+/ /g;
  my ($trash, $start, $sequence, $end) = split(/ /, $temp); 
  return $sequence;
}

sub get_hsp_by_ident {
  my ($self, $ident) = @_;
  if (!$self->results) {
    $self->parse;
  }
  foreach my $result (@{ $self->results }) {
    if ($result->ident eq $ident) {
      return $result;
    }
  }
  return 1;
}

sub is_empty_line {
  my ($line) = @_;
  chomp $line;
  if ($line eq '') {
    return 1;
  }
  return 0;
}

sub generate_cigar_strings {
  my ($self, $value) = @_;
  if ($value) {
    $self->{'generate_cigar_strings'} = $value;
  }
  return $self->{'generate_cigar_strings'};
}

1;
