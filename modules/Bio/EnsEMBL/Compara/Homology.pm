package Bio::EnsEMBL::Compara::Homology;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
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

#print STDERR "Number of codons: ", scalar keys %CODONS,"\n";

sub get_SimpleAlign {
  my $self = shift;
  my $alignment = shift;
  
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
    my $peptide_member = $ma->fetch_by_dbID($attribute->peptide_member_id);
    my $seqstr;
    if (defined $alignment && $alignment eq "cdna") {
      $seqstr = $attribute->cdna_alignment_string($peptide_member);
      $seqstr =~ s/\s+//g;
    } else {
      $seqstr = $attribute->alignment_string($peptide_member);
    }
    next if(!$seqstr);
    my $seq = Bio::LocatableSeq->new(-SEQ    => $seqstr,
                                     -START  => $attribute->cigar_start,
                                     -END    => $attribute->cigar_end,
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


=head2 n

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub n {
  my $self = shift;
  $self->{'_n'} = shift if(@_);
  return $self->{'_n'};
}


=head2 s

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub s {
  my $self = shift;
  $self->{'_s'} = shift if(@_);
  return $self->{'_s'};
}


=head2 lnl

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub lnl {
  my $self = shift;
  $self->{'_lnl'} = shift if(@_);
  return $self->{'_lnl'};
}

=head2 threshold_on_ds

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub threshold_on_ds {
  my $self = shift;
  $self->{'_threshold_on_ds'} = shift if(@_);
  return $self->{'_threshold_on_ds'};
}

=head2 dn

  Arg [1]    : floating $dn 
  Arg [2]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1. 
  Example    : $homology->dn
  Description: set/get the non synonymous subtitution rate
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub dn {
  my $self = shift;
  my $apply_threshold_on_ds = shift;
  
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);

  $self->{'_dn'} = shift if(@_);
  unless (defined $self->ds($apply_threshold_on_ds)) {
    return undef;
  }
  return $self->{'_dn'};
}

=head2 ds

  Arg [1]    : floating $ds
  Arg [2]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1. 
  Example    : $homology->ds
  Description: set/get the synonymous subtitution rate
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub ds {
  my $self = shift;
  my $apply_threshold_on_ds = shift;
  
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);
  
  if ($apply_threshold_on_ds == 0) {
    warn "Threshold on ds values is switched off. Be aware that you may obtain saturated ds values that are not to be trusted, neither the dn/ds ratio\n";
  }
  
  $self->{'_ds'} = shift if(@_);

  if ($apply_threshold_on_ds && defined $self->{'_ds'} && defined $self->{'_threshold_on_ds'}) {
    if ($self->{'_ds'} > $self->{'_threshold_on_ds'}) {
      return undef;
    }
  }
  return $self->{'_ds'};
}

=head2 dnds_ratio

  Arg [1]    : none
  Arg [2]    : boolean $apply_threshold_on_ds (optional, default = 1)
               Can be 0 or 1. 
  Example    : $homology->dnds_ratio
  Description: return the ratio $homology->dn/$homology->ds
  Returntype : floating
  Exceptions : 
  Caller     : 

=cut


sub dnds_ratio {
  my $self = shift;
  my $apply_threshold_on_ds = shift;
  
  $apply_threshold_on_ds = 1 unless (defined $apply_threshold_on_ds);

  my $ds;
  if ($apply_threshold_on_ds) {
    $ds = $self->ds;
  } else {
    $ds = $self->ds($apply_threshold_on_ds);
  }

  unless (defined $self->{'_dnds_ratio'}) {
    unless (defined $self->dn($apply_threshold_on_ds) &&  defined $ds && $ds != 0) {
      return undef;
    }
    $self->{'_dnds_ratio'} = sprintf("%.5f",$self->dn($apply_threshold_on_ds)/$ds);
  }
  return $self->{'_dnds_ratio'};
}

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

sub print_homology {
  my $self = shift;
  
  print("Homology : ");
  foreach my $RefArrayOfMemberAttributeArrayRef ($self->get_Member_Attribute_by_source("ENSEMBLGENE")) {
    foreach my $memAttributeArrayRef (@{$RefArrayOfMemberAttributeArrayRef}) {
      my $member = $memAttributeArrayRef->[0];
      my $attribute = $memAttributeArrayRef->[1];
      print $member->stable_id,"\t";
    }
  }
  print("\n");
}

1;

