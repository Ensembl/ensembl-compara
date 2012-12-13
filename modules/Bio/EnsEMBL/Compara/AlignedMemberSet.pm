=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::AlignedMemberSet

=head1 DESCRIPTION

A superclass for pairwise or multiple sequence alignments of genes,
base of Family, Homology and GeneTree.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::AlignedMemberSet
  +- Bio::EnsEMBL::Compara::MemberSet

=cut

package Bio::EnsEMBL::Compara::AlignedMemberSet;

use strict;
use Scalar::Util qw(weaken);

use Bio::AlignIO;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::AlignedMember;

use base ('Bio::EnsEMBL::Compara::MemberSet');

##############################
# Constructors / Destructors #
##############################

=head2 new

  Example    :
  Description:
  Returntype : Bio::EnsEMBL::Compara::AlignedMemberSet
  Exceptions :
  Caller     :

=cut

sub new {
    my($class,@args) = @_;

    my $self = $class->SUPER::new(@args);

    if (scalar @args) {
        my ($seq_type, $aln_method, $aln_length) =
            rearrange([qw(SEQ_TYPE ALN_METHOD ALN_LENGTH)], @args);

        $seq_type && $self->seq_type($seq_type);
        $aln_method && $self->aln_method($aln_method);
        $aln_length && $self->aln_length($aln_length);
    }

    return $self;
}


#####################
# Object attributes #
#####################


=head2 seq_type

  Description : Getter/Setter for the seq_type field. This field contains
                the type of sequence used for the members. If undefined,
                the usual sequence is used. Otherwise, there must be a
                matching sequence in the other_member_sequence table.
  Returntype  : String
  Example     : my $type = $tree->seq_type();
  Caller      : General

=cut

sub seq_type {
    my $self = shift;
    $self->{'_seq_type'} = shift if(@_);
    return $self->{'_seq_type'};
}


=head2 aln_length

  Description : Getter/Setter for the aln_length field. This field contains
                the length of the alignment
  Returntype  : Integer
  Example     : my $len = $tree->aln_length();
  Caller      : General

=cut

sub aln_length {
    my $self = shift;
    $self->{'_aln_length'} = shift if(@_);
    return $self->{'_aln_length'};
}


=head2 aln_method

  Description : Getter/Setter for the aln_method field. This field should
                represent the method used for the alignment
  Returntype  : String
  Example     : my $method = $tree->aln_method();
  Caller      : General

=cut

sub aln_method {
    my $self = shift;
    $self->{'_aln_method'} = shift if(@_);
    return $self->{'_aln_method'};
}



#######################
# MemberSet interface #
#######################


=head2 member_class

  Description: Returns the type of member used in the set
  Returntype : String: Bio::EnsEMBL::Compara::AlignedMember
  Caller     : general
  Status     : Stable

=cut

sub member_class {
    return 'Bio::EnsEMBL::Compara::AlignedMember';
}


=head2 _attr_to_copy_list

  Description: Returns the list of all the attributes to be copied by deep_copy()
  Returntype : Array of String
  Caller     : General

=cut

sub _attr_to_copy_list {
    my $self = shift;
    my @sup_attr = $self->SUPER::_attr_to_copy_list();
    push @sup_attr, qw(_seq_type _aln_length _aln_method);
    return @sup_attr;
}


######################
# Alignment sections #
######################

=head2 read_clustalw

  Arg [1]    : string $file 
               The name of the file containing the clustalw output  
  Example    : $family->read_clustalw('/tmp/clustalw.aln');
  Description: Parses the output from clustalw and sets the alignment strings
               of each of the memebers of this family
  Returntype : none
  Exceptions : thrown if file cannot be parsed
               warning if alignment file contains identifiers for sequences
               which are not members of this family
  Caller     : general

=cut

