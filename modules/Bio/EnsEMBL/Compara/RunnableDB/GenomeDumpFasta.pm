#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::GenomeDumpFasta->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Pipeline::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Pipeline::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::SimpleRuleAdaptor;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my $self = shift;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db);

  #get the Compara::GenomeDB object for the genome_db_id
  my $genome_db_id = $self->input_id();
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);

  # get the subset of 'longest transcripts' for this genome_db_id   
  my $ssid = $self->getSubsetIdForGenomeDBId($genome_db_id);
  $self->{'pepSubset'} = $self->{'comparaDBA'}->get_SubsetAdaptor()->fetch_by_dbID($ssid); 
  
  return 1;
}


sub run
{
  my $self = shift;

  # dump longest peptide subset for this genome_db_id to a fasta file
  # and configure it to be used as a blast database
  my $blastdb = $self->dumpPeptidesToFasta();

  # update the blast analysis setting the blast database
  #my $blast_analysis = $self->updateBlastAnalysis($blastdb);
  my $blast_analysis = $self->createBlastAnalysis($blastdb);
  
  return 1;
}

sub write_output
{
  #need to subclass otherwise it defaults to a version that fails
  #just return 1 so success
  return 1;
}



##################################
#
# subroutines
#
##################################

sub getSubsetIdForGenomeDBId {
  my $self         = shift;
  my $genome_db_id = shift;

  my @subsetIds = ();
  my $subset_id;

  my $sql = "SELECT distinct subset.subset_id " .
            "FROM member, subset, subset_member " .
            "WHERE subset.subset_id=subset_member.subset_id ".
            "AND subset.description like '%longest%' ".
            "AND member.member_id=subset_member.member_id ".
            "AND member.genome_db_id=$genome_db_id;";
  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();

  $sth->bind_columns( undef, \$subset_id );
  while( $sth->fetch() ) {
    print("found subset_id = $subset_id for genome_db_id = $genome_db_id\n");
    push @subsetIds, $subset_id;
  }
  $sth->finish();

  if($#subsetIds > 0) {
    warn ("Compara DB: more than 1 subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }
  if($#subsetIds < 0) {
    warn ("Compara DB: no subset of longest peptides defined for genome_db_id = $genome_db_id\n");
  }

  return $subsetIds[0];
}

# using the genome_db and longest peptides subset, create a fasta
# file which can be used as a blast database
sub dumpPeptidesToFasta
{
  my $self = shift;

  # create logical path name for fastafile
  my $species = $self->{'genome_db'}->name();
  $species =~ s/\s+/_/g;  # replace whitespace with '_' characters

  # fasta_dir in parameter_hash
  my %parameters = $self->parameter_hash($self->analysis->parameters());
  print("fasta_dir = " . $parameters{'fasta_dir'});

  my $fastafile = $parameters{'fasta_dir'} . "/" .
                  $species . "_" .
                  $self->{'genome_db'}->assembly() . ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  print("fastafile = '$fastafile'\n");

  # write fasta file
  $self->{'comparaDBA'}->get_SubsetAdaptor->dumpFastaForSubset($self->{'pepSubset'}, $fastafile);

  # configure the fasta file for use as a blast database file
  my $blastdb     = new Bio::EnsEMBL::Pipeline::Runnable::BlastDB (
      -dbfile     => $fastafile,
      -type       => 'PROTEIN');
  $blastdb->run;
  print("registered ". $blastdb->dbname . " for ".$blastdb->dbfile . "\n");

  return $blastdb;
}


sub updateBlastAnalysis
{
  my $self    = shift;
  my $blastdb = shift;

  
  my $logic_name = "blast_" . $self->{'genome_db'}->dbID(). "_". $self->{'genome_db'}->assembly();
  print("UPDATE the blastDB for analysis $logic_name\n");
  my $blast_analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);

  $self->throw("$logic_name analysis has not been created") unless($blast_analysis);

  $blast_analysis->db($blastdb->dbname);
  $blast_analysis->db_file($blastdb->dbfile);
  $blast_analysis->db_version(1);
  
  $self->db->get_AnalysisAdaptor()->update($blast_analysis);

  return $blast_analysis;
}


# create an analysis of type MemberPep for this fasta/blastdb
# that will run module BlastComparaPep
sub createBlastAnalysis
{
  my $self    = shift;
  my $blastdb = shift;

  my $blast_template = $self->db->get_AnalysisAdaptor->fetch_by_logic_name('blast_template');

  my $logic_name = "blast_" . $self->{'genome_db'}->dbID(). "_". $self->{'genome_db'}->assembly();

  my $params = "subset_id=>" . $self->{'pepSubset'}->dbID . "," .
               "genome_db_id=>" . $self->{'genome_db'}->dbID;
  if($blast_template->parameters()) {
    $params .= "," . $blast_template->parameters();
  }

  my $analysis = Bio::EnsEMBL::Pipeline::Analysis->new(
      -db              => $blastdb->dbname,
      -db_file         => $blastdb->dbfile,
      -db_version      => '1',
      -logic_name      => $logic_name,
      -input_id_type   => 'MemberPep',
      -program         => $blast_template->program(),
      -program_file    => $blast_template->program_file(),
      -program_version => $blast_template->program_version(),
      -module          => $blast_template->module(),
      -parameters      => $params,
    );

  $self->db->get_AnalysisAdaptor()->store($analysis);

  return $analysis;
}


sub parameter_hash{
  my $self = shift;
  my $parameter_string = shift;

  my %parameters;

  if ($parameter_string) {

    my @pairs = split (/,/, $parameter_string);
    foreach my $pair (@pairs) {
      my ($key, $value) = split (/=>/, $pair);
      if ($key && $value) {
        $key   =~ s/^\s+//g;
        $key   =~ s/\s+$//g;
        $value =~ s/^\s+//g;
        $value =~ s/\s+$//g;

        $parameters{$key} = $value;
      } else {
        $parameters{$key} = "__NONE__";
      }
    }
  }
  return %parameters;
}
1;
