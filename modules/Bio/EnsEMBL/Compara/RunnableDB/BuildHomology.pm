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
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::BuildHomology->new (
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

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BuildHomology;

use strict;
#use Statistics::Descriptive;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception qw ( throw warning ) ; 
use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

####################################
#
# Subclass methods
#
####################################


sub fetch_input
{
  my $self = shift;

  $self->{'startTime'} = time();

  # input_id is Compara_db=1 => work on whole compara database so essentially
  # has no value, so just ignore

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
                           -user => $self->db->dbc->username,
                           -pass => $self->db->dbc->password,
                           -host => $self->db->dbc->host,
                           -port => $self->db->dbc->port,
                           -dbname => $self->db->dbc->dbname,
                           -disconnect_when_inactive =>0);

  $self->{'blast_analyses'} = ();
  $self->{'store'} = 1;
  $self->{'getAllRHS'} = undef; #switch to look for synteny beyond a best (hit_rank>1)
  $self->{'doRHS'} = 1;
  $self->{'onlyOneHomology'} = undef;  #filter to place member in only 1 homology
  $self->{'comparaDBA'}->dbc->do("analyze table peptide_align_feature");  

  if($self->debug) { print("input_id = " . $self->input_id . "\n"); }
  
  if($self->input_id =~ '^{') { 
    $self->load_blasts_from_input();
  }
  elsif($self->input_id eq 'all'){
    # not in pair format, so load all blasts for processing
    $self->load_all_blasts();
  }
  if($self->debug) {
    print("blasts :\n");
    foreach my $analysis (@{$self->{'blast_analyses'}}) {
      print("   ".$analysis->logic_name."\n");
    }
  }

  #make sure method_link table is properly loaded
  $self->{'comparaDBA'}->dbc->do("insert ignore into method_link set method_link_id=201, type='ENSEMBL_ORTHOLOGUES'"); 

  return 1;
}


sub run
{
  my( $self) = @_;

  if($self->input_id eq 'test'){
    print("RUN TESTS!!!\n");
    $self->debug(1);
    $self->test_best_paf_web('ENSP00000344183',2);

    $self->test_RHS;
    $self->test_best_paf_web('ENSP00000328644',2);

    $self->test_best_paf_web('ENSP00000296755',2);
    $self->test_best_paf_web('ENSMUSP00000068374',1);
    $self->test_best_paf_web('ENSMUSP00000045740',1);
    $self->test_best_paf_web('ENSP00000341372',2);

    exit(1);
  }
  
  return 1;
}


