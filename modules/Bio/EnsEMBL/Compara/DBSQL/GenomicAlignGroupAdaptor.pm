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
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

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
      throw("GenomicAlign [$genomic_align] in GenomicAlignGroup is not in DB");
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


=head2 fetch_by_dbID

  Arg  1     : integer group_id
  Example    : my $genomic_align_group =
                  $genomic_align_group_adaptor->fetch_by_dbID(12413)
  Description: Returns a Bio::EnsEMBL::Compara::GenomicAlignGroup corresponding
               to the given group_id.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignGroup
  Exceptions : none
  Caller     : object::methodname

=cut

sub fetch_by_dbID {
  my ($self, $group_id) = @_;
  my $genomic_align_group;

  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;
  
  my $genomic_align_block_sql = qq{
              SELECT
                  group_id,
                  type,
                  genomic_align_id
              FROM
                genomic_align_group
              WHERE
                group_id = ?
        };
  
  my @values;
  
  my $sth = $self->prepare($genomic_align_block_sql);
  $sth->execute($group_id);

  # Group results in order to be able to build Bio::EnsEMBL::Compara::GenomicAlignGroupAdaptor objects
  my $group;
  while (my $values = $sth->fetchrow_arrayref) {
    my ($group_id, $type, $genomic_align_id) = @$values;

    $group->{'group_id'} = $group_id;
    $group->{'type'} = $type;
    my $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dbID => $genomic_align_id,
            -adaptor => $genomic_align_adaptor
        );

    push(@{$group->{'genomic_align_array'}}, $this_genomic_align);
  }

  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
          -dbID => $group->{'group_id'},
          -adaptor => $self,
          -type => $group->{'type'},
          -genomic_align_array => $group->{'genomic_align_array'}
      );
  foreach my $this_genomic_align (@{$genomic_align_group->genomic_align_array}) {
    $this_genomic_align->genomic_align_group_by_type($genomic_align_group->type, $genomic_align_group);
  }

  return $genomic_align_group;
}


=head2 fetch_all_by_GenomicAlign

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
                      - or -
               integer $genomic_align_id
  Example    : my $genomic_align_groups =
                  $genomic_align_group_adaptor->fetch_all_by_GenomicAlign(
                          $genomic_align)
  Example    : my $genomic_align_groups =
                  $genomic_align_group_adaptor->fetch_all_by_GenomicAlign(
                          124214)
  Description: Returns all the  Bio::EnsEMBL::Compara::GenomicAlignGroup
               corresponding to the given Bio::EnsEMBL::Compara::GenomicAlign.
  Returntype : a ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignGroup
               objects.
  Exceptions : none
  Caller     : object::methodname

=cut

sub fetch_all_by_GenomicAlign {
  my ($self, $genomic_align) = @_;
  my $genomic_align_groups = [];

  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;
  
  # Get Bio::EnsEMBL::Compara::GenomicAlign object from dbID if needed
  if ($genomic_align =~ /^\d+$/) {
    $genomic_align = $genomic_align_adaptor->fetch_by_dbID($genomic_align);
  }
  # Check Bio::EnsEMBL::Compara::GenomicAlign object
  unless($genomic_align && ref $genomic_align && 
        $genomic_align->isa('Bio::EnsEMBL::Compara::GenomicAlign')) {
    throw("genomic_align argument must be a Bio::EnsEMBL::Compara::GenomicAlign not a [$genomic_align]");
  }

  my $genomic_align_block_sql = qq{
              SELECT
                group_id,
                type
              FROM
                genomic_align_group
              WHERE
                genomic_align_id = ?
        };
  
  my $sth = $self->prepare($genomic_align_block_sql);
  $sth->execute($genomic_align->dbID);


  my $groups;
  while (my $values = $sth->fetchrow_arrayref) {
    my ($group_id, $type) = @$values;

    $groups->{$group_id}->{'type'} = $type;
  }

  foreach my $group_id (keys %$groups) {
    my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
            -dbID => $group_id,
            -adaptor => $self,
            -type => $groups->{$group_id}->{'type'},
        );
    push(@{$genomic_align_groups}, $genomic_align_group);
  }

  return $genomic_align_groups;
}

