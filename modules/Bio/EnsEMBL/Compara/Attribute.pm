package Bio::EnsEMBL::Compara::Attribute;

use strict;
use Carp;
use Bio::EnsEMBL::Utils::Exception;

our ($AUTOLOAD, %ok_field);

%ok_field = ('member_id' => 1,
             'family_id' => 1,
             'cigar_line' => 1,
             'cigar_start' => 1,
             'cigar_end' => 1,
             'domain_id' => 1,
             'member_start' => 1,
             'member_end' => 1,
             'homology_id' => 1,
             'peptide_member_id' => 1,
             'perc_cov' => 1,
             'perc_id' => 1,
             'perc_pos' => 1,
             'peptide_align_feature_id' => 1
             );


sub new {
  my ($class) = @_;

  return bless {}, $class;
}

=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype : 
  Exceptions : none
  Caller     : 

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}

sub AUTOLOAD {
  my $self = shift;
  my $method = $AUTOLOAD;
  $method =~ s/.*:://;
  croak "invalid method: ->$method()" unless $ok_field{$method};
  $self->{lc $method} = shift if(@_);
  return $self->{lc $method};
}

sub alignment_string {
  my ($self, $member) = @_;

  

  unless (defined $self->cigar_line) {
    throw("To get an alignment_string, the cigar_line needs to be define\n");
  }
  unless (defined $member) {
    throw("To get an alignment_string, the peptide member needs to be passed as an option\n");
  }

  unless (defined $self->{'alignment_string'}) {
    my $sequence = $member->sequence;
    if ((defined($self->cigar_start) && ($self->cigar_start != 0)) 
        || (defined $self->cigar_end  && ($self->cigar_end != 0))) {
      unless ((defined($self->cigar_start) && ($self->cigar_start != 0)) && 
               (defined $self->cigar_end  && ($self->cigar_end != 0))) {
#     if (defined $self->cigar_start || defined $self->cigar_end) {
#       unless (defined $self->cigar_start && defined $self->cigar_end) {
        throw("both cigar_start and cigar_end should be defined");
      }
      my $offset = $self->cigar_start - 1;
      my $length = $self->cigar_end - $self->cigar_start + 1;
      $sequence = substr($sequence, $offset, $length);
    }

    my $cigar_line = $self->cigar_line;
    $cigar_line =~ s/([MD])/$1 /g;

    my @cigar_segments = split " ",$cigar_line;
    my $alignment_string = "";
    my $seq_start = 0;
    foreach my $segment (@cigar_segments) {
      if ($segment =~ /^(\d*)D$/) {
        my $length = $1;
        $length = 1 if ($length eq "");
        $alignment_string .= "-" x $length;
      } elsif ($segment =~ /^(\d*)M$/) {
        my $length = $1;
        $length = 1 if ($length eq "");
        $alignment_string .= substr($sequence,$seq_start,$length);
        $seq_start += $length;
      }
    }
    $self->{'alignment_string'} = $alignment_string;
  }

  return $self->{'alignment_string'};
}

=head2 cdna_alignment_string

  Arg [1]    : none
  Example    : my $cdna_alignment = $family_member->cdna_alignment_string();
  Description: Converts the peptide alignment string to a cdna alignment
               string.  This only works for EnsEMBL peptides whose cdna can
               be retrieved from the attached EnsEMBL databse.
               If the cdna cannot be retrieved undef is returned and a
               warning is thrown.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub cdna_alignment_string {
  my ($self, $member, $changeSelenos) = @_;
  unless (defined $changeSelenos) {
      $changeSelenos = 0;
  }

  if($member->source_name ne 'ENSEMBLPEP') {
    warning("Don't know how to retrieve cdna for database [@{[$member->source_name]}]
      SPECIES @{[ $member->adaptor->db->get_GenomeDBAdaptor->fetch_by_dbID($member->genome_db_id)->db_adaptor->dbname ]}" );
    return undef;
  }

  unless (defined $self->{'cdna_alignment_string'}) {
    my $genome_db_id = $member->genome_db_id;
    
    my $genome_db =
      $member->adaptor->db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
    
    my $ta = $genome_db->db_adaptor->get_TranscriptAdaptor;
    my $transcript;
    if ($member->stable_id =~ /^\d+$/) {
      $transcript = $ta->fetch_by_translation_id($member->stable_id);
    } else {
      $transcript = $ta->fetch_by_translation_stable_id($member->stable_id);
    }
    if(!$transcript) {
      warning("Could not retrieve transcript via peptide id [" .
                  $member->stable_id . "] from database [" .
                  $genome_db->db_adaptor->dbname . "]");
      return undef;
    }
    
    my $cdna = $transcript->translateable_seq;

    if (defined $self->cigar_start || defined $self->cigar_end) {
      unless (defined $self->cigar_start && defined $self->cigar_end) {
        throw("both cigar_start and cigar_end should be defined");
      }
      my $offset = $self->cigar_start * 3 - 3;
      my $length = ($self->cigar_end - $self->cigar_start + 1) * 3;
      $cdna = substr($cdna, $offset, $length);
    }

    my $start = 0;
    my $cdna_align_string = '';

    foreach my $pep (split(//,$self->alignment_string($member))) {
      
      if($pep eq '-') {
        $cdna_align_string .= '--- ';
      } elsif ($pep eq 'U' && $changeSelenos or $pep eq '*') {
	$cdna_align_string .= 'NNN ';
	$start += 3;  
      } else {
        my $codon = substr($cdna, $start, 3);
        unless (length($codon) == 3) {
          # sometimes the last codon contains only 1 or 2 nucleotides.
          # making sure that it has 3 by adding as many Ns as necessary
          $codon .= 'N' x (3 - length($codon));
        }
        $cdna_align_string .= $codon . ' ';
        $start += 3;
      }
    }
    $self->{'cdna_alignment_string'} = $cdna_align_string;
  }
  
  return $self->{'cdna_alignment_string'};
}

sub DESTROY {}

1;