sub write_output
{
  my $self = shift;

  my @blast_list = @{$self->{'blast_analyses'}};

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  
  while(@blast_list) {
    my $blast1 = shift @blast_list;
    foreach my $blast2 (@blast_list) {
      if($self->debug) {
        print("   check pair ".$blast1->logic_name." <=> ".$blast2->logic_name."\n");
      }

      #$self->{'qmember_PAF_BRH_hash'} = {};
      $self->{'membersToBeProcessed'} = {};
      $self->{'storedHomologies'} = {};

      $self->determine_method_link_species_set($blast1, $blast2);
      $self->delete_previous_homology_method_link_species_set();

      $self->set_member_list($blast1);
      $self->set_member_list($blast2);
      if($self->debug) {
        print(scalar(keys %{$self->{'membersToBeProcessed'}}) . " members to be processed for HOMOLOGY\n");
      }

      $self->process_species_pair($blast1, $blast2);
      $self->process_species_pair($blast2, $blast1);

    }
  }
  
  if($self->debug) {
    my $runTime = time() - $self->{'startTime'};
    my $mins = int($runTime/60);
    my $secs = $runTime % 60;
    printf("total processing time %d min %d secs\n", $mins, $secs);
  }

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

  if($self->debug) { print("set_member_list from analysis ".$analysis->logic_name()."\n"); }

  my $subset_id = eval($analysis->data)->{'subset_id'};

  my $subset = $self->{'comparaDBA'}->get_SubsetAdaptor->fetch_by_dbID($subset_id);
  foreach my $member_id (@{$subset->member_id_list}) {
    $self->{'membersToBeProcessed'}->{$member_id} = $member_id;  #like an STL set
  }
  my @mkeys = keys %{$self->{'membersToBeProcessed'}};
  if($self->debug) { print("  count ". $#mkeys . "\n"); }
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

  if($self->debug) { print("load_blasts_from_input\n"); }
  my $input_hash = eval($self->input_id);

  if($input_hash->{'noRHS'}) {
    $self->{'doRHS'}=undef;
    if($self->debug) { print("TURN OFF RHS analysis\n"); }
  }

  my $logic_names = $input_hash->{'blasts'};
  if($self->debug) {
    print("$input_hash\n");
    print("keys: ", keys(%{$input_hash}), "\n");
    print("$logic_names\n");
  }
  foreach my $logic_name (@{$logic_names}) {
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

sub determine_method_link_species_set
{
  # using trick of specifying table twice so can join to self
  my $self      = shift;
  my $analysis1 = shift;  # query species (get subset_id)
  my $analysis2 = shift;  # db species (analysis_id, ie blast)

  if($self->debug) {
    print("determine_method_link_species_set\n");
    print("  analysis1 ".$analysis1->logic_name()."\n");
    print("  analysis2 ".$analysis2->logic_name()."\n");
  }

  my $q_genome_db_id   = eval($analysis1->data)->{'genome_db_id'}; 
  my $hit_genome_db_id   = eval($analysis2->data)->{'genome_db_id'};

  #
  # create method_link_species_set
  # 

  my $qGDB = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($q_genome_db_id);
  my $hGDB = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($hit_genome_db_id);
  
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $mlss->method_link_type("ENSEMBL_ORTHOLOGUES");
  $mlss->species_set([$qGDB, $hGDB]);
  $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);
  $self->{'method_link_species_set'} = $mlss;
  return $mlss;
}



sub delete_previous_homology_method_link_species_set 
{
  my $self = shift;

  if($self->debug) {
    printf("delete_previous_homology_method_link_species_set\n");
    printf("  method_link_species_set : %d\n", $self->{'method_link_species_set'}->dbID);
  }

  my $sql = "DELETE homology, homology_member from homology, homology_member ".
	    "WHERE homology.homology_id = homology_member.homology_id ".
            "AND homology.method_link_species_set_id = " .
	    $self->{'method_link_species_set'}->dbID;
  #print("$sql\n");
  my $delcount = $self->{'comparaDBA'}->dbc->do($sql);
  if($self->debug) { print("deleted $delcount rows\n"); }
}


sub process_species_pair
{
  # using trick of specifying table twice so can join to self
  my $self      = shift;
  my $analysis1 = shift;  # query species (get subset_id)
  my $analysis2 = shift;  # db species (analysis_id, ie blast)

  if($self->debug) { 
    print("process_species_pair_by_synteny_segment\n");
    print("  analysis1 ".$analysis1->logic_name()."\n");
    print("  analysis2 ".$analysis2->logic_name()."\n");
  }


  my $subset_id        = eval($analysis1->data)->{'subset_id'}; 
  my $q_genome_db_id   = eval($analysis1->data)->{'genome_db_id'}; 
  my $hit_genome_db_id = eval($analysis2->data)->{'genome_db_id'};

  # fetch the peptide members (via subset) ordered on chromosomes
  # then convert into synenty_segments (again of peptide members)
  #
  if($self->debug) {
    print("about to fetch sorted members for".
          " genome_db_id=$q_genome_db_id".
          " subset_id=$subset_id\n");
  }
  my $startTime = time();
  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor();
  $memberDBA->_final_clause("ORDER BY m.chr_name, m.chr_start");
  my $sortedMembers = $memberDBA->fetch_by_subset_id($subset_id);
  if($self->debug) {
    print(time()-$startTime . " sec memberDBA->fetch_by_subset_id\n");
    print(scalar(@{$sortedMembers}) . " members to process for HOMOLOGY\n");
  }

  my $syntenySegment = $self->get_next_syneny_segment($sortedMembers, $hit_genome_db_id);
  while($syntenySegment) {
    # do my processing of synteny
    $self->process_synteny_segement($syntenySegment);

    #get next segment
    $syntenySegment = $self->get_next_syneny_segment($sortedMembers, $hit_genome_db_id);
  }
}


sub get_next_syneny_segment
{
  my $self              = shift;
  my $sortedMembers     = shift;  #list reference
  my $hit_genome_db_id  = shift;

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

  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  #print("Extend synteny\n");
  while($sortedMembers and @{$sortedMembers}) { 
    my $member = $sortedMembers->[0];
    #$self->print_member($member, " PEEK\n");
    if($member->chr_name ne $firstMember->chr_name) {
      #print("  END: changed chromosome\n");
      last;
    }
    push @syntenySegment, $member;

    
    my $pafsArray = $pafDBA->fetch_BRH_web_for_member_genome_db($member->dbID, $hit_genome_db_id);
    if($self->debug) { printf("  %d pafs in bestweb\n", scalar(@$pafsArray)) if($pafsArray); }

    #first test if 1-to-1 BRH
    last if($self->check_BRHweb_is_unique($member, $pafsArray));

    #next test if 1-to-manyLocals BRH
    last if($self->check_BRHweb_for_recent_duplicates($member, $pafsArray));

    $member->{'BRH_paf_array'} = $pafsArray;
    #last if($self->check_segment_BRH_synteny(\@syntenySegment));
    
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


sub check_BRHweb_is_unique
{
  my $self         = shift;
  my $query_member = shift;
  my $pafsArray    = shift;

  #testing for simple 1-to-1 BRH
  #as in only one best hit in each direction
  return 0 unless($pafsArray and $query_member);
  return 0 unless(scalar(@$pafsArray)==2);

  my $paf1 = $pafsArray->[0];
  my $paf2 = $pafsArray->[1];

  return 0 unless(($paf1->query_member->dbID == $paf2->hit_member->dbID) and
                  ($paf1->hit_member->dbID == $paf2->query_member->dbID));

  if($query_member->dbID == $paf1->query_member->dbID) {
    $query_member->{'RHpaf'} = $paf1;
  } else {
    $query_member->{'RHpaf'} = $paf2;
  }
  $self->store_paf_as_homology($query_member->{'RHpaf'}, 'UBRH');
  return 1;
}


sub check_BRHweb_for_recent_duplicates
{
  my $self         = shift;
  my $query_member = shift;
  my $pafsArray    = shift;

  #testing for 1-to-many BRH
  #as in one member BRH to several neighboring genes
  #ie on same chromosome, and near by (within 1.5mBase)
  return 0 unless($pafsArray and $query_member);
  return 0 unless(scalar(@$pafsArray)>2);

  my $refPAF = undef;
  my $multiCount = 0;
  foreach my $paf (@{$pafsArray}) {

    #don't bother with the reverse pafs ie those from other species recip
    #hitting back to genome of $query_member (all links are BRHs)
    next if($paf->query_member->genome_db_id != $query_member->genome_db_id);

    #we are testing if query_member is root of 1-to-many (ie is the ONE)
    #so all remaining pafs must be from query_member
    return 0 unless($paf->query_member->dbID == $query_member->dbID);

    $multiCount++;
    unless(defined($refPAF)) {
      $refPAF = $paf;
    } else {
      return 0 unless($refPAF->hit_member->chr_name eq $paf->hit_member->chr_name);
      return 0 unless(abs($refPAF->hit_member->chr_start - $paf->hit_member->chr_start)<1500000);
    }
  }

  if($self->debug) { print("MULTIPLE BRHs are RECENT DUPLICATION\n"); }
  my $subtype = "DUP 1.$multiCount";
  foreach my $paf (@{$pafsArray}) {
    next if($paf->query_member->genome_db_id != $query_member->genome_db_id);
    $self->store_paf_as_homology($paf, "MBRH", $subtype);
    $query_member->{'RHpaf'} = $paf;
  }
  if($self->debug) { print("\n"); }
  return 1;
}


sub tag_BRHweb_as_mess
{
  my $self         = shift;
  my $query_member = shift;
  my $pafsArray    = shift;

  #failed all tests so this is a complex BRH web
  #so save each one as a BRH_MULTI
  return 0 unless($pafsArray and $query_member);
  return 0 unless(scalar(@$pafsArray)>0);

  foreach my $paf (@{$pafsArray}) {
    next if($paf->query_member->genome_db_id != $query_member->genome_db_id);
    $self->store_paf_as_homology($paf, 'MBRH', 'complex');
  }
  return 1;
}


sub check_segment_BRH_synteny
{
  my $self = shift;
  my $syntenySegmentRef = shift;

  return 0 unless($syntenySegmentRef and @{$syntenySegmentRef});
  return 0 unless(scalar(@{$syntenySegmentRef})>=2);
  
  my $firstMember   = $syntenySegmentRef->[0];
  my $lastMember    = $syntenySegmentRef->[scalar(@{$syntenySegmentRef})-1];
  my $leftPAF       = $firstMember->{'RHpaf'};
  my $rightPAFArray = $lastMember->{'BRH_paf_array'};
  return 0 unless($leftPAF and $rightPAFArray);

  if($self->debug >1) {
    print("MULTIPLE BRH for member : ");
    $self->print_member($lastMember);
    $self->print_synteny_segement($syntenySegmentRef);
    print(" LEFT  "); $leftPAF->display_short();

    foreach my $paf (@{$rightPAFArray}) { print(" RIGHT "); $paf->display_short(); }
  }

  #first loop look for one that hits the same chromosome as the leftPAF
  #if more than one BRH falls on same chromosome
  #pick one that is nearest to the leftBRH (might need to add orientation)
  foreach my $paf (@{$rightPAFArray}) {
    next if($leftPAF->hit_member->chr_name ne $paf->hit_member->chr_name);
    if($lastMember->{'RHpaf'}) {
      next if(abs($leftPAF->hit_member->chr_start - $paf->hit_member->chr_start) >
              abs($leftPAF->hit_member->chr_start - $lastMember->{'RHpaf'}->hit_member->chr_start));
    }
    $lastMember->{'RHpaf'} = $paf;    
  }

  if($lastMember->{'RHpaf'}) {
    #print("PICK: "); $lastMember->{'RHpaf'}->display_short();
    $self->store_paf_as_homology($lastMember->{'RHpaf'}, 'MBRH', 'SYN');
    #print("\n");
    return 1;
  }
  return 0;
}


sub process_synteny_segement
{
  my $self = shift;
  my $syntenySegmentRef = shift;

  return unless($syntenySegmentRef and @{$syntenySegmentRef});
  if($self->debug >2) {
    print("process_synteny_segement\n");
    $self->print_synteny_segement($syntenySegmentRef);
  }

  my @syntenySegment = @{$syntenySegmentRef};

  # members in synteny segment
  my $firstMember = shift @syntenySegment;
  return unless($firstMember);
  #$self->print_member($firstMember, "LEFT\n");
  my $lastMember = pop @syntenySegment;
  return unless($lastMember);
  #$self->print_member($lastMember, "RIGHT\n");
  return unless(scalar(@syntenySegment)>0);

  #my $refPAF = $self->{'qmember_PAF_BRH_hash'}->{$firstMember->dbID};
  my $refPAF = $firstMember->{'RHpaf'};
  foreach my $peptideMember (@syntenySegment) {
    $self->find_RHS($refPAF, $peptideMember);
  }
  $firstMember->{'RHpaf'} = undef;  #break possible cyclical relation, memory leak

  #$refPAF = $self->{'qmember_PAF_BRH_hash'}->{$lastMember->dbID};
  $refPAF = $lastMember->{'RHpaf'};
  foreach my $peptideMember (@syntenySegment) {
    $self->find_RHS($refPAF, $peptideMember);
  }

  #all clean cases exhausted so save remaining BRHs with tag 'BRH_MULTI'
  #but continue growing segement
  foreach my $peptideMember (@syntenySegment) {
    $self->tag_BRHweb_as_mess($peptideMember, $peptideMember->{'BRH_paf_array'});
  }
}



sub test_RHS
{
  my $self = shift;
  my $pafDBA    = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor;

  print("TEST RHS ANALYSIS\n");
  my $refPAF;
  my $t0 = [gettimeofday()];
  my $qmember = $memberDBA->fetch_by_source_stable_id('ENSEMBLPEP', 'ENSP00000314549');
  $qmember->print_member();
  printf(" seq_length=%d  seq=%s\n", $qmember->seq_length, $qmember->sequence);
  ($refPAF) = @{$pafDBA->fetch_BRH_by_member_genomedb($qmember->dbID,2)}; #against mouse
  #print(tv_interval($t0) . " sec to fetch PAF\n");
  print("refBRH : "); $refPAF->display_short;

  my $memberPep  = $memberDBA->fetch_by_source_stable_id('ENSEMBLPEP', 'ENSP00000345290');
  my $memberGene = $memberDBA->fetch_gene_for_peptide_member_id($memberPep->dbID);
  print("query pep  : "); $self->print_member($memberPep);
  print("query gene : "); $self->print_member($memberGene);
  
  $self->find_RHS($refPAF, $memberPep);
  #print("orig_find_RHS\n");
  #$self->orig_find_RHS($refPAF, $memberPep);
  print("\n\n");
}


sub find_RHS
{
  my $self = shift;
  my $refPAF = shift;  #from syntenySegment
  my $memberPep = shift;

  return unless($refPAF and $memberPep);
  return unless($self->{'doRHS'});
  return if($memberPep->{'RHpaf'});

  return if($self->{'onlyOneHomology'} and
            !defined($self->{'membersToBeProcessed'}->{$memberPep->dbID}));

  if($self->debug>3) {
    print("ref BRH : "); $refPAF->display_short();
    $self->print_member($refPAF->query_member, " BRH QUERY\n");
    $self->print_member($refPAF->hit_member, " BRH HIT\n");
  }
  if($self->debug>2) {
    $self->print_member($memberPep, "test for RHS synteny\n");
  }

  if($refPAF->query_member->chr_start < $memberPep->chr_start) { #BRH to left
    return if(($memberPep->chr_start - $refPAF->query_member->chr_end) > 1500000)
  }
  if($refPAF->query_member->chr_start > $memberPep->chr_start) { #BRH to right
    return if(($refPAF->query_member->chr_start - $memberPep->chr_end) > 1500000)
  }

  my $pafDBA    = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;
  my $pafsArray = $pafDBA->fetch_all_RH_by_member_genomedb($memberPep->dbID, $refPAF->hit_member->genome_db_id);
  foreach my $paf (@$pafsArray) {
    #print("  test : "); $paf->display_short();
    next if($self->{'onlyOneHomology'} and
            !defined($self->{'membersToBeProcessed'}->{$paf->hit_member->dbID}));
    # next unless ($paf->hit_rank==1);
    # next unless ($paf->evalue<1e-50 and $paf->perc_ident>40);
    next unless($paf->evalue < 1e-10);
    next unless($paf->hit_member->chr_name eq $refPAF->hit_member->chr_name);
    next unless($paf->hit_member->chr_start < ($refPAF->hit_member->chr_end+1500000));
    next unless($paf->hit_member->chr_end   > ($refPAF->hit_member->chr_start-1500000));
    next if($self->{'getAllRHS'} and !($paf->evalue<1e-50 and $paf->perc_ident>40));
    
    my $recip_paf = $pafDBA->fetch_by_dbID($paf->rhit_dbID);
    #print("  recip_paf : "); $recip_paf->display_short();

    if($self->{'getAllRHS'} or $paf->hit_rank==1 or $recip_paf->hit_rank==1) {
      my $type = 'RHS';
      unless($paf->hit_rank==1 or $recip_paf->hit_rank==1) {
        my $rank = $paf->hit_rank;
        $rank = $recip_paf->hit_rank if($rank < $recip_paf->hit_rank);
        $type .= $rank;
      }
      if($paf->hit_rank==1 and $recip_paf->hit_rank==1) {
        $self->store_paf_as_homology($paf, "MBRH", "SYN");
      } else {
        $self->store_paf_as_homology($paf, $type);
      }
    }
  }
}


sub orig_find_RHS
{
  my $self = shift;
  my $refPAF = shift;  #from syntenySegment
  my $memberPep = shift;

  return unless($refPAF and $memberPep);
  return unless($self->{'doRHS'});
  return if($memberPep->{'RHpaf'});

  return if($self->{'onlyOneHomology'} and
            !defined($self->{'membersToBeProcessed'}->{$memberPep->dbID}));

  if($self->debug>3) {
    print("ref BRH : "); $refPAF->display_short();
    $self->print_member($refPAF->query_member, " BRH QUERY\n");
    $self->print_member($refPAF->hit_member, " BRH HIT\n");
  }
  if($self->debug>2) {
    $self->print_member($memberPep, "test for RHS synteny\n");
  }

  if($refPAF->query_member->chr_start < $memberPep->chr_start) { #BRH to left
    return if(($memberPep->chr_start - $refPAF->query_member->chr_end) > 1500000)
  }
  if($refPAF->query_member->chr_start > $memberPep->chr_start) { #BRH to right
    return if(($refPAF->query_member->chr_start - $memberPep->chr_end) > 1500000)
  }

  # shorthand for this query is, get all reciprocal hits syntenous with
  # reference PAF's hit (same species, same chromosoe, within 1.5Mbase)
  # and of sufficient quality (evalue<1e-50 and perc_ident>40)
  # some of the joins are not necessary (qm), but doesn't altar the speed
  # returns results sorted by same sort as used for 'best' analysis
  # Current code will take all results, but could limit to only
  # 'best' ie first result returned
  my $sql = "SELECT paf1.peptide_align_feature_id, paf1.hmember_id, paf1.hit_rank".
            " FROM member hm,".
            " peptide_align_feature paf1, peptide_align_feature paf2,".
            " member_gene_peptide".
            " WHERE paf1.hmember_id=paf2.qmember_id".
            " AND paf1.qmember_id=paf2.hmember_id".
            " AND hm.member_id=member_gene_peptide.gene_member_id".
            " AND member_gene_peptide.peptide_member_id=paf1.hmember_id".
            #" AND paf1.hit_rank=1".
            # AND (paf1.evalue<1e-50 AND paf1.perc_ident>40)".
            " AND paf1.evalue<1e-10".
            " AND paf1.qmember_id='". $memberPep->dbID ."'".
            " AND paf2.hmember_id='". $memberPep->dbID ."'".
            " AND paf1.hgenome_db_id='". $refPAF->hit_member->genome_db_id ."'".
            " AND paf2.qgenome_db_id='". $refPAF->hit_member->genome_db_id ."'".
            " AND hm.genome_db_id='". $refPAF->hit_member->genome_db_id ."'".
            " AND hm.chr_name='". $refPAF->hit_member->chr_name ."'".
            " AND hm.chr_start<'". scalar($refPAF->hit_member->chr_end+1500000) ."'".
            " AND hm.chr_end>'". scalar($refPAF->hit_member->chr_start-1500000) ."'".
            " ORDER BY paf1.score DESC, paf1.evalue, paf1.perc_ident DESC, paf1.perc_pos DESC";

  if($self->debug>3) { print("$sql\n"); } 
  my $sth = $self->{'comparaDBA'}->prepare($sql);
  $sth->execute();

  my ($paf1_id, $hmember_id, $hit_rank);
  my @paf_id_list;
  $sth->bind_columns(\$paf1_id, \$hmember_id, \$hit_rank);
  while ($sth->fetch()) {
    next if($self->{'onlyOneHomology'} and !defined($self->{'membersToBeProcessed'}->{$hmember_id}));
    push @paf_id_list, $paf1_id;
    last unless($self->{'getAllRHS'}); #just get best (since sorted in query)
  }
  $sth->finish;

  #print("  CONVERT PAF => Homology objects and store\n");
  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor();
  #$startTime = time();
  foreach $paf1_id (@paf_id_list) {
    my $paf = $pafDBA->fetch_by_dbID($paf1_id);
    $self->store_paf_as_homology($paf, 'RHS');
  }
  #print(time()-$startTime . " sec to convert PAF to Homology\n");

}


sub store_paf_as_homology
{
  my $self = shift;
  my $paf  = shift;
  my $type = shift;
  my $subtype = shift;
  $subtype = '' unless($subtype);

  if($self->debug) { print("$type $subtype : "); $paf->display_short; }

  # load the genes for this PAF
  # member_gene values must be properly set before $paf->create_homology
  # and $paf->hash_key can return valid results
  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor;
  my $queryGene = $memberDBA->fetch_gene_for_peptide_member_id($paf->query_member->dbID);
  $paf->query_member->gene_member($queryGene);
  my $hitGene = $memberDBA->fetch_gene_for_peptide_member_id($paf->hit_member->dbID);
  $paf->hit_member->gene_member($hitGene);

  my $homology = $paf->create_homology();
  $homology->description($type);
  $homology->subtype($subtype);
  $homology->method_link_species_set($self->{'method_link_species_set'});
  
  my $key = $paf->hash_key;
  my $hashtype=$self->{'storedHomologies'}->{$key};
  if($hashtype) {
    warn($paf->hash_key." homology already stored as $hashtype not $type $subtype\n") if($self->debug>1);
  } else {
    $self->{'comparaDBA'}->get_HomologyAdaptor()->store($homology) if($self->{'store'});
    $self->{'storedHomologies'}->{$key} = $type." ".$subtype;
  }

  delete $self->{'membersToBeProcessed'}->{$paf->query_member->dbID};
  delete $self->{'membersToBeProcessed'}->{$paf->hit_member->dbID};  
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
  #my $paf = $self->{'qmember_PAF_BRH_hash'}->{$member->dbID};
  my $paf = $member->{'RHpaf'};
  if($paf) { print(" BRH(".$paf->dbID.")" ); }
  if($postfix) { print(" $postfix"); } 
  else { print("\n"); }
}

sub parse_as_hash{
  my $hash_string = shift;

  my %hash;

  return \%hash unless($hash_string);

  my @pairs = split (/,/, $hash_string);
  foreach my $pair (@pairs) {
    my ($key, $value) = split (/=>/, $pair);
    if ($key && $value) {
      $key   =~ s/^\s+//g;
      $key   =~ s/\s+$//g;
      $value =~ s/^\s+//g;
      $value =~ s/\s+$//g;

      $hash{$key} = $value;
    } else {
      $hash{$key} = "__NONE__";
    }
  }
  return \%hash;
}



sub test_best_paf_web
{
  my $self               = shift;
  my $qmember_id         = shift;
  my $hit_genome_db_id   = shift;

  return unless($qmember_id);
  my $qmember = $self->{'comparaDBA'}->get_MemberAdaptor
                     ->fetch_by_source_stable_id('ENSEMBLPEP', $qmember_id);
  $qmember = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_dbID($qmember_id) unless($qmember);
  return unless($qmember);                   

  printf("test_best_paf_web member %s(%d) to genome $hit_genome_db_id\n",
         $qmember->stable_id, $qmember->dbID);

  
  my $pafDBA = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor;

  my $pafsArray = $pafDBA->fetch_BRH_web_for_member_genome_db($qmember->dbID, $hit_genome_db_id);
  foreach my $paf (@{$pafsArray}) {
    print("   "); $paf->display_short;
  }  
  return if($self->check_BRHweb_is_unique($qmember, $pafsArray));
  return if($self->check_BRHweb_for_recent_duplicates($qmember, $pafsArray));
}



1;
