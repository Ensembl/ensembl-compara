package Bio::EnsEMBL::Compara::Homology;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
use Bio::EnsEMBL::Utils::Exception;
use Bio::SimpleAlign;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelation);

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
                "---" => "---");

foreach my $codon (keys %TWOD_CODONS) {
  $CODONS{$codon} = $TWOD_CODONS{$codon};
}
foreach my $codon (keys %FOURD_CODONS) {
  $CODONS{$codon} = $FOURD_CODONS{$codon};
}

=head2 get_SimpleAlign

  Arg [1]    : string 'cdna' (optional)
  Example    : $simple_align = $homology->get_SimpleAlign();
               $cdna_s_align = $homology->get_SimpleAlign('cdna');
  Description: get pairwise simple alignment (from the multialignment)
  Returntype : Bio::SimpleAlign

=cut

sub get_SimpleAlign {
  my $self = shift;
  my $alignment = shift;
  my $changeSelenos = shift;
  unless (defined $changeSelenos) {
      $changeSelenos = 0;
  }
  
  my $sa = Bio::SimpleAlign->new();

  #Hack to try to work with both bioperl 0.7 and 1.2:
  #Check to see if the method is called 'addSeq' or 'add_seq'
  my $bio07 = 0;
  if(!$sa->can('add_seq')) {
    $bio07 = 1;
  }

  my $ma = $self->adaptor->db->get_MemberAdaptor;

  foreach my $member_attribute (@{$self->get_all_Member_Attribute}) {
    my ($member, $attribute) = @{$member_attribute};
    if ($member->chr_name =~ /mt/i) {
      # codeml icodes
      #      0:universal code (default)
      if ($member->taxon->classification =~ /vertebrata/i) {
        #      1:mamalian mt
        $sa->{_special_codeml_icode} = 1;
      } else {
        #      4:invertebrate mt
        $sa->{_special_codeml_icode} = 4;
      }
    }
    my $peptide_member = $ma->fetch_by_dbID($attribute->peptide_member_id);
    my $seqstr;
    my $alphabet = 'protein';
    if (defined $alignment && $alignment =~ /^cdna$/i) {
      $seqstr = $attribute->cdna_alignment_string($peptide_member,$changeSelenos);
      $seqstr =~ s/\s+//g;
      $alphabet = 'dna';
    } else {
      $seqstr = $attribute->alignment_string($peptide_member);
    }
    next if(!$seqstr);
    my $cigar_start = $attribute->cigar_start;
    my $cigar_end = $attribute->cigar_end;
    $cigar_start = 1 unless (defined $cigar_start);
    unless (defined $cigar_end) {
      $cigar_end = $peptide_member->seq_length;
      $cigar_end = $cigar_end*3 if ($alignment =~ /^cdna$/i);
    }
    #print STDERR "cigar_start $cigar_start cigar_end $cigar_end\n";
    my $seq = Bio::LocatableSeq->new(-SEQ    => $seqstr,
                                     -ALPHABET  => $alphabet,
                                     -START  => $cigar_start,
                                     -END    => $cigar_end,
                                     -ID     => $peptide_member->stable_id,
                                     -STRAND => 0);

    if($bio07) {
      $sa->addSeq($seq);
    } else {
      $sa->add_seq($seq);
    }
  }

  return $sa;
}


=head2 subtype

  Arg [1]    : string $subtype (optional)
  Example    : $subtype = $homology->subtype();
               $homology->subtype($subtype);
  Description: getter/setter of string description of homology subtype.
               Examples: 'DUP 1.3', 'SYN', 'complex'
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub subtype {
  my $self = shift;
  $self->{'_subtype'} = shift if(@_);
  $self->{'_subtype'} = '' unless($self->{'_subtype'});
  return $self->{'_subtype'};
}


=head2 n

  Arg [1]    : float $n (optional)
  Example    : $n = $homology->n();
               $homology->n(3);
  Description: getter/setter of number of nonsynonymous positions for the homology.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub n {
  my $self = shift;
  $self->{'_n'} = shift if(@_);
  return $self->{'_n'};
}


=head2 s

  Arg [1]    : float $s (optional)
  Example    : $s = $homology->s();
               $homology->s(4);
  Description: getter/setter of number of synonymous positions for the homology.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub s {
  my $self = shift;
  $self->{'_s'} = shift if(@_);
  return $self->{'_s'};
}


=head2 lnl

  Arg [1]    : float $lnl (optional)
  Example    : $lnl = $homology->lnl();
               $homology->lnl(-1234.567);
  Description: getter/setter of number of the negative log likelihood for the dnds homology calculation.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub lnl {
  my $self = shift;
  $self->{'_lnl'} = shift if(@_);
  return $self->{'_lnl'};
}