=head2 fetch_by_GenomicAlign_and_type

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
                      - or -
               integer $genomic_align_id
  Arg  2     : string $genomic_align_group_type
  Example    : my $genomic_align_group =
                  $genomic_align_group_adaptor->fetch_by_GenomicAlign_and_type(
                          $genomic_align, "default")
  Example    : my $genomic_align_groups =
                  $genomic_align_group_adaptor->fetch_all_by_GenomicAlign(
                          124214, "default")
  Description: Returns a Bio::EnsEMBL::Compara::GenomicAlignGroup corresponding
               to the given Bio::EnsEMBL::Compara::GenomicAlign and group_type.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignGroup
  Exceptions : none
  Caller     : object::methodname

=cut

sub fetch_by_GenomicAlign_and_type {
  my ($self, $genomic_align, $type) = @_;
  my $genomic_align_group;

  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;
  
  # Get Bio::EnsEMBL::Compara::GenomicAlign object from dbID if needed
  if ($genomic_align =~ /^\d+$/) {
    $genomic_align = $genomic_align_adaptor->fetch_by_dbID($genomic_align);
  }
  # Check Bio::EnsEMBL::Compara::GenomicAlign object
  unless($genomic_align && ref $genomic_align && 
        $genomic_align->isa('Bio::EnsEMBL::Compara::GenomicAlign')) {
    throw("dnafrag argument must be a Bio::EnsEMBL::Compara::GenomicAlign not a [$genomic_align]");
  }

  my $genomic_align_block_sql = qq{
              SELECT
                  b.group_id,
                  b.type,
                  b.genomic_align_id
              FROM
                genomic_align_group a, genomic_align_group b
              WHERE
                a.group_id = b.group_id
                AND a.genomic_align_id = ?
                AND a.type = ?
        };
  
  my @values;
  
  my $sth = $self->prepare($genomic_align_block_sql);
  $sth->execute($genomic_align->dbID, $type);

  # Group results in order to be able to build Bio::EnsEMBL::Compara::GenomicAlignGroupAdaptor objects
  my $group;
  while (my $values = $sth->fetchrow_arrayref) {
    my ($group_id, $type, $genomic_align_id) = @$values;

    $group->{'group_id'} = $group_id;
    $group->{'type'} = $type;
    my $this_genomic_align;
    if ($genomic_align_id == $genomic_align->dbID) {
      # Use Bio::EnsEMBL::Compara::GenomicAlign object given by argument if possible
      $this_genomic_align = $genomic_align;
    } else {
      # Create a new Bio::EnsEMBL::Compara::GenomicAlign object otherwise
      $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
              -dbID => $genomic_align_id,
              -adaptor => $genomic_align_adaptor
          );
    }

    push(@{$group->{'genomic_align_array'}}, $this_genomic_align);
  }

  $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
          -dbID => $group->{'group_id'},
          -adaptor => $self,
          -type => $group->{'type'},
          -genomic_align_array => $group->{'genomic_align_array'}
      );
  foreach my $this_genomic_align (@{$genomic_align_group->genomic_align_array}) {
    $this_genomic_align->genomic_align_group_by_type($genomic_align_group->type, $genomic_align_group);
  }

  return $genomic_align_group;
}


=head2 retrieve_all_direct_attributes

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignGroup $genomic_align_group
  Example    : $genomic_align_group_adaptor->retrieve_all_direct_attributes($genomic_align_group)
  Description: Retrieve the all the direct attibutes corresponding to the dbID of the
               Bio::EnsEMBL::Compara::GenomicAlignGroup object. It is used after lazy fetching
               of the object for populating it when required.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : 
  Caller     : none

=cut

sub retrieve_all_direct_attributes {
  my ($self, $genomic_align_group) = @_;

  my $sql = qq{
                SELECT
                    type
                FROM
                    genomic_align_group
                WHERE
                    group_id = ?
                LIMIT 1
        };

  my $sth = $self->prepare($sql);
  $sth->execute($genomic_align_group->dbID);
  my ($type) = $sth->fetchrow_array();
  
  ## Populate the object
  $genomic_align_group->adaptor($self);
  $genomic_align_group->type($type);

  return $genomic_align_group;
}


1;
