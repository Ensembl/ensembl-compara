package Bio::EnsEMBL::Compara::Homology;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelation);

my %FOURD_CODONS = ("CTT" => 1,#Leu
                      "CTC" => 1,
                      "CTA" => 1,
                      "CTG" => 1,

                      "GTT" => 1,#Val 
                      "GTC" => 1,
                      "GTA" => 1,
                      "GTG" => 1,
                      
                      "TCT" => 1,#Ser
                      "TCC" => 1,
                      "TCA" => 1,
                      "TCG" => 1,

                      "CCT" => 1,#Pro
                      "CCC" => 1,
                      "CCA" => 1,
                      "CCG" => 1,

                      "ACT" => 1,#Thr
                      "ACC" => 1,
                      "ACA" => 1,
                      "ACG" => 1,

                      "GCT" => 1,#Ala
                      "GCC" => 1,
                      "GCA" => 1,
                      "GCG" => 1,

                      "CGT" => 1,#Arg
                      "CGC" => 1,
                      "CGA" => 1,
                      "CGG" => 1,

                      "GGT" => 1,#Gly
                      "GGC" => 1,
                      "GGA" => 1,
                      "GGG" => 1);
                      
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
                                     -START  => 1,
                                     -END    => length($seqstr),
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
  
  if (defined $apply_threshold_on_ds && $apply_threshold_on_ds == 0) {
    warn "Threshold on ds values is switched off. Be aware that you may obtain saturated ds values that are not to be trusted, neither the dn/ds ratio\n";
  }
  
  $self->{'_ds'} = shift if(@_);

# Threshold on ds is hardcoded here. That's really bad. I'll make for the next release
# i.e. february 2004 that the threshold is taken from the compara database
  if ($apply_threshold_on_ds) {
    if (($self->stable_id =~ /^9606_10090_\d+$/ && $self->{'_ds'} > 1.26775) ||
        ($self->stable_id =~ /^9606_10116_\d+$/ && $self->{'_ds'} > 1.27342) ||
        ($self->stable_id =~ /^10090_10116_\d+$/ && $self->{'_ds'} > 0.41278) ||
        ($self->stable_id =~ /^6239_6238_\d+$/ && $self->{'_ds'} > 4.53168)) {
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
    foreach my $seqid (keys %member_seqstr) {
      if (FourD_codon($member_seqstr{$seqid}->[$i])) {
        next;
      } else {
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

1;