=head2 threshold_on_ds

  Arg [1]    : float $threshold_ond_ds (optional)
  Example    : $lnl = $homology->threshold_on_ds();
               $homology->threshold_on_ds(1.01340);
  Description: getter/setter of the threshold on ds for which the dnds ratio still makes sense.
  Returntype : float
  Exceptions : none
  Caller     : general

=cut

sub threshold_on_ds {
  my $self = shift;
  $self->{'_threshold_on_ds'} = shift if(@_);
  return $self->{'_threshold_on_ds'};
}

=head2 dn

  Arg [1]    : floating $dn (can be undef)
  Arg [2]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1.
  Example    : $homology->dn or $homology->dn(0.1209)
               if you want to retrieve dn without applying threshold_on_ds, the right call
               is $homology->dn(undef,0).
  Description: set/get the non synonymous subtitution rate
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub dn {
  my ($self, $dn, $apply_threshold_on_ds) = @_;

  $self->{'_dn'} = $dn if (defined $dn);
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);

  unless (defined $self->ds(undef, $apply_threshold_on_ds)) {
    return undef;
  }

  return $self->{'_dn'};
}

=head2 ds

  Arg [1]    : floating $ds (can be undef)
  Arg [2]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1. 
  Example    : $homology->ds or $homology->ds(0.9846)
               if you want to retrieve ds without applying threshold_on_ds, the right call
               is $homology->dn(undef,0).
  Description: set/get the synonymous subtitution rate
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub ds {
  my ($self, $ds, $apply_threshold_on_ds) = @_;

  $self->{'_ds'} = $ds if (defined $ds);
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);

  if (defined $self->{'_ds'} && 
      defined $self->{'_threshold_on_ds'} &&
      $self->{'_ds'} > $self->{'_threshold_on_ds'}) {
    
    if ($apply_threshold_on_ds) {
      return undef;
    } else {
      warning("Threshold on ds values is switched off. Be aware that you may obtain saturated ds values that are not to be trusted, neither the dn/ds ratio\n");
    }
  }

  return $self->{'_ds'};
}

