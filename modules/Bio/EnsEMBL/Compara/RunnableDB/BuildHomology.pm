#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BuildHomology

=cut
=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::BuildHomology->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->write_output(); #writes to DB

=cut
=head1 DESCRIPTION

This object interfaces with a Compara schema database.  It works from a
previously filled set of tables (member, peptide_align_feature) and
analyzes the alignment features for BRH (best reciprocal hits) and
RHS (reciprocal hits based on synteny)

Since the object can do all analysis in perl, there is no Runnable, and
all work is to be done here and with loaded perl modules

=cut
=head1 CONTACT

  Jessica Severin : jessica@ebi.ac.uk

=cut
=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BuildHomology;

use strict;
#use Statistics::Descriptive;
use Time::HiRes qw(gettimeofday tv_interval);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Pipeline::RunnableDB;

use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::Compara::Functions;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   none
    Returns :   none
    Args    :   none

=cut

sub fetch_input
{
  my $self = shift;

  # input_id is Compara_db=1 => work on whole compara database so essentially
  # has no value, so just ignore

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
                           -DBCONN => $self->db);

  $self->{'blast_analyses'} = ();
  $self->{'verbose'} = 0;
  $self->{'store'} = 1;
  $self->{'getAllRHS'} = undef;

  print("input_id = " . $self->input_id . "\n");
  
  if($self->input_id =~ ',') {
    $self->load_blasts_from_input();
  }
  elsif($self->input_id eq 'all'){
    # not in pair format, so load all blasts for processing
    $self->load_all_blasts();
  }

  print("blasts :\n");
  foreach my $analysis (@{$self->{'blast_analyses'}}) {
    print("   ".$analysis->logic_name."\n");
  }

  return 1;
}


