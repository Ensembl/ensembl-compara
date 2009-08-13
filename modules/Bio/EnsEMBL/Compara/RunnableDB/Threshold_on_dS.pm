#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Threshold_on_dS

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('Threshold_on_dS');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::Threshold_on_dS(
                         -input_id   => [[1,2,3,14],[4,13],[11,16]]
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, calculates the median dS for each paired species
where dS values are available, and stores 2*median in the threshold_on_ds column
in the homology table.

=cut

=head1 CONTACT

abel@ebi.ac.uk, jessica@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Threshold_on_dS;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
use Statistics::Descriptive;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'species_sets_aref'} = undef;
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->input_id);
  return 1;
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  if (defined $params->{'species_sets'}) {
    $self->{'species_sets_aref'} = $params->{'species_sets'};
  }

  if (!defined $params->{'method_link_types'}){
    # Default will be orthologues
    $params->{method_link_types} = ['ENSEMBL_ORTHOLOGUES'];
    $self->{'method_link_types'} = [@{$params->{'method_link_types'}}];
  }
  elsif (defined $params->{'method_link_type'}) {
    warn( 'The method_link_type paramerter is deprecated. '.
          'Please use method_link_types with an arrayref value instead' );
    $self->{'method_link_types'} = [$params->{'method_link_type'}];
  }
  else {
  	$self->{'method_link_types'} = [@{$params->{'method_link_types'}}];
  }

  return;
}

sub run
{
  my $self = shift;
  return 1 unless($self->{'species_sets_aref'});

  $self->calc_threshold_on_dS($self->{'species_sets_aref'});
  
  return 1;
}

sub write_output {
  my $self = shift;
  return 1;
}

##########################################
#
# internal methods
#
##########################################

sub calc_threshold_on_dS {
  my $self = shift;
  my $species_sets_aref = shift;

  my $aa = $self->db->get_AnalysisAdaptor;
  my $Threshold_on_dS_analysis = $aa->fetch_by_logic_name('Threshold_on_dS');

  my $compara_dbc = $self->{'comparaDBA'}->dbc;

  my $sql = "select ds from homology where method_link_species_set_id = ? and ds is not NULL";
  my $sth = $compara_dbc->prepare($sql);

  $sql = "update homology set threshold_on_ds = ? where method_link_species_set_id = ?";
  my $sth2 = $compara_dbc->prepare($sql);

  my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  foreach my $species_set (@{$species_sets_aref}) {
    while (my $genome_db_id1 = shift @{$species_set}) {
      foreach my $genome_db_id2 (@{$species_set}) {
        foreach my $method_link_type(@{$self->{'method_link_types'}}){

          my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids
              ($method_link_type,[$genome_db_id1,$genome_db_id2]);
          $sth->execute($mlss->dbID);

          my $stats = new Statistics::Descriptive::Full;
          my $dS;
          $sth->bind_columns(\$dS);
          my $count = 0;
          while ($sth->fetch) {
            $stats->add_data($dS);
            $count++;
          }
          if ($count) {
            my $median = $stats->median;
            print STDERR "method_link_species_set_id: ",$mlss->dbID,"; median: ",$median,"; 2\*median: ",2*$median;

            if($median >1.0) {
              print STDERR "  threshold exceeds 2.0 - to distant -> set to 2\n";
              $median = 1.0;
            }
            if($median <1.0) {
              print STDERR "  threshold below 1.0 -> set to 1\n";
              $median = 0.5;
            }
            $sth2->execute(2*$median, $mlss->dbID);
            print STDERR " stored\n";
          }
        }
      }
    }
  }

  $sth->finish;
}

1;
