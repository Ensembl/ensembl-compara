=head1 NAME

AlignedMember - DESCRIPTION of Object

=head1 DESCRIPTION

A subclass of Member which extends it to allow it to be aligned with other
AlignedMember objects.  General enough to allow for global, local, pair-wise and 
multiple alignments.  To be used primarily in NestedSet Tree data-structure.

=head1 CONTACT

Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::AlignedMember;

use strict;
#use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::Member;
our @ISA = qw(Bio::EnsEMBL::Compara::Member);

##################################
# overriden superclass methods
##################################

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy;
  bless $mycopy, "Bio::EnsEMBL::Compara::AlignedMember";
  
  $mycopy->cigar_line($self->cigar_line);
  $mycopy->cigar_start($self->cigar_start);
  $mycopy->cigar_end($self->cigar_end);
  $mycopy->perc_cov($self->perc_cov);
  $mycopy->perc_id($self->perc_id);
  $mycopy->perc_pos($self->perc_pos);
  $mycopy->method_link_species_set_id($self->method_link_species_set_id);
  
  return $mycopy;
}

sub print_node {
  my $self  = shift;
  printf("(%s %d,%d)", $self->node_id, $self->left_index, $self->right_index);

  printf(" %s", $self->genome_db->name) if($self->genome_db_id and $self->adaptor);
  if($self->gene_member) {
    printf(" %s %s %s:%d-%d",
      $self->gene_member->stable_id, $self->gene_member->display_label || '', $self->gene_member->chr_name,
      $self->gene_member->chr_start, $self->gene_member->chr_end);
  } elsif($self->stable_id) {
    printf(" (%d) %s", $self->member_id, $self->stable_id);
  }
  print("\n");
}



#####################################################

sub name {
  my $self = shift;
  return $self->stable_id(@_);
}

sub cigar_line {
  my $self = shift;
  $self->{'_cigar_line'} = shift if(@_);
  return $self->{'_cigar_line'};
}

sub cigar_start {
  my $self = shift;
  $self->{'_cigar_start'} = shift if(@_);
  return $self->{'_cigar_start'};
}

sub cigar_end {
  my $self = shift;
  $self->{'_cigar_end'} = shift if(@_);
  return $self->{'_cigar_end'};
}


sub perc_cov {
  my $self = shift;
  $self->{'perc_cov'} = shift if(@_);
  return $self->{'perc_cov'};
}

sub perc_id {
  my $self = shift;
  $self->{'perc_id'} = shift if(@_);
  return $self->{'perc_id'};
}

sub perc_pos {
  my $self = shift;
  $self->{'perc_pos'} = shift if(@_);
  return $self->{'perc_pos'};
}

sub method_link_species_set_id {
  my $self = shift;
  $self->{'method_link_species_set_id'} = shift if(@_);
  $self->{'method_link_species_set_id'} = 0 unless(defined($self->{'method_link_species_set_id'}));
  return $self->{'method_link_species_set_id'};
}


sub alignment_string {
  my $self = shift;
  my $exon_cased = shift;

  unless (defined $self->cigar_line && $self->cigar_line ne "") {
    throw("To get an alignment_string, the cigar_line needs to be define\n");
  }
  unless (defined $self->{'alignment_string'}) {
    my $sequence;
    if ($exon_cased) {
      $sequence = $self->sequence_exon_cased;
    } else {
      $sequence = $self->sequence;
    }
    if (defined $self->cigar_start || defined $self->cigar_end) {
      unless (defined $self->cigar_start && defined $self->cigar_end) {
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
  Example    : my $cdna_alignment = $aligned_member->cdna_alignment_string();
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
  my $self = shift;

  throw("can't connect to CORE to get transcript and cdna for "
        . "genome_db_id:" . $self->genome_db_id )
    unless($self->transcript);

  unless (defined $self->{'cdna_alignment_string'}) {
    
    my $cdna = $self->transcript->translateable_seq;

    if (defined $self->cigar_start || defined $self->cigar_end) {
      unless (defined $self->cigar_start && defined $self->cigar_end) {
        throw("both cigar_start and cigar_end should be defined");
      }
      my $offset = $self->cigar_start * 3 - 3;
      my $length = ($self->cigar_end - $self->cigar_start + 1) * 3;
      $cdna = substr($cdna, $offset, $length);
    }

    my $cdna_len = length($cdna);
    my $start = 0;
    my $cdna_align_string = '';

    # foreach my $pep (split(//, $self->alignment_string)) { # Speed up below
    my $alignment_string = $self->alignment_string;
    foreach my $pep (unpack("A1" x length($alignment_string), $alignment_string)) {
      if($pep eq '-') {
        $cdna_align_string .= '--- ';
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
    $self->{'cdna_alignment_string'} = $cdna_align_string
  }
  
  return $self->{'cdna_alignment_string'};
}


#############################################################
#
# orthologue and paralogue searching
#
#############################################################


sub orthologue_in_genome {
  my $self = shift;
  my $genomedb = shift;
  
  throw("[$genomedb] must be a Bio::EnsEMBL::Compara::GenomeDB object")
       unless ($genomedb and $genomedb->isa("Bio::EnsEMBL::Compara::GenomeDB"));

#  my $starttime = time();
  my $all_leaves = $self->root->get_all_leaves;
  foreach my $member (@{$all_leaves}) {
  }
  
#  printf("%1.3f secs to find orthologue\n", (time()-$starttime));
}

sub get_leaves_in_genome {
  my $self = shift;
}

1;
