=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
use warnings;

use Scalar::Util qw(weaken);

use Bio::LocatableSeq;
use Bio::AlignIO;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::Utils::Cigars;

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


=head2 load_cigars_from_file

  Arg [1]    : string $file 
               The name of the file containing the multiple alignment
  Arg [-IMPORT_SEQ] : (opt) boolean (default: false)
               Whether the sequences of the members should be reassigned
               using the alignment file
  Arg [-FORMAT]     : (opt) string (default: undef)
               The format of the alignment. By default, BioPerl will try to
               guess it from the file extension.  Refer to
               http://www.bioperl.org/wiki/HOWTO:AlignIO_and_SimpleAlign
               for a list of the supported formats.
  Example    : $family->load_cigars_from_file('/tmp/clustalw.aln');
  Description: Parses the multiple alignment fileand sets the cigar lines
               of each of the memebers of this AlignedMemberSet
  Returntype : none
  Exceptions : thrown if file cannot be parsed
               dies if a sequence identifier cannot be found in the set
               dies if there is a sequence mismatch with the set

=cut

sub load_cigars_from_file {
    my ($self, $file, @args) = @_;

    my $format;
    my $import_seq;
    if (scalar @args) {
        ($import_seq, $format) =
            rearrange([qw(IMPORT_SEQ FORMAT)], @args);
    }

    my $alignio = Bio::AlignIO->new(-file => $file, -format => $format);

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

        my $cigar_line = Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string($seq->seq());
        $member_hash{$id}->cigar_line($cigar_line);

        my $seqseq = $seq->seq();
        $seqseq =~ s/-//g;
        if ($import_seq) {
            $member_hash{$id}->sequence($seqseq);
        } else {
            die "'$id' has a different sequence in the file '$file'" if $member_hash{$id}->sequence ne $seqseq;
        }
    }
}


=head2 read_clustalw

    Description : DEPRECATED. read_clustalw() is deprecated. Please use $self->load_cigars_from_file($file, -format => 'clustalw') instead.

=cut

sub read_clustalw {  # DEPRECATED
    my $self = shift;
    my $file = shift;

    deprecate('read_clustalw() is deprecated. Please use $self->load_cigars_from_file($file, -format => \'clustalw\') instead');
    return $self->load_cigars_from_file($file, -format => 'clustalw');
}