sub run
{
  my $self = shift;

  my @blast_list = @{$self->{'blast_analyses'}};

  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;

  if($self->input_id eq 'test'){ $self->test_RHS; exit(1); }
  
  while(@blast_list) {
    my $blast1 = shift @blast_list;
    foreach my $blast2 (@blast_list) {
      print("   check pair ".$blast1->logic_name." <=> ".$blast2->logic_name."\n");

      $self->{'qmember_PAF_BRH_hash'} = {};
      $self->{'membersToBeProcessed'} = {};
   
      $self->set_member_list($blast1);
      $self->set_member_list($blast2);

      my $genome_db_id = parse_as_hash($blast1->parameters)->{'genome_db_id'};
      #$self->calc_inter_genic_distance($genome_db_id);

      $self->get_BRH_for_species_pair($blast1, $blast2);

      my @mkeys = keys %{$self->{'membersToBeProcessed'}};
      print($#mkeys . " members to be processed for RHS\n");

      $self->find_RHS_for_species_pair($blast1, $blast2);
      $self->find_RHS_for_species_pair($blast2, $blast1);

    }
  }

  return 1;
}

sub write_output
{
  my( $self) = @_;

  return 1;
}

####################################
#
# Specific analysis code below
#
####################################


sub set_member_list
{
  # using trick of specifying table twice so can join to self
  my $self      = shift;
  my $analysis = shift;

  print(STDERR "set_member_list from analysis ".$analysis->logic_name()."\n");

  my $subset_id = parse_as_hash($analysis->parameters)->{'subset_id'};

  my $subset = $self->{'comparaDBA'}->get_SubsetAdaptor->fetch_by_dbID($subset_id);
  foreach my $member_id (@{$subset->member_id_list}) {
    $self->{'membersToBeProcessed'}->{$member_id} = $member_id;  #like an STL set
  }
  my @mkeys = keys %{$self->{'membersToBeProcessed'}};
  print("  count ". $#mkeys . "\n");
}


sub get_BRH_for_species_pair
{
  # using trick of specifying table twice so can join to self
  my $self      = shift;
  my $analysis1 = shift;
  my $analysis2 = shift;

  print(STDERR "select BRH\n");
  print(STDERR "  analysis1 ".$analysis1->logic_name()."\n");
  print(STDERR "  analysis2 ".$analysis2->logic_name()."\n");
  
  my $sql = "SELECT paf1.peptide_align_feature_id, paf2.peptide_align_feature_id, ".
            " paf1.qmember_id, paf1.hmember_id ".
            " FROM peptide_align_feature paf1, peptide_align_feature paf2 ".
            " WHERE paf1.qmember_id=paf2.hmember_id ".
            " AND paf1.hmember_id=paf2.qmember_id ".
            " AND paf1.hit_rank=1 AND paf2.hit_rank=1 ".
            " AND paf1.analysis_id = ".$analysis1->dbID.
            " AND paf2.analysis_id = ".$analysis2->dbID;

  print("$sql\n");
  my $startTime = time();
  my $sth = $self->{'comparaDBA'}->prepare($sql);
  $sth->execute();
  print(time()-$startTime . " sec to query\n");

  my ($paf1_id, $paf2_id, $qmember_id, $hmember_id);
  $sth->bind_columns(\$paf1_id, \$paf2_id, \$qmember_id, \$hmember_id);

  my @paf_id_list;
  while ($sth->fetch()) {
    my @pair = ($paf1_id, $paf2_id);
    push @paf_id_list, \@pair;
  }
  $sth->finish;
  print(time()-$startTime . " sec to query and fetch\n");
  
  print("  found ".($#paf_id_list + 1).
        " BRH for reciprocal blasts for pair ".
        $analysis1->logic_name." and ".
        $analysis2->logic_name."\n");

  print("  CONVERT PAF => Homology objects and store\n");
  my $pafDBA      = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor();
  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor();

  $startTime = time();
  foreach my $pair (@paf_id_list) {
    my ($paf1_id, $paf2_id) = @{$pair};
    my $paf1 = $pafDBA->fetch_by_dbID($paf1_id);
    print("BRH : "); $paf1->display_short;

    my $homology = $paf1->return_as_homology();
    $homology->description('BRH');
    eval { $homologyDBA->store($homology) if($self->{'store'}); };

    my $paf2 = $pafDBA->fetch_by_dbID($paf2_id);
    $self->{'qmember_PAF_BRH_hash'}->{$paf1->query_member->dbID} = $paf1;
    $self->{'qmember_PAF_BRH_hash'}->{$paf2->query_member->dbID} = $paf2;
    delete $self->{'membersToBeProcessed'}->{$paf1->query_member->dbID};
    delete $self->{'membersToBeProcessed'}->{$paf1->hit_member->dbID};
  }
  print(time()-$startTime . " sec to convert PAF to Homology\n");
}


sub load_all_blasts
{
  my $self = shift;
  
  my @analyses = @{$self->db->get_AnalysisAdaptor->fetch_all()};
  $self->{'blast_analyses'} = ();
  #print("analyses :\n");
  foreach my $analysis (@analyses) {
    #print("   ".$analysis->logic_name."\n");
    if($analysis->logic_name =~ /blast_\d+/) {
      push @{$self->{'blast_analyses'}}, $analysis;
    }
  }
}


sub load_blasts_from_input
{
  my $self = shift;

  print("load_blasts_from_input\n");
  my $input = $self->input_id;
  $input =~ s/\s//g;
  my @logic_names = split(/,/ , $input);
  foreach my $logic_name (@logic_names) {
    my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);
    if($analysis->logic_name =~ /blast_\d+/) {
      push @{$self->{'blast_analyses'}}, $analysis;
    }
  }
}


##################################
#
# Synteny section
#
##################################

sub find_RHS_for_species_pair
{
  # using trick of specifying table twice so can join to self
  my $self      = shift;
  my $analysis1 = shift;  # query species (get subset_id)
  my $analysis2 = shift;  # db species (analysis_id, ie blast)

  print(STDERR "select RHS\n");
  print(STDERR "  analysis1 ".$analysis1->logic_name()."\n");
  print(STDERR "  analysis2 ".$analysis2->logic_name()."\n");

  my $subset_id = parse_as_hash($analysis1->parameters)->{'subset_id'};

  #
  # fetch the peptide members (via subset) ordered on chromosomes
  # then convert into synenty_segments (again of peptide members)
  #
  print("about to fetch members\n") if($self->{'verbose'});
  my $startTime = time();
  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor();
  $memberDBA->_final_clause("ORDER BY m.chr_name, m.chr_start");
  my $sortedMembers = $memberDBA->fetch_by_subset_id($subset_id);
  print(time()-$startTime . " sec memberDBA->fetch_by_subset_id\n") if($self->{'verbose'});
  print(scalar(@{$sortedMembers}) . " members to process for RHS\n");

  my $syntenySegment = $self->get_next_syneny_segment($sortedMembers);
  while($syntenySegment) {
    # do my processing of synteny
    $self->print_synteny_segement($syntenySegment) if($self->{'verbose'});
    $self->process_synteny_segement($syntenySegment);
    
    #get next segment
    $syntenySegment = $self->get_next_syneny_segment($sortedMembers);
  }

}


sub get_next_syneny_segment
{
  my $self            = shift;
  my $sortedMembers   = shift;  #list reference

  #
  # now loop through the members creating synteny segments
  # a synteny segment is store as a list of Member objects
  # possbilities
  #  1) list of members bounded on both ends by BRH that are syntenous
  #  2) list of members where bounded on one end by a BRH
  # Breaks occur when, BRH breaks synteny, or members switch chromosomes

  return undef
    unless($sortedMembers and @{$sortedMembers}); #undefined or list empty
  
  my @syntenySegment = ();

  #print("get_next_syneny_segment\n");
  
  my $firstMember = shift @{$sortedMembers};
  return undef
    unless($firstMember); #undefined or list empty
  
  push @syntenySegment, $firstMember;
  #$self->print_member($firstMember, "FIRST_MEMBER\n");

  #print("Extend synteny\n");
  while($sortedMembers and @{$sortedMembers}) { 
    my $member = $sortedMembers->[0];
    #$self->print_member($member, " PEEK\n");
    if($member->chr_name ne $firstMember->chr_name) {
      #print("  END: changed chromosome\n");
      last;
    }

    if($self->{'qmember_PAF_BRH_hash'}->{$member->dbID}) {
      #print("  END: hit BRH, stop growing segment\n");
      push @syntenySegment, $member;
      last;
    }
    
    push @syntenySegment, $member;
    shift @{$sortedMembers};
  }
  
  if(@syntenySegment) { return \@syntenySegment; }

  #print("syntenySegment empty\n");
  return undef;
}


sub print_synteny_segement
{
  my $self = shift;
  my $syntenySegment = shift;

  return unless($syntenySegment and @{$syntenySegment});

  print("synteny_segment\n");
  if(scalar(@{$syntenySegment}) > 10) {
    $self->print_member($syntenySegment->[0]);
    $self->print_member($syntenySegment->[scalar(@{$syntenySegment})-1]);
  }
  else {
    foreach my $member (@{$syntenySegment}) {
      $self->print_member($member);
    }
  }
}


sub process_synteny_segement
{
  my $self = shift;
  my $syntenySegmentRef = shift;

  print("process_synteny_segement\n");
  
  return unless($syntenySegmentRef and @{$syntenySegmentRef});
  my @syntenySegment = @{$syntenySegmentRef};

  # members in synteny segment
  my $firstMember = shift @syntenySegment;
  return unless($firstMember);
  $self->print_member($firstMember, "LEFT\n");
  my $lastMember = pop @syntenySegment;
  return unless($lastMember);
  $self->print_member($lastMember, "RIGHT\n");
  return unless(@syntenySegment);

  print("  have potential synteny members to check\n");
  my $refPAF = $self->{'qmember_PAF_BRH_hash'}->{$firstMember->dbID};
  foreach my $peptideMember (@syntenySegment) {
    $self->find_RHS($refPAF, $peptideMember);
  }

  $refPAF = $self->{'qmember_PAF_BRH_hash'}->{$lastMember->dbID};
  foreach my $peptideMember (@syntenySegment) {
    $self->find_RHS($refPAF, $peptideMember);
  }
}



sub test_RHS
{
  my $self = shift;
  my $pafDBA    = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor;

  my $refPAF;
  my $t0 = [gettimeofday()];
  #$refPAF = $pafDBA->fetch_BRH_by_member_genomedb(31950,3);
  $refPAF = $pafDBA->fetch_by_dbID(604963); #BRH
  #print(tv_interval($t0) . " sec to fetch PAF\n");

  #print("BRH : "); $refPAF->display_short;
  my $memberPep  = $memberDBA->fetch_by_dbID(31957);
  my $memberGene = $memberDBA->fetch_gene_for_peptide_member_id(31957);
  $self->print_member($memberPep);
  $self->print_member($memberGene);
  
  $self->find_RHS($refPAF, $memberPep);
}


sub find_RHS
{
  my $self = shift;
  my $refPAF = shift;  #from syntenySegment
  my $memberPep = shift;

  return unless($refPAF and $memberPep);

  return unless($self->{'membersToBeProcessed'}->{$memberPep->dbID});

  if($self->{'verbose'}) {
    print("ref BRH : "); $refPAF->display_short();
    $self->print_member($refPAF->query_member, " BRH QUERY\n");
    $self->print_member($refPAF->hit_member, " BRH HIT\n");
    $self->print_member($memberPep, "potential synteny\n");
  }

  if($refPAF->query_member->chr_start < $memberPep->chr_start) { #BRH to left
    return
      if(($memberPep->chr_start - $refPAF->query_member->chr_end) > 1500000)
  }
  if($refPAF->query_member->chr_start > $memberPep->chr_start) { #BRH to right
    return
      if(($refPAF->query_member->chr_start - $memberPep->chr_end) > 1500000)
  }

  # shorthand for this query is, get all reciprocal hits syntenous with
  # reference PAF's hit (same species, same chromosoe, within 1.5Mbase)
  # and of sufficient quality (evalue<1e-50 and perc_ident>40)
  # some of the joins are not necessary (qm), but doesn't altar the speed
  # returns results sorted by same sort as used for 'best' analysis
  # Current code will take all results, but could limit to only
  # 'best' ie first result returned
  my $sql = "SELECT paf1.peptide_align_feature_id".
            " FROM member qm, member hm,".
            " peptide_align_feature paf1, peptide_align_feature paf2,".
            " member_gene_peptide".
            " WHERE paf1.hmember_id=paf2.qmember_id".
            " AND paf1.qmember_id=paf2.hmember_id".
            " AND qm.member_id=paf1.qmember_id".
            " AND hm.member_id=member_gene_peptide.gene_member_id".
            " AND member_gene_peptide.peptide_member_id=paf1.hmember_id".
            #" AND paf1.hit_rank=1".
            # AND (paf1.evalue<1e-50 AND paf1.perc_ident>40)".
            " AND paf1.evalue<1e-10".
            " AND hm.genome_db_id='". $refPAF->hit_member->genome_db_id ."'".
            " AND hm.chr_name='". $refPAF->hit_member->chr_name ."'".
            " AND hm.chr_start<'". scalar($refPAF->hit_member->chr_end+1500000) ."'".
            " AND hm.chr_end>'". scalar($refPAF->hit_member->chr_start-1500000) ."'".
            " AND paf1.qmember_id='". $memberPep->dbID ."'".
            " AND paf2.hmember_id='". $memberPep->dbID ."'".
            " ORDER BY paf1.score DESC, paf1.evalue, paf1.perc_ident DESC, paf1.perc_pos DESC";

  print("$sql\n") if($self->{'verbose'}>1);
  my $sth = $self->{'comparaDBA'}->prepare($sql);
  $sth->execute();

  my ($paf1_id);
  my @paf_id_list;
  $sth->bind_columns(\$paf1_id);
  if($self->{'getAllRHS'}) {
    while ($sth->fetch()) {
      push @paf_id_list, $paf1_id;
    }
  }
  else { #just get best (ie
    if ($sth->fetch()) {
      push @paf_id_list, $paf1_id;
    }
  }
  $sth->finish;

  #print("  CONVERT PAF => Homology objects and store\n");
  my $pafDBA      = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor();
  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor();

  #$startTime = time();
  foreach $paf1_id (@paf_id_list) {
    my $paf = $pafDBA->fetch_by_dbID($paf1_id);
    print("RHS : "); $paf->display_short;

    my $homology = $paf->return_as_homology();
    $homology->description('RHS');
    eval { $homologyDBA->store($homology) if($self->{'store'}); };

    delete $self->{'membersToBeProcessed'}->{$paf->query_member->dbID};
    delete $self->{'membersToBeProcessed'}->{$paf->hit_member->dbID};
  }
  #print(time()-$startTime . " sec to convert PAF to Homology\n");
  
}

#################################
#
# General routines
#
#################################

sub print_member
{
  my $self = shift;
  my $member = shift;
  my $postfix = shift;
  
  print("   ".$member->stable_id.
        "(".$member->dbID.")".
        "\t".$member->chr_name ." : ".
        $member->chr_start ."- ". $member->chr_end);
  my $paf = $self->{'qmember_PAF_BRH_hash'}->{$member->dbID};
  if($paf) { print(" BRH(".$paf->dbID.")" ); }
  if($postfix) { print(" $postfix"); } 
  else { print("\n"); }
}


sub calc_inter_genic_distance
{
  my $self = shift;
  my $genome_db_id = shift;

  print("calc_inter_genic_distance genome_db_id=$genome_db_id\n");
  my $genomeDB = $self->{'comparaDBA'}->get_GenomeDBAdaptor()->fetch_by_dbID($genome_db_id);
  my $desc = $genomeDB->name() . " genes";
  print("  desc = $desc\n");
  my $subset = $self->{'comparaDBA'}->get_SubsetAdaptor->fetch_by_set_description($desc);
  print("fetched subset_id ". $subset->dbID . "\n");
  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor();
  $memberDBA->_final_clause("ORDER BY m.chr_name, m.chr_start");
  my $sortedMembers = $memberDBA->fetch_by_subset_id($subset->dbID);
  print(scalar(@{$sortedMembers}) . " members to process\n");

  my $lastMember = undef;
  my $count = 0;
  my $distSum = 0;
  my $minDist = undef;
  my $maxDist = undef;
  my $dist;
  my $overlapCount = 0;
  foreach my $member (@{$sortedMembers}) {
    if($lastMember) {
      if($lastMember->chr_name ne $member->chr_name) {
        $lastMember = undef;
      }
      else {
        $count++;
        $dist = ($member->chr_start - $lastMember->chr_end);
        $distSum += $dist;

        if($dist < 0) {
          $overlapCount++;
          $self->print_member($lastMember, "lastMember");
          $self->print_member($member, "member, dist<0\n");
        }

        unless($minDist and $dist>$minDist) { $minDist=$dist; }
        unless($maxDist and $dist<$maxDist) { $maxDist=$dist; }

        $lastMember = $member;
      }
    }
    else {
      $lastMember = $member;
    }
  }

  my $averageIntergenicDistance = scalar($distSum/$count);

  print("$count intergenic intervals\n");
  print("$overlapCount overlapping genes\n");
  print("$averageIntergenicDistance average intergenic distance\n");
  print("maxDist = $maxDist\n");
  print("minDist = $minDist\n");
}


1;