sub read_clustalw {
    my $self = shift;
    my $file = shift;

    my %align_hash;
    my $FH = IO::File->new();
    $FH->open($file) || throw("Could not open alignment file [$file]");

    <$FH>; #skip header
    while(<$FH>) {
        next if($_ =~ /^\s+/);  #skip lines that start with space

        my ($id, $align) = split;
        $align_hash{$id} ||= '';
        $align_hash{$id} .= $align;
    }

    $FH->close;

    #place all members in a hash on their member name
    my %member_hash;
    foreach my $member (@{$self->get_all_Members}) {
        $member_hash{$member->stable_id} = $member;
    }

    #assign cigar_line to each of the member attribute
    foreach my $id (keys %align_hash) {
        throw("No member for alignment portion: [$id]") unless exists $member_hash{$id};

        my $alignment_string = $align_hash{$id};
        $alignment_string =~ s/\-([A-Z])/\- $1/g;
        $alignment_string =~ s/([A-Z])\-/$1 \-/g;

        my @cigar_segments = split " ",$alignment_string;

        my $cigar_line = "";
        foreach my $segment (@cigar_segments) {
            my $seglength = length($segment);
            $seglength = "" if ($seglength == 1);
            if ($segment =~ /^\-+$/) {
                $cigar_line .= $seglength . "D";
            } else {
                $cigar_line .= $seglength . "M";
            }
        }

        $member_hash{$id}->cigar_line($cigar_line);
    }
}

sub load_cigars_from_fasta {
    my ($self, $file, $import_seq) = @_;

    my $alignio = Bio::AlignIO->new(-file => "$file", -format => "fasta");

    my $aln = $alignio->next_aln or die "Bio::AlignIO could not get next_aln() from file '$file'";
    $self->aln_length($aln->length);

    #place all members in a hash on their member name
    my %member_hash;
    foreach my $member (@{$self->get_all_Members}) {
        $member->cigar_line(undef);
        $member->sequence(undef) if $import_seq;
        $member_hash{$member->member_id} = $member;
    }

    #assign cigar_line to each of the member attribute
    foreach my $seq ($aln->each_seq) {
        my $id = $seq->display_id;
        $id =~ s/_.*$//;
        throw("No member for alignment portion: [$id]") unless exists $member_hash{$id};

        my $cigar_line = '';
        my $seq_string = $seq->seq();
        while($seq_string=~/(?:\b|^)(.)(.*?)(?:\b|$)/g) {
            $cigar_line .= ($2 ? length($2)+1 : '').(($1 eq '-') ? 'D' : 'M');
        }

        $member_hash{$id}->cigar_line($cigar_line);

        if ($import_seq) {
            my $nucl_seq = $seq->seq();
            $nucl_seq =~ s/-//g;
            $member_hash{$id}->sequence($nucl_seq);
        }
    }
}



=head2 get_SimpleAlign

    Arg [-UNIQ_SEQ] : (opt) boolean (default: false)
        : whether redundant sequences should be discarded
    Arg [-CDNA] : (opt) boolean (default: false)
        : whether the CDS sequence should be used instead of the default sequence
    Arg [-ID_TYPE] (opt) string (one of 'STABLE'*, 'SEQ', 'MEMBER')
        : which identifier should be used as sequence names: the stable_id, the sequence_id, or the member_id
    Arg [-STOP2X] (opt) boolean (default: false)
        : whether the stop codons (character '*') should be replaced with gaps (character 'X')
    Arg [-APPEND_TAXON_ID] (opt) boolean (default: false)
        : whether the taxon_ids should be added to the sequence names
    Arg [-APPEND_SP_SHORT_NAME] (opt) boolean (default: false)
        : whether the species (in short name format) should be added to the sequence names
    Arg [-APPEND_GENOMEDB_ID] (opt) boolean (default: false)
        : whether the genome_db_id should be added to the sequence names
    Arg [-EXON_CASED] (opt) boolean (default: false)
        : whether the case of the sequence should change at each exon
    Arg [-KEEP_GAPS] (opt) boolean (default: false)
        : whether columns that only contain gaps should be kept in the alignment

  Example    : $tree->get_SimpleAlign(-CDNA => 1);
  Description: Returns the alignment as a BioPerl object
  Returntype : Bio::SimpleAlign
  Exceptions : none
  Caller     : general