=head2 load_cigars_from_fasta

    Description: DEPRECATED: load_cigars_from_fasta() is deprecated. Please use $self->load_cigars_from_file($file, -format => 'fasta') instead (possibly with a -import_seq argument.

=cut

sub load_cigars_from_fasta { # DEPRECATED
    my ($self, $file, $import_seq) = @_;

    deprecate('load_cigars_from_fasta() is deprecated. Please use $self->load_cigars_from_file($file, -format => \'fasta\') instead (possibly with a -import_seq argument');
    return $self->load_cigars_from_file($file, -format => 'fasta', -import_seq => $import_seq);
}


=head2 get_SimpleAlign

    Arg [-UNIQ_SEQ] : (opt) boolean (default: false)
        : whether redundant sequences should be discarded
    Arg [-CDNA] : (opt) boolean (default: false)
        : whether the CDS sequence should be used instead of the default sequence
        : This option is deprec-ated in favour of -SEQ_TYPE => 'cds'
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
        : This option is deprec-ated in favour of -SEQ_TYPE => 'exon_cased'
    Arg [-KEEP_GAPS] (opt) boolean (default: false)
        : whether columns that only contain gaps should be kept in the alignment
    Arg [-SEQ_TYPE] (opt) string
        : which sequence should be used instead of the default one.
        : Can be 'exon_cased' for proteins and ncRNAs, and 'cds' for proteins only

  Example    : $tree->get_SimpleAlign(-SEQ_TYPE => 'cds');
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
    my $seq_type = undef;
    if (scalar @args) {
        ($unique_seqs, $cdna, $id_type, $stop2x, $append_taxon_id, $append_sp_short_name, $append_genomedb_id, $exon_cased, $keep_gaps, $seq_type) =
            rearrange([qw(UNIQ_SEQ CDNA ID_TYPE STOP2X APPEND_TAXON_ID APPEND_SP_SHORT_NAME APPEND_GENOMEDB_ID EXON_CASED KEEP_GAPS SEQ_TYPE)], @args);
    }

    warn "-CDNA => 1 in AlignedMemberSet::get_SimpleAlign is deprecated. Please use -SEQ_TYPE => 'cds' instead" if $cdna;
    die "-CDNA and -SEQ_TYPE cannot be both defined in AlignedMemberSet::get_SimpleAlign" if $cdna and $seq_type;
    $seq_type = 'cds' if $cdna;

    warn "-EXON_CASED => 1 in AlignedMemberSet::get_SimpleAlign is deprecated. Please use -SEQ_TYPE => 'exon_cased' instead" if $exon_cased;
    die "-EXON_CASED and -SEQ_TYPE cannot be both defined in AlignedMemberSet::get_SimpleAlign" if $exon_cased and $seq_type;
    $seq_type = 'exon_cased' if $exon_cased;

    die "-SEQ_TYPE cannot be specified if \$self->seq_type is already defined" if $seq_type and $self->seq_type;
    $seq_type = $self->seq_type unless $seq_type;

    my $sa = Bio::SimpleAlign->new();

    #Hack to try to work with both bioperl 0.7 and 1.2:
    #Check to see if the method is called 'addSeq' or 'add_seq'
    my $bio07 = ($sa->can('add_seq') ? 0 : 1);

    my $seq_hash = {};
    foreach my $member (@{$self->get_all_Members}) {

        next if $member->source_name eq 'ENSEMBLGENE';
        next if $member->source_name =~ m/^Uniprot/i and $seq_type;

        # The correct codon table
        if ($member->chr_name and $member->chr_name =~ /mt/i) {
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

        my $seqstr = $member->alignment_string($seq_type);
        next unless $seqstr;

        # Print unique sequences only ?
        next if $unique_seqs and $seq_hash->{$seqstr};
        $seq_hash->{$seqstr} = 1;

        my $alphabet = $member->source_name eq 'ENSEMBLTRANS' ? 'dna' : 'protein';
        $alphabet = 'dna' if $seq_type and ($seq_type eq 'cds');

        # Sequence name
        my $seqID = $member->stable_id;
        $seqID = $member->sequence_id if $id_type and $id_type eq 'SEQ';
        $seqID = $member->member_id if $id_type and $id_type eq 'MEMBER';
        $seqID = $member->{_tmp_name} if $id_type and $id_type eq 'TMP';
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

    my @all_members = @{$self->get_all_Members};
    foreach my $leaf (@all_members) {
        push @cigars, $leaf->cigar_line;
    }
    return Bio::EnsEMBL::Compara::Utils::Cigars::consensus_cigar_line(@cigars);
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
        my $seqstr = $member->alignment_string('cds');
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

    # New cigars
    my @new_cigars = Bio::EnsEMBL::Compara::Utils::Cigars::minimize_cigars(map {$_->cigar_line} @$genes);
    for (my $j=0; $j<$ngenes; $j++) {
        $genes->[$j]->cigar_line($new_cigars[$j]);
    }

    my @aln = map {$_->alignment_string} @$genes;
    my $aln_length = length($aln[0]);

    my @seq_length   = (0) x $ngenes;
    my @nmatch_id    = (0) x $ngenes;
    my @nmatch_pos   = (0) x $ngenes;
    my @nmatch_cov   = (0) x $ngenes;

    if ($ngenes == 2) {
        # This code is >4 times faster with pairs of genes

        my $gene1 = $genes->[0];
        my $gene2 = $genes->[1];

        my @aln1 = split(//, $aln[0]);
        my @aln2 = split(//, $aln[1]);

        for (my $i=0; $i <= $#aln1; $i++) {
            my $gap1 = ($aln1[$i] eq '-');
            my $gap2 = ($aln2[$i] eq '-');
            $seq_length[0]++ unless $gap1;
            $seq_length[1]++ unless $gap2;
            if (not $gap1 and not $gap2) {
                $nmatch_cov[0]++;
                if ($aln1[$i] eq $aln2[$i]) {
                    $nmatch_id[0]++;
                    $nmatch_pos[0]++;
                } elsif ($matrix_hash{uc $aln1[$i]}{uc $aln2[$i]} > 0) {
                    $nmatch_pos[0]++;
                }
            }
        }

        $nmatch_id[1] = $nmatch_id[0];
        $nmatch_pos[1] = $nmatch_pos[0];
        $nmatch_cov[1] = $nmatch_cov[0];

    } else {

        my $min_seq = shift;
        $min_seq = int($min_seq * $ngenes) if $min_seq <= 1;

        for (my $i=0; $i < $aln_length; $i++) {

            my @char_i =  map {substr($_, $i, 1)} @aln;
            #print "pos $i: ", join('/', @char_i), "\n";

            my %seen;
            map {$seen{$_}++} @char_i;
            next if $seen{'-'} == $ngenes;
            my $is_cov_match = ($seen{'-'} <= $ngenes-2);
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
                if ($char_i[$j] ne '-') {
                    $seq_length[$j]++;
                    $nmatch_cov[$j]++ if $is_cov_match;
                    if ($seen{$char_i[$j]} >= $min_seq) {
                        $nmatch_id[$j]++;
                        $nmatch_pos[$j]++;
                    } elsif (exists $pos_chars{$char_i[$j]}) {
                        $nmatch_pos[$j]++;
                    }
                }
            }
        }
    }

    for (my $j=0; $j<$ngenes; $j++) {
        if ($seq_length[$j]) {
            $genes->[$j]->perc_id( int((100.0 * $nmatch_id[$j] / $seq_length[$j] + 0.5)) );
            $genes->[$j]->perc_pos( int((100.0 * $nmatch_pos[$j] / $seq_length[$j] + 0.5)) );
            $genes->[$j]->perc_cov( int((100.0 * $nmatch_cov[$j] / $seq_length[$j] + 0.5)) );
        }
    }
}



1;
