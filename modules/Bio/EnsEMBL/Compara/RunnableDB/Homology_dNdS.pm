#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Homology_dNdS

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::Homology_dNdS->new ( 
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

package Bio::EnsEMBL::Compara::RunnableDB::Homology_dNdS;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::Blast;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;

use Bio::Tools::Run::Phylo::PAML::Codeml;


use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  my $homology_id = $self->input_id;
  $self->{'homology'}= $self->{'comparaDBA'}->get_HomologyAdaptor->fetch_by_dbID($homology_id);
  return 1 if($self->{'homology'});
  return 0;
}


sub run
{
  my $self = shift;
  $self->calc_genetic_distance($self->{'homology'});
  return 1;
}


sub write_output {
  my $self = shift;
  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor;
  $homologyDBA->update_genetic_distance($self->{'homology'});
  return 1;
}


##########################################
#
# internal methods
#
##########################################

sub calc_genetic_distance
{
  my $self = shift;
  my $homology = shift;

  print("use codeml to get genetic distance of homology\n");
  $homology->print_homology;
  
  my $aln = $homology->get_SimpleAlign("cdna");
  
  my $codeml = new Bio::Tools::Run::Phylo::PAML::Codeml();
  $codeml->alignment($aln);
  my ($rc,$parser) = $codeml->run();
  my $result = $parser->next_result;
  my $MLmatrix = $result->get_MLmatrix();

  print "n = ", $MLmatrix->[0]->[1]->{'N'},"\n";
  print "s = ", $MLmatrix->[0]->[1]->{'S'},"\n";
  print "t = ", $MLmatrix->[0]->[1]->{'t'},"\n";
  print "lnL = ", $MLmatrix->[0]->[1]->{'lnL'},"\n";
  print "Ka = ", $MLmatrix->[0]->[1]->{'dN'},"\n";
  print "Ks = ", $MLmatrix->[0]->[1]->{'dS'},"\n";
  print "Ka/Ks = ", $MLmatrix->[0]->[1]->{'omega'},"\n";

  $homology->n($MLmatrix->[0]->[1]->{'N'});
  $homology->s($MLmatrix->[0]->[1]->{'S'});
  $homology->dn($MLmatrix->[0]->[1]->{'dN'});
  $homology->ds($MLmatrix->[0]->[1]->{'dS'});
  $homology->lnl($MLmatrix->[0]->[1]->{'lnL'});

  return $homology;
}

1;