=cut

sub get_SimpleAlign {

    my ($self, @args) = @_;

    my $id_type = 0;
    my $unique_seqs = 0;
    my $cdna = 0;
    my $stop2x = 0;
    my $append_taxon_id = 0;
    my $append_sp_short_name = 0;
    my $append_genomedb_id = 0;
    my $exon_cased = 0;
    my $keep_gaps = 0;
    if (scalar @args) {
        ($unique_seqs, $cdna, $id_type, $stop2x, $append_taxon_id, $append_sp_short_name, $append_genomedb_id, $exon_cased, $keep_gaps) =
            rearrange([qw(UNIQ_SEQ CDNA ID_TYPE STOP2X APPEND_TAXON_ID APPEND_SP_SHORT_NAME APPEND_GENOMEDB_ID EXON_CASED KEEP_GAPS)], @args);
    }

    my $sa = Bio::SimpleAlign->new();

    #Hack to try to work with both bioperl 0.7 and 1.2:
    #Check to see if the method is called 'addSeq' or 'add_seq'
    my $bio07 = ($sa->can('add_seq') ? 0 : 1);

    my $seq_id_hash = {};
    foreach my $member (@{$self->get_all_Members}) {

        next if $member->source_name eq 'ENSEMBLGENE';

        # Print unique sequences only ?
        next if($unique_seqs and $seq_id_hash->{$member->sequence_id});
        $seq_id_hash->{$member->sequence_id} = 1;

        # The correct codon table
        if ($member->chr_name =~ /mt/i) {
            # codeml icodes
            # 0:universal code (default)
            my $class;
            eval {$class = $member->taxon->classification;};
            unless ($@) {
                if ($class =~ /vertebrata/i) {
                    # 1:mamalian mt
                    $sa->{_special_codeml_icode} = 1;
                } else {
                    # 4:invertebrate mt
                    $sa->{_special_codeml_icode} = 4;
                }
            }
        }

        my $seqstr;
        my $alphabet;
        if ($cdna) {
            $seqstr = $member->cdna_alignment_string();
            $seqstr =~ s/\s+//g;
            $alphabet = 'dna';
        } elsif ($self->seq_type) {
            $seqstr = $member->alignment_string_generic($self->seq_type);
            $alphabet = 'protein';
        } else {
            $seqstr = $member->alignment_string($exon_cased);
            $alphabet = 'protein';
        }
        next if(!$seqstr);

        # Sequence name
        my $seqID = $member->stable_id;
        $seqID = $member->sequence_id if $id_type and $id_type eq 'SEQ';
        $seqID = $member->member_id if $id_type and $id_type eq 'MEMBER';
        $seqID .= "_" . $member->taxon_id if($append_taxon_id);
        $seqID .= "_" . $member->genome_db_id if ($append_genomedb_id);

        ## Append $seqID with Speciae short name, if required
        if ($append_sp_short_name) {
            my $species = $member->genome_db->short_name;
            $species =~ s/\s/_/g;
            $seqID .= "_" . $species . "_";
        }

        # Sequence length
        my $true_seq = $seqstr;
        $true_seq =~ s/-//g;
        my $aln_end = length($true_seq);

        $seqstr =~ s/\*/X/g if ($stop2x);
        my $seq = Bio::LocatableSeq->new(
                -SEQ        => $seqstr,
                -ALPHABET   => $alphabet,
                -START      => 1,
                -END        => $aln_end,
                -ID         => $seqID,
                -STRAND     => 0
        );

        if($bio07) {
            $sa->addSeq($seq);
        } else {
            $sa->add_seq($seq);
        }
    }
    $sa = $sa->remove_gaps(undef, 1) if UNIVERSAL::can($sa, 'remove_gaps') and not $keep_gaps;
    return $sa;
}



