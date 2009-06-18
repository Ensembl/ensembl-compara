#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SetInternalIds

=head1 SYNOPSIS


=head1 DESCRIPTION

This module makes the internal ids unique by setting auto_increment to start at method_link_species_set_id * 10**10. This will do this on the following tables: genomic_align_block, genomic_align, genomic_align_group, genomic_align_tree

=head1 PARAMETERS

=head1 CONTACT

Post questions to the Ensembl development list: ensembl-dev@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SetInternalIds;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

   $self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);

  #read from analysis table
  $self->get_params($self->parameters); 

  #read from analysis_job table
  $self->get_params($self->input_id);
  
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Run gerp
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;
    $self->setInternalIds();
    

}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Write results to the database
    Returns :   1
    Args    :   none

=cut

sub write_output {
    my ($self) = @_;

    return 1;
}

#Makes the internal ids unique
sub setInternalIds {
    my $self = shift;
    
    my $dba = $self->{'comparaDBA'};
    my $mlss_id;

    if (defined $self->method_link_species_set_id) {
	$mlss_id = $self->method_link_species_set_id;
    } elsif (defined($self->method_link_type) && defined($self->genome_db_ids)) {
	my $mlssa = $dba->get_MethodLinkSpeciesSetAdaptor;
	my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($self->method_link_type, eval($self->genome_db_ids));
	if (!defined $mlss) {
	    print "Unable to find method_link_species_set object of " . $self->method_link_type . " for genome_dbs " . $self->genome_db_ids . ". Unable to set internal ids.\n";
	    return;
	}

	$mlss_id = $mlss->dbID;
    } else {
	throw ("Must define either method_link_species_set_id or method_link_type and genome_db_ids");
    }

    #Set AUTO_INCREMENT to start at the {mlss_id} * 10**10 + 1
    my $index = ($mlss_id * 10**10) + 1;
    my $sql_gab = "ALTER TABLE genomic_align_block AUTO_INCREMENT=$index";
    my $sql_ga = "ALTER TABLE genomic_align AUTO_INCREMENT=$index";
    my $sql_gag = "ALTER TABLE genomic_align_group AUTO_INCREMENT=$index";
    my $sql_gat = "ALTER TABLE genomic_align_tree AUTO_INCREMENT=$index";
    
    foreach my $sql ($sql_gab,$sql_ga,$sql_gag,$sql_gat) {
	my $sth = $dba->dbc->prepare($sql);
	$sth->execute();
	$sth->finish;
    }
}


##########################################
#
# getter/setter methods
# 
##########################################

sub method_link_species_set_id {
  my $self = shift;
  $self->{'_method_link_species_set_id'} = shift if(@_);
  return $self->{'_method_link_species_set_id'};
}

sub method_link_type {
  my $self = shift;
  $self->{'_method_link_type'} = shift if(@_);
  return $self->{'_method_link_type'};
}

sub genome_db_ids {
  my $self = shift;
  $self->{'_genome_db_ids'} = shift if(@_);
  return $self->{'_genome_db_ids'};
}


##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'method_link_species_set_id'})) {
    $self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  if(defined($params->{'method_link_type'})) {
    $self->method_link_type($params->{'method_link_type'});
  }
  if(defined($params->{'genome_db_ids'})) {
    $self->genome_db_ids($params->{'genome_db_ids'});
  }
  return 1;
}
