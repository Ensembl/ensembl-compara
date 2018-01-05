=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 NAME

Bio::EnsEMBL::Compara::AlignedMemberSet

=head1 DESCRIPTION

AlignedMemberSet is a specialized version of MemberSet for members
that have a sequence and that are aligned (i.e. AlignedMember).

It is the actual base class for Family, Homology and GeneTree.
It only adds methods to deal with the alignment.

Since SeqMember can hold several sequences per member (seq_type),
AlignedMemberSet can also do so. An AlignedMemberSet defaults on a
given seq_type, but can also be mapped to another one. For instance,
the alignments of protein sequences can be transformed into alignments
of the initial CDS sequences.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::AlignedMemberSet
  `- Bio::EnsEMBL::Compara::MemberSet

=head1 SYNOPSIS

Global properties of the alignment:
 - seq_type()
 - aln_length()
 - aln_method()
 - consensus_cigar_line()

I/O:
 - load_cigars_from_file()
 - print_alignment_to_file()
 - get_SimpleAlign()
 - get_4D_SimpleAlign()

=head1 METHODS

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
use Bio::EnsEMBL::Compara::Utils::Preloader;

use Bio::Annotation::AnnotationFactory;

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
  Arg [-CHECK_SEQ] : (opt) boolean (default: false)
               Checks that all the sequences recovered from the alignment file
               match the data in the Members
  Arg [-FORMAT]     : (opt) string (default: undef)
               The format of the alignment. By default, BioPerl will try to
               guess it from the file extension.  Refer to
               http://www.bioperl.org/wiki/HOWTO:AlignIO_and_SimpleAlign
               for a list of the supported formats.
  Arg [-ID_TYPE] (opt) string (one of 'STABLE', 'SEQ', 'MEMBER'*)
                : which identifier should be used as sequence names:
                  the stable_id, the sequence_id, or the seq_member_id (default)
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
    my $id_type;
    my $check_seq;
    if (scalar @args) {
        ($import_seq, $format, $id_type, $check_seq) =
            rearrange([qw(IMPORT_SEQ FORMAT ID_TYPE CHECK_SEQ)], @args);
    }

    ## First read the alignment file and put the data in a hash
    my $alignio = Bio::AlignIO->new(-file => $file, -format => $format);
    my $aln = $alignio->next_aln or die "Bio::AlignIO could not get next_aln() from file '$file'";

    my $aln_length;
    my %aln_string_hash;
    foreach my $seq ($aln->each_seq) {

        my $id = $seq->display_id;
        $id =~ s/_.*$//;

        my $seqseq = $seq->seq();
        throw("No sequence for alignment portion: [$id]") unless $seqseq;

        $aln_length = length($seqseq) unless $aln_length;
        throw("While parsing the alignment, [$id] did not return the expected alignment length $aln_length\n") if $aln_length != length($seqseq);

        my $cigar_line = Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string($seqseq);
        throw("empty cigar_line for [$id]\n") unless length($cigar_line);

        $seqseq =~ s/-//g;

        # The following code is disabled because it slows down the method by 10%
        # We should rather have unit-testing on Bio::EnsEMBL::Compara::Utils::Cigars

        ## Check that the cigar length (Ms) matches the sequence length
        ## Take the M lengths into an array
        #my @cigar_match_lengths = map { $_ eq '' ? 1 : $_ } map { $_ =~ /^(\d*)/ } ( $cigar_line =~ /(\d*[M])/g );
        ## Sum up the M lengths
        #my $seq_cigar_length; map { $seq_cigar_length += $_ } @cigar_match_lengths;
        #if ($seq_cigar_length != length($seqseq)) {
            #warn "$id:$seq_cigar_length:".length($seqseq)."\n$seqseq\n$cigar_line\n".$seq->seq."\n";
            #$self->throw("While storing the cigar line, the returned cigar length did not match the sequence length\n");
        #}

        $aln_string_hash{$id} = [$seqseq, $cigar_line];
    }
    $self->aln_length($aln_length);

    my %unseen = (map {$_ => 1} (keys %aln_string_hash));

    ## Then we associate each member with its alignment, based on the required $id_type
    foreach my $member (@{$self->get_all_Members}) {

        my $seqID = $member->seq_member_id;
        $seqID = $member->sequence_id if $id_type and $id_type =~ m/^SEQ/i;
        $seqID = $member->stable_id if $id_type and $id_type =~ m/^STA/i;

        throw($member->stable_id." ($seqID) cannot be found in the alignment\n") unless exists $aln_string_hash{$seqID};

        my $seqseq = $aln_string_hash{$seqID}->[0];
        my $cigar_line = $aln_string_hash{$seqID}->[1];

        $member->cigar_line($cigar_line);

        if ($import_seq) {
            $member->sequence($seqseq);
        } elsif ($check_seq) {
            my $member_sequence = $member->sequence;
            if ($member_sequence ne $seqseq) {
                throw($member->stable_id." ($seqID) has a different sequence in the alignment file '$file'");
            }
        }

        delete $unseen{$seqID} if exists $unseen{$seqID};
    }

    if (scalar(keys %unseen)) {
        throw("No member for alignment ids: ".join(", ", keys %unseen));
    }
}


=head2 get_SimpleAlign

    Arg [-UNIQ_SEQ] : (opt) boolean (default: false)
        : whether redundant sequences should be discarded
    Arg [-ID_TYPE] (opt) string (one of 'STABLE'*, 'SEQ', 'MEMBER', 'DISPLAY')
        : which identifier should be used as sequence names: the stable_id, the sequence_id, the seq_member_id, or the display_label
    Arg [-STOP2X] (opt) boolean (default: false)
        : whether the stop codons (character '*') should be replaced with gaps (character 'X')
          other unusual aminoacids (U and O) are also replaced by their closest match (C and K)
    Arg [-APPEND_TAXON_ID] (opt) boolean (default: false)
        : whether the taxon_ids should be added to the sequence names
    Arg [-APPEND_SP_SHORT_NAME] (opt) boolean (default: false)
        : whether the species (in short name format) should be added to the sequence names
    Arg [-APPEND_GENOMEDB_ID] (opt) boolean (default: false)
        : whether the genome_db_id should be added to the sequence names
    Arg [-APPEND_SPECIES_TREE_NODE_ID] (opt) hashref (default:  undef)
        : a hashref {genome_db_id => SpeciesTreeNode} that is used to append species_tree_node_ids
          to the sequence names
    Arg [-REMOVE_GAPS] (opt) boolean (default: false)
        : whether columns that only contain gaps should be removed from the alignment
    Arg [-SEQ_TYPE] (opt) string
        : which sequence should be used instead of the default one.
        : Can be 'exon_cased' for proteins and ncRNAs, and 'cds' for proteins only
    Arg [-REMOVED_COLUMNS] (opt) arrayref of arrayrefs of 2 integers
        : intervals of columns that have to be filtered out from the alignment
        : Used to remove low-information sites

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
    my $stop2x = 0;
    my $append_taxon_id = 0;
    my $append_sp_short_name = 0;
    my $append_genomedb_id = 0;
    my $append_stn_id = undef;
    my $remove_gaps = 0;
    my $seq_type = undef;
    my $removed_columns = undef;
    my $removed_members = undef;
    my $map_long_seq_names = undef;
    my $annotations = undef;
    if (scalar @args) {
        ($unique_seqs,  $id_type, $stop2x, $append_taxon_id, $append_sp_short_name, $append_genomedb_id, $append_stn_id, $remove_gaps, $seq_type, $removed_columns, $removed_members, $map_long_seq_names, $annotations) =
            rearrange([qw(UNIQ_SEQ ID_TYPE STOP2X APPEND_TAXON_ID APPEND_SP_SHORT_NAME APPEND_GENOMEDB_ID APPEND_SPECIES_TREE_NODE_ID REMOVE_GAPS SEQ_TYPE REMOVED_COLUMNS REMOVED_MEMBERS MAP_LONG_SEQ_NAMES ANNOTATIONS)], @args);
    }

    die "-SEQ_TYPE cannot be specified if \$self->seq_type is already defined" if $seq_type and $self->seq_type;
    $seq_type = $self->seq_type unless $seq_type;

    my $sa = Bio::SimpleAlign->new();
    if ($self->stable_id) {
        $sa->id($self->stable_id);
    } elsif ($self->dbID) {
        my $type = ref($self);
        $type =~ s/^.*://;
        $sa->id($type."/".($self->dbID));
    } else {
        $sa->id("$self");
    }

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->adaptor->db->get_SequenceAdaptor, $seq_type, $self) if $self->adaptor;

    my $seq_hash = {};

    #Counter for the unique temporary sequence name.
    my $countSeq = 0;

    #This is to assure that we have always the same order when dumping and mapping an alignment. 
    my @all_members; 
    if ($map_long_seq_names){
        @all_members = sort {$b->dbID <=> $a->dbID} @{$self->get_all_Members};
    }else{
        @all_members = @{$self->get_all_Members};
    }

    foreach my $member (@all_members) {

        next if $member->source_name =~ m/^Uniprot/i and $seq_type;

        next if $removed_members->{$member->dbID};

        my $seqstr = $member->alignment_string($seq_type);
        next unless $seqstr;

        # Print unique sequences only ?
        next if $unique_seqs and $seq_hash->{$seqstr};
        $seq_hash->{$seqstr} = 1;

        my $alphabet = $member->source_name =~ /TRANS$/ ? 'dna' : 'protein';
        $alphabet = 'dna' if $seq_type and ($seq_type eq 'cds');

        # Sequence name
        my $prefix;
        $prefix = $member->stable_id;
        $prefix = $member->sequence_id if $id_type and $id_type =~ m/^SEQ/i;
        $prefix = $member->seq_member_id if $id_type and $id_type =~ m/^MEM/i;
        $prefix = $member->display_label if $id_type and $id_type =~ m/^DIS/i;

        my $suffix = '';
        $suffix = $member->taxon_id if($append_taxon_id);
        $suffix = $member->genome_db_id if ($append_genomedb_id);
        $suffix = $append_stn_id->{$member->genome_db_id}->node_id if ($append_stn_id);

        my $seqID;

        # Many phylogenetic methods take as input the sequence format phylip, which has a limit of 10 characters for the sequence names.
        # For those cases we need to create a mapping of the original names to be re-mapped whenever needed.
        # If map_long_seq_names is defined we need to store the mapping 
        if ($map_long_seq_names){
            #Instead, the sequence counter needs to be incremented for each sequence.
            $countSeq++;

            #Define the new sequence naming
            #Flanking with chars to assure that the \b regex will work just fine.
            $seqID = "x".$countSeq."x";

            #Store the mapping
            #Permanent sequence name
            $map_long_seq_names->{$seqID}->{'seq'} = $prefix;

            #Permanent suffix that will be used in the DB, it needs to be here to be replaced by the devived classes
            $map_long_seq_names->{$seqID}->{'suf'} = $suffix;

        }else{
            $seqID = $prefix;
            $seqID .= '_' . $suffix if $suffix;
        }

        ## Append $seqID with species short name, if required
        if ($append_sp_short_name and $member->genome_db_id) {
            my $species = $member->genome_db->get_short_name;
            $species =~ s/\s/_/g;
            $seqID .= "_" . $species;
        }

        if ($stop2x) {
            $seqstr =~ s/\*/X/g;
            if ($alphabet eq 'protein') {
                $seqstr =~ s/U/C/g;
                $seqstr =~ s/O/K/g;
            }
        }

        my $n_gaps = ($seqstr =~ tr/-/-/);

        my $seq = Bio::LocatableSeq->new(
                -SEQ        => $seqstr,
                -ALPHABET   => $alphabet,
                -START      => 1,
                -END        => length($seqstr)-$n_gaps,
                -ID         => $seqID,
                -STRAND     => 0
        );

        $sa->add_seq($seq);
    }
    $sa = $sa->remove_gaps(undef, 1) if $remove_gaps;
    $sa = $sa->remove_columns(@$removed_columns) if $removed_columns and scalar(@$removed_columns);

    #Add cutoffs annotations to the HMM stockholm file, which will be caught by hmmbuild
    if ($annotations) {
        # AnnotationCollection from the SimpleAlign object
        my $factory = Bio::Annotation::AnnotationFactory->new( -type => 'Bio::Annotation::SimpleValue' );

        foreach my $annot_tag (keys %{$annotations}) {
            my $annot_obj = $factory->create_object( -value => $annotations->{$annot_tag}, -tagname => $annot_tag );
            $sa->annotation->add_Annotation( 'custom', $annot_obj );
        }
    }

    return $sa;
}


=head2 print_alignment_to_file

  Arg [1]     : scalar (string or file handle) - output file
  Arg [-FORMAT] : string - format of the output (cf BioPerl capabilities) (example: 'fasta')
  Arg [-FLAT_DISPLAYNAME] : boolean - whether the sequence names in the alignment should be displayed "flat".
                            "flat" is a BioPerl option that means: without alignment start/end (e.g "/1-2542").
  Arg [...]   : all the other arguments of L<get_SimpleAlign>
  Example     : $family->print_alignment_to_file(-APPEND_TAXON_ID => 1);
  Description : Wrapper around get_SimpleAlign to print the alignment to a file (stdout by default)
  Returntype  : Bio::SimpleAlign
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub print_alignment_to_file {
    my ($self, $file, @args) = @_;
    my ($format, $flat_display_name) = rearrange([qw(FORMAT FLAT_DISPLAYNAME)], @args);

    my $sa = $self->get_SimpleAlign(@args);    # We assume that none of print_alignment_to_file() arguments clash with get_SimpleAlign()'s
    $sa->set_displayname_flat($flat_display_name // 1);

    my $alignIO = Bio::AlignIO->new( ref($file) ? (-fh => $file) : (-file => ">$file"), -format => $format );
    $alignIO->write_aln($sa);
    return $sa
}


=head2 consensus_cigar_line

  Example    : my $consensus_cigar = $gene_tree->consensus_cigar_line();
  Description: Creates a consensus cigar line for all the members of the
               set. See Bio::EnsEMBL::Compara::AlignedMemberSet
  Returntype : string
  Caller     : general

=cut

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
  Caller     : general

=cut

sub get_4D_SimpleAlign {
    my $self = shift;
    my $keep_gaps = shift;
    my $aa_must_be_identical = shift;

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->adaptor->db->get_SequenceAdaptor, 'cds', $self);

    my $sa = Bio::SimpleAlign->new();

    my %member_seqstr;
    foreach my $member (@{$self->get_all_Members}) {
        # Only peptides can have a CDS sequence
        next unless $member->source_name =~ /PEP$/;
        my $seqstr = $member->alignment_string('cds');
        next if(!$seqstr);
        #print STDERR $seqstr,"\n";
        $seqstr =~ s/(.{3})/$1 /g;
        my @tmp_tab =  split /\s+/, $seqstr;
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
            if (defined $FOURD_CODONS{$member_seqstr{$seqid}->[$i]} or ($keep_gaps and $member_seqstr{$seqid}->[$i] eq '---')) {
                #print STDERR "YES ",$FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
                next unless $aa_must_be_identical;

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

        $sa->add_seq($seq);
    }

    $sa = $sa->remove_gaps(undef, 1);

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


=head2 update_alignment_stats

  Arg [1]    : (optional) $seq_type
  Example    : my $consensus_cigar = $gene_tree->consensus_cigar_line();
  Description: Update the AlignedMemberSet properties (% identity, % coverage, etc)
               for the given seq_type (the default sequence is used otherwise)
  Returntype : string
  Caller     : internal

=cut

sub update_alignment_stats {
    my $self = shift;
    my $seq_type = shift;

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->adaptor->db->get_SequenceAdaptor, $seq_type, $self) if $self->adaptor;

    my $genes = $self->get_all_Members;
    my $ngenes = scalar(@$genes);

    # New cigars
    my @new_cigars = Bio::EnsEMBL::Compara::Utils::Cigars::minimize_cigars(map {$_->cigar_line} @$genes);
    for (my $j=0; $j<$ngenes; $j++) {
        $genes->[$j]->cigar_line($new_cigars[$j]);
    }

    my @aln = map {$_->alignment_string($seq_type)} @$genes;
    my $aln_length = length($aln[0]);

    my @seq_length   = (0) x $ngenes;
    my @nmatch_id    = (0) x $ngenes;
    my @nmatch_pos   = (0) x $ngenes;
    my @nmismatch    = (0) x $ngenes;

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
                if ($aln1[$i] eq $aln2[$i]) {
                    $nmatch_id[0]++;
                    $nmatch_pos[0]++;
                } elsif ($matrix_hash{uc $aln1[$i]}{uc $aln2[$i]} > 0) {
                    $nmatch_pos[0]++;
                    $nmismatch[0]++;
                } else {
                    $nmismatch[0]++;
                }
            }
        }

        $nmatch_id[1] = $nmatch_id[0];
        $nmatch_pos[1] = $nmatch_pos[0];
        $nmismatch[1] = $nmismatch[0];

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
                    if ($seen{$char_i[$j]} >= $min_seq) {
                        $nmatch_id[$j]++;
                        $nmatch_pos[$j]++;
                    } elsif (exists $pos_chars{$char_i[$j]}) {
                        $nmatch_pos[$j]++;
                        $nmismatch[$j]++;
                    } else {
                        $nmismatch[$j]++;
                    }
                }
            }
        }
    }

    for (my $j=0; $j<$ngenes; $j++) {
        if ($seq_length[$j]) {
            $genes->[$j]->num_matches( $nmatch_id[$j] );
            $genes->[$j]->num_pos_matches( $nmatch_pos[$j] );
            $genes->[$j]->num_mismatches( $nmismatch[$j] );
            $genes->[$j]->perc_id( 100.0 * $nmatch_id[$j] / $seq_length[$j] );
            $genes->[$j]->perc_pos( 100.0 * $nmatch_pos[$j] / $seq_length[$j] );
            $genes->[$j]->perc_cov( 100.0 * ($nmatch_id[$j]+$nmismatch[$j]) / $seq_length[$j] );
        }
    }
}



1;