# Takes a protein tree and creates a consensus cigar line from the
# constituent leaf nodes.
sub consensus_cigar_line {

   my $self = shift;
   my @cigars;

   # First get an 'expanded' cigar string for each leaf of the subtree
   my @all_members = @{$self->get_all_Members};
   my $num_members = scalar(@all_members);
   foreach my $leaf (@all_members) {
     next unless( UNIVERSAL::can( $leaf, 'cigar_line' ) );
     my $cigar = $leaf->cigar_line;
     my $newcigar = "";
#     $cigar =~ s/(\d*)([A-Z])/$2 x ($1||1)/ge; #Expand
      while ($cigar =~ /(\d*)([A-Z])/g) {
          $newcigar .= $2 x ($1 || 1);
      }
     $cigar = $newcigar;
     push @cigars, $cigar;
   }

   # Itterate through each character of the expanded cigars.
   # If there is a 'D' at a given location in any cigar,
   # set the consensus to 'D', otherwise assume an 'M'.
   # TODO: Fix assumption that cigar strings are always the same length,
   # and start at the same point.
   my $cigar_len = length( $cigars[0] );
   my $cons_cigar;
   for( my $i=0; $i<$cigar_len; $i++ ){
     my $char = 'M';
     my $num_deletions = 0;
     foreach my $cigar( @cigars ){
       if ( substr($cigar,$i,1) eq 'D'){
         $num_deletions++;
       }
     }
     if ($num_deletions * 3 > 2 * $num_members) {
       $char = "D";
     } elsif ($num_deletions * 3 > $num_members) {
       $char = "m";
     }
     $cons_cigar .= $char;
   }

   # Collapse the consensus cigar, e.g. 'DDDD' = 4D
#   $cons_cigar =~ s/(\w)(\1*)/($2?length($2)+1:"").$1/ge;
   my $collapsed_cigar = "";
   while ($cons_cigar =~ /(D+|M+|I+|m+)/g) {
     $collapsed_cigar .= (length($1) == 1 ? "" : length($1)) . substr($1,0,1)
 }
   $cons_cigar = $collapsed_cigar;
   # Return the consensus
   return $cons_cigar;
}


my %TWOD_CODONS = ("TTT" => "Phe",#Phe
                   "TTC" => "Phe",
                   
                   "TTA" => "Leu",#Leu
                   "TTG" => "Leu",
                   
                   "TAT" => "Tyr",#Tyr
                   "TAC" => "Tyr",
                   
                   "CAT" => "His",#His
                   "CAC" => "His",

                   "CAA" => "Gln",#Gln
                   "CAG" => "Gln",
                   
                   "AAT" => "Asn",#Asn
                   "AAC" => "Asn",
                   
                   "AAA" => "Lys",#Lys
                   "AAG" => "Lys",
                   
                   "GAT" => "Asp",#Asp
                   "GAC" => "Asp",

                   "GAA" => "Glu",#Glu
                   "GAG" => "Glu",
                   
                   "TGT" => "Cys",#Cys
                   "TGC" => "Cys",
                   
                   "AGT" => "Ser",#Ser
                   "AGC" => "Ser",
                   
                   "AGA" => "Arg",#Arg
                   "AGG" => "Arg",
                   
                   "ATT" => "Ile",#Ile
                   "ATC" => "Ile",
                   "ATA" => "Ile");

my %FOURD_CODONS = ("CTT" => "Leu",#Leu
                    "CTC" => "Leu",
                    "CTA" => "Leu",
                    "CTG" => "Leu",
                    
                    "GTT" => "Val",#Val 
                    "GTC" => "Val",
                    "GTA" => "Val",
                    "GTG" => "Val",
                    
                    "TCT" => "Ser",#Ser
                    "TCC" => "Ser",
                    "TCA" => "Ser",
                    "TCG" => "Ser",
                    
                    "CCT" => "Pro",#Pro
                    "CCC" => "Pro",
                    "CCA" => "Pro",
                    "CCG" => "Pro",
                    
                    "ACT" => "Thr",#Thr
                    "ACC" => "Thr",
                    "ACA" => "Thr",
                    "ACG" => "Thr",
                    
                    "GCT" => "Ala",#Ala
                    "GCC" => "Ala",
                    "GCA" => "Ala",
                    "GCG" => "Ala",
                    
                    "CGT" => "Arg",#Arg
                    "CGC" => "Arg",
                    "CGA" => "Arg",
                    "CGG" => "Arg",
                    
                    "GGT" => "Gly",#Gly
                    "GGC" => "Gly",
                    "GGA" => "Gly",
                    "GGG" => "Gly");
                    
