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

my $_build_homology_idx = 1; #global index counter

package Bio::EnsEMBL::Compara::RunnableDB::BuildHomology;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Pipeline::RunnableDB;

use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Subset;

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

  if($self->input_id =~ ',') {
    $self->load_blasts_from_input();
  }
  else {
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

  while(@blast_list) {
    my $blast1 = shift @blast_list;
    foreach my $blast2 (@blast_list) {
      print("   check pair ".$blast1->logic_name." <=> ".$blast2->logic_name."\n");

      $self->get_BRH_for_species_pair($blast1, $blast2);
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
  my $sth = $self->{'comparaDBA'}->prepare($sql);
  $sth->execute();

  my ($paf1_id, $paf2_id, $qmember_id, $hmember_id);
  $sth->bind_columns(\$paf1_id, \$paf2_id, \$qmember_id, \$hmember_id);

  my @paf_id_list;
  while ($sth->fetch()) {
    push @paf_id_list, $paf1_id;
  }
  $sth->finish;
  print("  found ".($#paf_id_list + 1).
        " BRH for reciprocal blasts for pair ".
        $analysis1->logic_name." and ".
        $analysis2->logic_name."\n");

  print("  CONVERT PAF => Homology objects and store\n");
  my $pafDBA      = $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor();
  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor();

  foreach $paf1_id (@paf_id_list) {
    my $paf = $pafDBA->fetch_by_dbID($paf1_id);

    my $homology = $self->PAF2Homology($paf);
    $homology->description('BRH');
    $homologyDBA->store($homology);
  }
}


sub PAF2Homology
{
  my $self = shift;
  my $paf  = shift;

  # create an Homology object
  my $homology = new Bio::EnsEMBL::Compara::Homology;
  my $stable_id = $paf->query_member->taxon_id() . "_" . $paf->hit_member->taxon_id . "_";
  $stable_id .= sprintf ("%011.0d",$_build_homology_idx++);
  $homology->stable_id($stable_id);
  $homology->source_name("ENSEMBL_HOMOLOGS");

  # NEED TO BUILD THE Attributes (ie homology_members)
  #
  # QUERY member
  #
  my $attribute;
  $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->member_id($paf->query_member->dbID); 
  $attribute->cigar_start($paf->qstart);
  $attribute->cigar_end($paf->qend);
  my $qlen = ($paf->qend - $paf->qstart + 1);
  $attribute->perc_cov(int($qlen*100/$paf->query_member->seq_length));
  $attribute->perc_id(int($paf->identical_matches*100.0/$qlen));
  $attribute->perc_pos(int($paf->positive_matches*100/$qlen));

  my $cigar_line = $paf->cigar_line;
  #print("original cigar_line '$cigar_line'\n");
  $cigar_line =~ s/I/M/g;
  $cigar_line = compact_cigar_line($cigar_line);
  $attribute->cigar_line($cigar_line);
  #print("   '$cigar_line'\n");

  $homology->add_Member_Attribute([$paf->query_member, $attribute]);

  # HIT member 
  #
  $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->member_id($paf->hit_member->dbID);
  $attribute->cigar_start($paf->hstart);
  $attribute->cigar_end($paf->hend);
  my $hlen = ($paf->hend - $paf->hstart + 1);
  $attribute->perc_cov(int($hlen*100/$paf->hit_member->seq_length));
  $attribute->perc_id(int($paf->identical_matches*100.0/$hlen));
  $attribute->perc_pos(int($paf->positive_matches*100/$hlen));

  $cigar_line = $paf->cigar_line;
  #print("original cigar_line\n    '$cigar_line'\n");
  $cigar_line =~ s/D/M/g;
  $cigar_line =~ s/I/D/g;
  $cigar_line = compact_cigar_line($cigar_line);
  $attribute->cigar_line($cigar_line);
  #print("   '$cigar_line'\n");

  $homology->add_Member_Attribute([$paf->hit_member, $attribute]);

  return $homology;
}

  
sub compact_cigar_line
{
  my $cigar_line = shift;
  
  #print("cigar_line '$cigar_line' => ");
  my @pieces = ( $cigar_line =~ /(\d*[MDI])/g );
  my @new_pieces = ();
  foreach my $piece (@pieces) {
    $piece =~ s/I/M/;
    if (! scalar @new_pieces || $piece =~ /D/) {
      push @new_pieces, $piece;
      next;
    }
    if ($piece =~ /\d*M/ && $new_pieces[-1] =~ /\d*M/) {
      my ($matches1) = ($piece =~ /(\d*)M/);
      my ($matches2) = ($new_pieces[-1] =~ /(\d*)M/);
      if (! defined $matches1 || $matches1 eq "") {
        $matches1 = 1;
      }
      if (! defined $matches2 || $matches2 eq "") {
        $matches2 = 1;
      }
      $new_pieces[-1] = $matches1 + $matches2 . "M";
    } else {
      push @new_pieces, $piece;
    }
  }
  my $new_cigar_line = join("", @new_pieces);
  #print(" '$new_cigar_line'\n");
  return $new_cigar_line;
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


1;
