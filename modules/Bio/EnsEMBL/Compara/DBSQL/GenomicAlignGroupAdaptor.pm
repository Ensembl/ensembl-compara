#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor
#
# Copyright Javier Herrero
#
# You may distribute this module under the same terms as perl itself
# 
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor - Object to access data in genomic_align_group table

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor; 
  my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (
      -host => $host,
      -user => $dbuser,
      -pass => $dbpass,
      -port => $port,
      -dbname => $dbname,
      -conf_file => $conf_file);
  
  my $genomic_align_group_adaptor = $db->get_GenomicAlignGroupAdaptor();

  $genomic_align_group_adaptor->store($genomic_align_group);

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;


@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor Bio::EnsEMBL::Compara::DBSQL::DBAdaptor);

my $DEFAULT_MAX_ALIGNMENT = 20000;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  my $vals =
    $self->db->get_MetaContainer->list_value_by_key('max_alignment_length');

  if(@$vals) {
    $self->{'max_alignment_length'} = $vals->[0];
  } else {
    $self->warn("Meta table key 'max_alignment_length' not defined\n" .
        "using default value [$DEFAULT_MAX_ALIGNMENT]");
    $self->{'max_alignment_length'} = $DEFAULT_MAX_ALIGNMENT;
  }

  return $self;
}


=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignGroup
               The things you want to store
  Example    : $gen_ali_grp_adaptor->store($genomic_align_group);
  Description: It stores the given GenomicAlginGroup in the database
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignGroup object
  Exceptions : not stored linked Bio::EnsEMBL::Compara::GenomicAlign objects throw.
  Caller     : general

=cut

sub store {
  my ($self, $genomic_align_group) = @_;

  my $genomic_align_block_sql =
        qq{INSERT INTO genomic_align_group (
                group_id,
                type,
                genomic_align_id
        ) VALUES (?,?,?)};
  
  my @values;
  
  ## CHECKING
  foreach my $genomic_align (@{$genomic_align_group->genomic_align_array}) {
    # check if every GenomicAlgin has a dbID
    if (!defined($genomic_align->dbID)) {
      $self->throw("GenomicAlign in GenomicAlignGroup is not in DB");
    }
  }
  
  ## Stores data, all of them with the same id
  my $group_id = $genomic_align_group->dbID;
  my $sth = $self->prepare($genomic_align_block_sql);
  foreach my $genomic_align (@{$genomic_align_group->genomic_align_array}) {
    $sth->execute(
                  ($group_id or "NULL"),
                  $genomic_align_group->type,
                  $genomic_align->dbID
          );
    if (!$group_id) {$group_id = $sth->{'mysql_insertid'};}
  }
  
  return $genomic_align_group;
}


=head2 fetch_by_GenomicAlign_and_type

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
  Arg  2     : string $genomic_align_group_type
  Example    : my $genomic_align_group =
                  $genomic_align_group_adaptor->fetch_by_GenomicAlign_and_type(
                          $genomic_align, "default")
  Description: Returns a Bio::EnsEMBL::Compara::GenomicAlignGroup corresponding
               to the given Bio::EnsEMBL::Compara::GenomicAlign and group_type.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignGroup
  Exceptions : none
  Caller     : object::methodname

=cut

sub fetch_by_GenomicAlign_and_type {
  my ($self, $genomic_align, $type) = @_;

  unless($genomic_align && ref $genomic_align && 
        $genomic_align->isa('Bio::EnsEMBL::Compara::GenomicAlign')) {
    throw("dnafrag argument must be a Bio::EnsEMBL::Compara::GenomicAlign not a [$genomic_align]");
  }

  my $genomic_align_block_sql = qq{
              SELECT 
                    b.genomic_align_id
              FROM genomic_align_group a, genomic_align_group b
              WHERE a.genomic_align_id = b.genomic_align_id
              AND a.genomic_align_id = ?
              AND a.type = ?
        };
  
  my @values;
  
  my $sth = $self->prepare($genomic_align_block_sql);
  $sth->execute($genomic_align->dbID, $type);
  
}


1;