my %CODONS =   ("ATG" => "Met",
                "TGG" => "Trp",
                "TAA" => "TER",
                "TAG" => "TER",
                "TGA" => "TER",
                "---" => "---",
                %TWOD_CODONS,
                %FOURD_CODONS,
                );


=head2 get_4D_SimpleAlign

  Example    : $4d_align = $homology->get_4D_SimpleAlign();
  Description: get 4 times degenerate positions pairwise simple alignment
  Returntype : Bio::SimpleAlign

=cut

sub get_4D_SimpleAlign {
    my $self = shift;

    my $sa = Bio::SimpleAlign->new();

    #Hack to try to work with both bioperl 0.7 and 1.2:
    #Check to see if the method is called 'addSeq' or 'add_seq'
    my $bio07 = 0;
    if(!$sa->can('add_seq')) {
        $bio07 = 1;
    }

    my %member_seqstr;
    foreach my $member (@{$self->get_all_Members}) {
        next if $member->source_name ne 'ENSEMBLPEP';
        my $seqstr = $member->cdna_alignment_string();
        next if(!$seqstr);
        #print STDERR $seqstr,"\n";
        my @tmp_tab = split /\s+/, $seqstr;
        #print STDERR "tnp_tab 0: ", $tmp_tab[0],"\n";
        $member_seqstr{$member->stable_id} = \@tmp_tab;
    }

    my $seqstr_length;
    foreach my $seqid (keys %member_seqstr) {
        unless (defined $seqstr_length) {
            #print STDERR $member_seqstr{$seqid}->[0],"\n";
            $seqstr_length = scalar @{$member_seqstr{$seqid}};
            next;
        }
        unless ($seqstr_length == scalar @{$member_seqstr{$seqid}}) {
            die "Length of dna alignment are not the same, $seqstr_length and " . scalar @{$member_seqstr{$seqid}} ." respectively for homology_id " . $self->dbID . "\n";
        }
    }

    my %FourD_member_seqstr;
    for (my $i=0; $i < $seqstr_length; $i++) {
        my $FourD_codon = 1;
        my $FourD_aminoacid;
        foreach my $seqid (keys %member_seqstr) {
            if (defined $FOURD_CODONS{$member_seqstr{$seqid}->[$i]}) {
                if (defined $FourD_aminoacid && $FourD_aminoacid eq $FOURD_CODONS{$member_seqstr{$seqid}->[$i]}) {
                    #print STDERR "YES ",$FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
                    next;
                } elsif (defined $FourD_aminoacid) {
                    #print STDERR "NO ",$FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
                    $FourD_codon = 0;
                    last;
                } else {
                    $FourD_aminoacid = $FOURD_CODONS{$member_seqstr{$seqid}->[$i]};
                    #print STDERR $FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i]," ";
                }
                next;
            } else {
                #print STDERR "NO ",$CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
                $FourD_codon = 0;
                last;
            }
        }
        next unless ($FourD_codon);
        foreach my $seqid (keys %member_seqstr) {
            $FourD_member_seqstr{$seqid} .= substr($member_seqstr{$seqid}->[$i],2,1);
        }
    }

    foreach my $seqid (keys %FourD_member_seqstr) {

        my $seq = Bio::LocatableSeq->new(
                -SEQ    => $FourD_member_seqstr{$seqid},
                -START  => 1,
                -END    => length($FourD_member_seqstr{$seqid}),
                -ID     => $seqid,
                -STRAND => 0
        );

        if($bio07) {
            $sa->addSeq($seq);
        } else {
            $sa->add_seq($seq);
        }
    }

    return $sa;
}

my %matrix_hash;