=head2 dnds_ratio

  Arg [1]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1. 
  Example    : $homology->dnds_ratio or
               $homology->dnds_ratio(0) if you want to obtain a result
               even when the dS is above the threshold on dS.
  Description: return the ratio of dN/dS
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub dnds_ratio {
  my $self = shift;
  my $apply_threshold_on_ds = shift;
  
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);

  my $ds = $self->ds(undef, $apply_threshold_on_ds);
  my $dn = $self->dn(undef, $apply_threshold_on_ds);

  unless (defined $dn &&
          defined $ds &&
          $ds !=0) {
    return undef;
  }

  unless (defined $self->{'_dnds_ratio'}) {
    $self->{'_dnds_ratio'} = sprintf("%.5f",$dn/$ds);
  }

  return $self->{'_dnds_ratio'};
}


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

  my $ma = $self->adaptor->db->get_MemberAdaptor;

  my %member_seqstr;
  foreach my $member_attribute (@{$self->get_all_Member_Attribute}) {
    my ($member, $attribute) = @{$member_attribute};
    my $peptide_member = $ma->fetch_by_dbID($attribute->peptide_member_id);
    my $seqstr;
    $seqstr = $attribute->cdna_alignment_string($peptide_member);
    next if(!$seqstr);
#    print STDERR $seqstr,"\n";
    my @tmp_tab = split /\s+/, $seqstr;
#    print STDERR "tnp_tab 0: ", $tmp_tab[0],"\n";
    $member_seqstr{$peptide_member->stable_id} = \@tmp_tab;
  }
  
  my $seqstr_length;
  foreach my $seqid (keys %member_seqstr) {
    unless (defined $seqstr_length) {
 #     print STDERR $member_seqstr{$seqid}->[0],"\n";
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
      if (FourD_codon($member_seqstr{$seqid}->[$i])) {
        if (defined $FourD_aminoacid && 
            $FourD_aminoacid eq $FOURD_CODONS{$member_seqstr{$seqid}->[$i]}) {
#          print STDERR "YES ",$FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
          next;
        } elsif (defined $FourD_aminoacid) {
#          print STDERR "NO ",$FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
          $FourD_codon = 0;
          last;
        } else {
          $FourD_aminoacid = $FOURD_CODONS{$member_seqstr{$seqid}->[$i]};
#          print STDERR $FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i]," ";
        }
        next;
      } else {
#        print STDERR "NO ",$CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
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
  
    my $seq = Bio::LocatableSeq->new(-SEQ    => $FourD_member_seqstr{$seqid},
                                     -START  => 1,
                                     -END    => length($FourD_member_seqstr{$seqid}),
                                     -ID     => $seqid,
                                     -STRAND => 0);
    
    if($bio07) {
      $sa->addSeq($seq);
    } else {
      $sa->add_seq($seq);
    }
  }
  
  return $sa;
}

sub FourD_codon {
  my ($codon) = @_;
  
  if (defined $FOURD_CODONS{$codon}) {
    return 1;
  }

  return 0;
}

sub TwoD_codon {
  my ($codon) = @_;
  
  if (defined $TWOD_CODONS{$codon}) {
    return 1;
  }

  return 0;
}

=head2 print_homology

 Example    : $homology->print_homology
 Description: This method prints a short descriptor of the homology
	      USE ONLY FOR DEBUGGING not for data output since the
	      format of this output may change as need dictates.

=cut

sub print_homology {
  my $self = shift;
  
  printf("Homology %d,%s,%s : ", $self->dbID, $self->description, $self->subtype);
  foreach my $member_attribute (@{$self->get_all_Member_Attribute}) {
    my ($member, $attribute) = @{$member_attribute};
    printf("%s(%d)\t", $member->stable_id, $member->dbID);
  }
  print("\n");
}


=head2 get_all_PeptideAlignFeature

  Example    : my ($paf) = @{$homology->get_all_PeptideAlignFeature};
               my ($paf, $recipPaf) = @{$homology->get_all_PeptideAlignFeature};
  Description: return the peptide_align_feature object (and its reciprocal hit)
               used to create this homology
  Returntype : array ref of peptide_align_feature objects
  Exceptions :
  Caller     :

=cut

sub get_all_PeptideAlignFeature {
  my $self = shift;

  my @pafs;
  throw("homology must have a valid adaptor and db in order to get peptide_align_features")
    unless($self->adaptor and $self->adaptor->db);
  my $pafDBA = $self->adaptor->db->get_PeptideAlignFeatureAdaptor;
  
  foreach my $RefArrayOfMemberAttributeArrayRef ($self->get_Member_Attribute_by_source("ENSEMBLGENE")) {
    foreach my $memAttributeArrayRef (@{$RefArrayOfMemberAttributeArrayRef}) {
      my $member = $memAttributeArrayRef->[0];
      my $attribute = $memAttributeArrayRef->[1];

      if($attribute->peptide_align_feature_id) {
        my $paf = $pafDBA->fetch_by_dbID($attribute->peptide_align_feature_id);
        push @pafs, $paf;
      }
    }
  }
  return \@pafs;
}


=head2 has_species_by_name

  Arg [1]    : string $species_name
  Example    : my $ret = $homology->has_species_by_name("Homo sapiens");
  Description: return TRUE or FALSE whether one of the members in the homology is from the given species
  Returntype : 1 or 0
  Exceptions :
  Caller     :

=cut


sub has_species_by_name {
  my $self = shift;
  my $species_name = shift;
  
  foreach my $member_attribute (@{$self->get_all_Member_Attribute}) {
    my ($member, $attribute) = @{$member_attribute};
    return 1 if($member->genome_db->name eq $species_name);
  }
  return 0;
}


=head2 gene_list

  Example    : my $pair = $homology->gene_list
  Description: return the pair of members for the homology
  Returntype : array ref of (2) Bio::EnsEMBL::Compara::Member objects
  Caller     : general

=cut


sub gene_list {
  my $self = shift;
  my @genes;
  foreach my $member_attribute (@{$self->get_all_Member_Attribute}) {
    my ($member, $attribute) = @{$member_attribute};
    push @genes, $member;
  }
  return \@genes;
}


=head2 homology_key

  Example    : my $key = $homology->homology_key;
  Description: returns a string uniquely identifying this homology in world space.
               uses the gene_stable_ids of the members and orders them by taxon_id
               and concatonates them together.  
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub homology_key {
  my $self = shift;
  return $self->{'_homology_key'} if(defined($self->{'_homology_key'}));
  
  my @genes;
  foreach my $member_attribute (@{$self->get_all_Member_Attribute}) {
    my ($member, $attribute) = @{$member_attribute};
    push @genes, $member;
  }
  @genes = sort {$a->taxon_id <=> $b->taxon_id || $a->stable_id cmp $b->stable_id} @genes;
  @genes = map ($_->stable_id, @genes);

  my $homology_key = join('_', @genes);
  return $homology_key;
}

=head2 node_id

  Arg [1]    : int $node_id (optional)
  Example    : $node_id = $homology->node_id();
               $homology->subtype($node_id);
  Description: getter/setter of integer that refer to a node_id in the protein_tree data.
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub node_id {
  my $self = shift;

  $self->{'_node_id'} = shift if(@_);
  $self->{'_node_id'} = '' unless($self->{'_node_id'});
  return $self->{'_node_id'};
  
}

1;

