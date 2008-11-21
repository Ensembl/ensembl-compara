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
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This RunnableDB takes a genome_db as input and creates a blast database in a shared directory
and creates a corresponding blast_<genome> analysis off of the blast_template analysis.
The new genome specific analysis is given a logic name like blast_1_NCBI35.

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

package Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Analysis::Tools::BlastDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


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
  print("input_id = ".$self->input_id."\n");
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /{/);
  my $input_hash = eval($self->input_id);
  
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  my $genome_db_id = $input_hash->{'gdb'};
  my $subset_id    = $input_hash->{'ss'};
  $self->{'logic_name'} = undef;

  if(defined($genome_db_id)) {
    print("gdb = $genome_db_id\n");

    #get the Compara::GenomeDB object for the genome_db_id
    $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);

    $self->{'logic_name'} = "blast_" . $self->{'genome_db'}->dbID(). "_". $self->{'genome_db'}->assembly();

    unless($subset_id) {
      # get the subset of 'longest transcripts' for this genome_db_id
      $subset_id = $self->getSubsetIdForGenomeDBId($genome_db_id);
    }
  }
  
  throw("no subset defined, can't figure out which peptides to use\n") 
    unless(defined($subset_id));
  
  $self->{'pepSubset'} = $self->{'comparaDBA'}->get_SubsetAdaptor()->fetch_by_dbID($subset_id); 
  
  unless($self->{'logic_name'}) {
    $self->{'logic_name'} = "blast_" . $self->{'pepSubset'}->description;
    $self->{'logic_name'} =~ s/\s+/_/g;
  }  
  
  return 1;
}


sub run
{
  my $self = shift;
  return 1;
}


sub write_output
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

  # fasta_dir in parameter_hash
  my %parameters = $self->parameter_hash($self->analysis->parameters());
  printf("fasta_dir = %s\n", $parameters{'fasta_dir'});

  # create logical path name for fastafile
  my $fastafile = $parameters{'fasta_dir'} . "/";
  if($self->{'genome_db'}) {
    $fastafile .= $self->{'genome_db'}->name() . "_" . 
                  $self->{'genome_db'}->assembly() . ".fasta";
  } else {
    $fastafile .= $self->{'logic_name'} . ".fasta";
  }
  $fastafile =~ s/\s+/_/g;    # replace whitespace with '_' characters
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  print("fastafile = '$fastafile'\n");

  # write fasta file
  $self->{'comparaDBA'}->get_SubsetAdaptor->dumpFastaForSubset($self->{'pepSubset'}, $fastafile);

  # configure the fasta file for use as a blast database file
  my $blastdb        = new Bio::EnsEMBL::Analysis::Tools::BlastDB (
      -sequence_file => $fastafile,
      -mol_type => "PROTEIN");
  $blastdb->create_blastdb;

  my $seq_name = $blastdb->sequence_file;
  my ($dbname) = $seq_name =~ /([^\/]+)$/;
  print("registered ". $dbname . " for ".$blastdb->sequence_file . "\n");

  return $blastdb;
}


sub updateBlastAnalysis
{
  my $self    = shift;
  my $blastdb = shift;

  
  my $logic_name = $self->{'logic_name'};
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

  my %fasta_dump_parameters = $self->parameter_hash($self->analysis->parameters());

  my $params = "{subset_id=>" . $self->{'pepSubset'}->dbID;
  $params .= ",genome_db_id=>" . $self->{'genome_db'}->dbID if($self->{'genome_db'});

  if($blast_template->parameters()) {
    my $parmhash = eval($blast_template->parameters);
    if (defined $parmhash->{'blast_template_analysis_data_id'}) {
      my $blast_template_analysis_data_id = $parmhash->{'blast_template_analysis_data_id'};
      my $ada = $self->db->get_AnalysisDataAdaptor;
      my $new_params = eval($ada->fetch_by_dbID($blast_template_analysis_data_id));
      if (defined $new_params) {
        $parmhash = $new_params;
      }
    }
    if($parmhash->{'null_cigar'}) {
      $params .= ",null_cigar=>'" . $parmhash->{'null_cigar'} . "'";
    }
    if($parmhash->{'reuse_db'}) {
      $params .= ",reuse_db=>'" . $parmhash->{'reuse_db'} . "'";
    }
    if($parmhash->{'reuse_gdb'}) {
      $params .= ",reuse_gdb=>" . "[". join(",",@{$parmhash->{'reuse_gdb'}}). "]";
    }
    if($parmhash->{'options'}) {
      $params .= ",options=>'" . $parmhash->{'options'} . "'";
    }
  }
  $params .= '}';
  
  print("createBlastAnalysis\n  params = $params\n");
  my $seq_name = $blastdb->sequence_file;
  my ($dbname) = $seq_name =~ /([^\/]+)$/;

  my $analysis = Bio::EnsEMBL::Analysis->new(
      -db              => $dbname,
      -db_file         => $blastdb->sequence_file,
      -db_version      => '1',
      -logic_name      => $self->{'logic_name'},
      -program         => $blast_template->program(),
      -program_file    => $blast_template->program_file(),
      -program_version => $blast_template->program_version(),
      -module          => $blast_template->module(),
      -parameters      => $params,
    );

  my $blast_analysis_data_id = 
    $self->db->get_AnalysisDataAdaptor->store_if_needed($params);
  if (defined $blast_analysis_data_id) {
    my $parameters = "{'analysis_data_id'=>'$blast_analysis_data_id'}";
    $analysis->parameters($parameters);
  }

  $self->db->get_AnalysisAdaptor()->store($analysis);
  $self->db->get_AnalysisAdaptor()->update($analysis);

  my $stats = $self->db->get_AnalysisStatsAdaptor->fetch_by_analysis_id($analysis->dbID);
  $stats->batch_size(40);
  my $hive_capacity = $fasta_dump_parameters{'blast_hive_capacity'};
  $hive_capacity = 450 unless defined $hive_capacity; #Set it to the default 450 unless something was given
  $stats->hive_capacity($hive_capacity);
  $stats->update();
  
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