{
  my $BLOSUM62 = "#  Matrix made by matblas from blosum62.iij
#  * column uses minimum score
#  BLOSUM Clustered Scoring Matrix in 1/2 Bit Units
#  Blocks Database = /data/blocks_5.0/blocks.dat
#  Cluster Percentage: >= 62
#  Entropy =   0.6979, Expected =  -0.5209
   A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *
A  4 -1 -2 -2  0 -1 -1  0 -2 -1 -1 -1 -1 -2 -1  1  0 -3 -2  0 -2 -1  0 -4
R -1  5  0 -2 -3  1  0 -2  0 -3 -2  2 -1 -3 -2 -1 -1 -3 -2 -3 -1  0 -1 -4
N -2  0  6  1 -3  0  0  0  1 -3 -3  0 -2 -3 -2  1  0 -4 -2 -3  3  0 -1 -4
D -2 -2  1  6 -3  0  2 -1 -1 -3 -4 -1 -3 -3 -1  0 -1 -4 -3 -3  4  1 -1 -4
C  0 -3 -3 -3  9 -3 -4 -3 -3 -1 -1 -3 -1 -2 -3 -1 -1 -2 -2 -1 -3 -3 -2 -4
Q -1  1  0  0 -3  5  2 -2  0 -3 -2  1  0 -3 -1  0 -1 -2 -1 -2  0  3 -1 -4
E -1  0  0  2 -4  2  5 -2  0 -3 -3  1 -2 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4
G  0 -2  0 -1 -3 -2 -2  6 -2 -4 -4 -2 -3 -3 -2  0 -2 -2 -3 -3 -1 -2 -1 -4
H -2  0  1 -1 -3  0  0 -2  8 -3 -3 -1 -2 -1 -2 -1 -2 -2  2 -3  0  0 -1 -4
I -1 -3 -3 -3 -1 -3 -3 -4 -3  4  2 -3  1  0 -3 -2 -1 -3 -1  3 -3 -3 -1 -4
L -1 -2 -3 -4 -1 -2 -3 -4 -3  2  4 -2  2  0 -3 -2 -1 -2 -1  1 -4 -3 -1 -4
K -1  2  0 -1 -3  1  1 -2 -1 -3 -2  5 -1 -3 -1  0 -1 -3 -2 -2  0  1 -1 -4
M -1 -1 -2 -3 -1  0 -2 -3 -2  1  2 -1  5  0 -2 -1 -1 -1 -1  1 -3 -1 -1 -4
F -2 -3 -3 -3 -2 -3 -3 -3 -1  0  0 -3  0  6 -4 -2 -2  1  3 -1 -3 -3 -1 -4
P -1 -2 -2 -1 -3 -1 -1 -2 -2 -3 -3 -1 -2 -4  7 -1 -1 -4 -3 -2 -2 -1 -2 -4
S  1 -1  1  0 -1  0  0  0 -1 -2 -2  0 -1 -2 -1  4  1 -3 -2 -2  0  0  0 -4
T  0 -1  0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -2 -1  1  5 -2 -2  0 -1 -1  0 -4
W -3 -3 -4 -4 -2 -2 -3 -2 -2 -3 -2 -3 -1  1 -4 -3 -2 11  2 -3 -4 -3 -2 -4
Y -2 -2 -2 -3 -2 -1 -2 -3  2 -1 -1 -2 -1  3 -3 -2 -2  2  7 -1 -3 -2 -1 -4
V  0 -3 -3 -3 -1 -2 -2 -3 -3  3  1 -2  1 -1 -2 -2  0 -3 -1  4 -3 -2 -1 -4
B -2 -1  3  4 -3  0  1 -1  0 -3 -4  0 -3 -3 -2  0 -1 -4 -3 -3  4  1 -1 -4
Z -1  0  0  1 -3  3  4 -2  0 -3 -3  1 -1 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4
X  0 -1 -1 -1 -2 -1 -1 -1 -1 -1 -1 -1 -1 -1 -2  0  0 -2 -1 -1 -1 -1 -1 -4
* -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4  1
";
  my $matrix_string;
  my @lines = split(/\n/,$BLOSUM62);
  foreach my $line (@lines) {
    next if ($line =~ /^\#/);
    if ($line =~ /^[A-Z\*\s]+$/) {
      $matrix_string .= sprintf "$line\n";
    } else {
      my @t = split(/\s+/,$line);
      shift @t;
      #       print scalar @t,"\n";
      $matrix_string .= sprintf(join(" ",@t)."\n");
    }
  }

#  my %matrix_hash;
  @lines = ();
  @lines = split /\n/, $matrix_string;
  my $lts = shift @lines;
  $lts =~ s/^\s+//;
  $lts =~ s/\s+$//;
  my @letters = split /\s+/, $lts;

  foreach my $letter (@letters) {
    my $line = shift @lines;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    my @penalties = split /\s+/, $line;
    die "Size of letters array and penalties array are different\n"
      unless (scalar @letters == scalar @penalties);
    for (my $i=0; $i < scalar @letters; $i++) {
      $matrix_hash{uc $letter}{uc $letters[$i]} = $penalties[$i];
    }
  }
}


sub update_alignment_stats {
    my $self = shift;

    my $genes = $self->get_all_Members;
    my $ngenes = scalar(@$genes);

    if ($ngenes == 2) {
        # This code is >4 times faster with pairs of genes

        my $gene1 = $genes->[0];
        my $gene2 = $genes->[1];
        my $new_aln1_cigarline = "";
        my $new_aln2_cigarline = "";

        my $identical_matches = 0;
        my $positive_matches = 0;

        my ($aln1state, $aln2state);
        my ($aln1count, $aln2count);
        my ($aln1cov, $aln2cov) = (0,0);

        my @aln1 = split(//, $gene1->alignment_string);
        my @aln2 = split(//, $gene2->alignment_string);

        for (my $i=0; $i <= $#aln1; $i++) {
            next if ($aln1[$i] eq '-' && $aln2[$i] eq '-');
            my $cur_aln1state = ($aln1[$i] eq '-' ? 'D' : 'M');
            my $cur_aln2state = ($aln2[$i] eq '-' ? 'D' : 'M');
            $aln1cov++ if $cur_aln1state ne 'D';
            $aln2cov++ if $cur_aln2state ne 'D';
            if ($cur_aln1state eq 'M' && $cur_aln2state eq 'M') {
                if ($aln1[$i] eq $aln2[$i]) {
                    $identical_matches++;
                    $positive_matches++;
                } elsif ($matrix_hash{uc $aln1[$i]}{uc $aln2[$i]} > 0) {
                    $positive_matches++;
                }
            }
            unless (defined $aln1state) {
                $aln1count = 1;
                $aln2count = 1;
                $aln1state = $cur_aln1state;
                $aln2state = $cur_aln2state;
                next;
            }
            if ($cur_aln1state eq $aln1state) {
                $aln1count++;
            } else {
                if ($aln1count == 1) {
                    $new_aln1_cigarline .= $aln1state;
                } else {
                    $new_aln1_cigarline .= $aln1count.$aln1state;
                }
                $aln1count = 1;
                $aln1state = $cur_aln1state;
            }
            if ($cur_aln2state eq $aln2state) {
                $aln2count++;
            } else {
                if ($aln2count == 1) {
                    $new_aln2_cigarline .= $aln2state;
                } else {
                    $new_aln2_cigarline .= $aln2count.$aln2state;
                }
                $aln2count = 1;
                $aln2state = $cur_aln2state;
            }
        }
        if ($aln1count == 1) {
            $new_aln1_cigarline .= $aln1state;
        } else {
            $new_aln1_cigarline .= $aln1count.$aln1state;
        }
        if ($aln2count == 1) {
            $new_aln2_cigarline .= $aln2state;
        } else {
            $new_aln2_cigarline .= $aln2count.$aln2state;
        }
        my $seq_length1 = $gene1->seq_length;
        unless (0 == $seq_length1) {
            $gene1->cigar_line($new_aln1_cigarline);
            $gene1->perc_id( int((100.0 * $identical_matches / $seq_length1 + 0.5)) );
            $gene1->perc_pos( int((100.0 * $positive_matches  / $seq_length1 + 0.5)) );
            $gene1->perc_cov( int((100.0 * $aln1cov / $seq_length1 + 0.5)) );
        }
        my $seq_length2 = $gene2->seq_length;
        unless (0 == $seq_length2) {
            $gene2->cigar_line($new_aln2_cigarline);
            $gene2->perc_id( int((100.0 * $identical_matches / $seq_length2 + 0.5)) );
            $gene2->perc_pos( int((100.0 * $positive_matches  / $seq_length2 + 0.5)) );
            $gene2->perc_cov( int((100.0 * $aln2cov / $seq_length2 + 0.5)) );
        }
        return undef;
    }

    my $min_seq = shift;
    $min_seq = int($min_seq * $ngenes) if $min_seq <= 1;

    my @new_cigars   = ('') x $ngenes;
    my @nmatch_id    = (0) x $ngenes; 
    my @nmatch_pos   = (0) x $ngenes; 
    my @nmatch_cov   = (0) x $ngenes; 
    my @alncount     = (1) x $ngenes;
    my @alnstate     = (undef) x $ngenes;
    my @cur_alnstate = (undef) x $ngenes;

    my @aln = map {$_->alignment_string} @$genes;
    my $aln_length = length($aln[0]);

    for (my $i=0; $i < $aln_length; $i++) {

        my @char_i =  map {substr($_, $i, 1)} @aln;
        #print "pos $i: ", join('/', @char_i), "\n";

        my %seen;
        map {$seen{$_}++} @char_i;
        next if $seen{'-'} == $ngenes;
        delete $seen{'-'};
        
        my %pos_chars = ();
        my @chars = keys %seen;
        while (my $c1 = shift @chars) {
            foreach my $c2 (@chars) {
                if (($matrix_hash{uc $c1}{uc $c2} > 0) and ($seen{$c1}+$seen{$c2} >= $min_seq)) {
                    $pos_chars{$c1} = 1;
                    $pos_chars{$c2} = 1;
                }
            }
        }

        for (my $j=0; $j<$ngenes; $j++) {
            if ($char_i[$j] eq '-') {
                $cur_alnstate[$j] = 'D';
            } else {
                $nmatch_cov[$j]++;
                $cur_alnstate[$j] = 'M';
                if ($seen{$char_i[$j]} >= $min_seq) {
                    $nmatch_id[$j]++;
                    $nmatch_pos[$j]++;
                } elsif (exists $pos_chars{$char_i[$j]}) {
                    $nmatch_pos[$j]++;
                }
            }
        }

        if ($i == 0) {
            @alnstate = @cur_alnstate;
            next;
        }

        for (my $j=0; $j<$ngenes; $j++) {
            if ($cur_alnstate[$j] eq $alnstate[$j]) {
                $alncount[$j]++;
            } else {
                if ($alncount[$j] == 1) {
                    $new_cigars[$j] .= $alnstate[$j];
                } else {
                    $new_cigars[$j] .= $alncount[$j].$alnstate[$j];
                }
                $alncount[$j] = 1;
                $alnstate[$j] = $cur_alnstate[$j];
            }
        }
    }

    for (my $j=0; $j<$ngenes; $j++) {
        if ($alncount[$j] == 1) {
            $new_cigars[$j] .= $alnstate[$j];
        } else {
            $new_cigars[$j] .= $alncount[$j].$alnstate[$j];
        }
        $genes->[$j]->cigar_line($new_cigars[$j]);
        my $seq_length = $genes->[$j]->seq_length;
        unless (0 == $seq_length) {
            $genes->[$j]->perc_id( int((100.0 * $nmatch_id[$j] / $seq_length + 0.5)) );
            $genes->[$j]->perc_pos( int((100.0 * $nmatch_pos[$j] / $seq_length + 0.5)) );
            $genes->[$j]->perc_cov( int((100.0 * $nmatch_cov[$j] / $seq_length + 0.5)) );
        }
    }
}



1;
