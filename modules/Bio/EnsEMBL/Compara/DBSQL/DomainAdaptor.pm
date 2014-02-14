=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 NAME

DomainAdaptor

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

  my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-user   => 'myusername',
						       -dbname => 'mycompra_db',
						       -host   => 'myhost');

  my $da = $famdb->get_DomainAdaptor;
  my $dom = $da->fetch_by_stable_id('PR00262');

  my $ma = $db->get_SeqMemberAdaptor;
  my $member = $ma->fetch_by_source_stable_id('SWISSPROT', 'YSV4_CAEEL')};
  my @dom = @{$da->fetch_all_by_Member($member)};


  @dom = @{$da->fetch_by_description_with_wildcards('interleukin',1)};
  @dom = @{$da->fetch_all};

=head1 DESCRIPTION

This module is an entry point into a database of protein families,
clustering SWISSPROT/TREMBL and ensembl protein sets using the TRIBE MCL algorithm.
The clustering neatly follows the SWISSPROT DE-lines, which are 
taken as the description of the whole family.

The objects can be read from and write to a compara database.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::DomainAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Domain;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);


sub fetch_all_by_Member {
  my ($self, $member) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  my $join = [[['domain_member', 'dm'], 'd.domain_id = dm.domain_id']];
  my $constraint = "dm.member_id = " .$member->dbID;

  return $self->generic_fetch($constraint, $join);
}

sub fetch_by_Member_Domain_source {
  my ($self, $member, $source_name) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  $self->throw("source_name arg is required\n")
    unless ($source_name);

  my $join = [[['domain_member', 'dm'], 'd.domain_id = dm.domain_id']];
  my $constraint = "s.source_name = '$source_name'";
  $constraint .= " AND dm.member_id = " . $member->dbID;

  return $self->generic_fetch($constraint, $join);
}

=head2 fetch_by_description_with_wildcards

 Arg [1]    : string $description
 Arg [2]    : int $wildcard (optional)
              if set to 1, wildcards are added and the search is a slower LIKE search
 Example    : $fams = $FamilyAdaptor->fetch_by_description_with_wildcards('REDUCTASE',1);
 Description: simplistic substring searching on the description to get the families
              matching the description. (The search is currently case-insensitive;
              this may change if SPTR changes to case-preservation)
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_by_description_with_wildcards{ 
    my ($self,$desc,$wildcard) = @_; 

    my $constraint;
    
    if ($wildcard) {
      $constraint = "d.description LIKE '"."%"."\U$desc"."%"."'";
    }
    else {
      $constraint = "d.description = '$desc'";
    }

    return $self->generic_fetch($constraint);
}

#
# INTERNAL METHODS
#
###################

# internal method used in multiple calls above to build domain objects from table data  

sub _tables {
  return (['domain', 'd'], ['source', 's']);
}

sub _columns {
  return qw (d.domain_id
             d.stable_id
             d.description
             s.source_id
             s.source_name);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my ($domain_id, $stable_id, $description, $source_id, $source_name);

  $sth->bind_columns(\$domain_id, \$stable_id, \$description,
                     \$source_id, \$source_name);

  my @domains = ();
  
  while ($sth->fetch()) {
    push @domains, Bio::EnsEMBL::Compara::Domain->new_fast({
            '_adaptor'      => $self,       # field name NOT in sync with Bio::EnsEMBL::Storable
            '_dbID'         => $domain_id,  # field name NOT in sync with Bio::EnsEMBL::Storable
            '_stable_id'    => $stable_id,
            '_description'  => $description,
            '_source_id'    => $source_id,
            '_source_name'  => $source_name,
       });
  }
  
  return \@domains;  
}

sub _default_where_clause {
  return 'd.source_id = s.source_id';
}

#
# STORE METHODS
#
################

=head2 store

 Arg [1]    : Bio::EnsEMBL::Compara::Domain $dom
 Example    : $DomainAdaptor->store($dom)
 Description: Stores a domain object into a family  database
 Returntype : int 
              been the database family identifier, if domain stored correctly
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::Domain
 Caller     : general

=cut

sub store {
  my ($self,$dom) = @_;

  $dom->isa('Bio::EnsEMBL::Compara::Domain') ||
    $self->throw("You have to store a Bio::EnsEMBL::Compara::Domain object, not a $dom");

  my $sql = "SELECT domain_id from domain where stable_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($dom->stable_id);
  my $rowhash = $sth->fetchrow_hashref;

  $dom->source_id($self->store_source($dom->source_name));

  if ($rowhash->{domain_id}) {
    $dom->dbID($rowhash->{domain_id});
  } else {
  
    $sql = "INSERT INTO domain (stable_id, source_id, description) VALUES (?,?,?)";
    $sth = $self->prepare($sql);
    $sth->execute($dom->stable_id,$dom->source_id,$dom->description);
    $dom->dbID($sth->{'mysql_insertid'});
  }
  
  $sql = "INSERT IGNORE INTO domain_member (domain_id, member_id, member_start, member_end) VALUES (?,?,?,?)";
  $sth = $self->prepare($sql);
  foreach my $member (@{$dom->get_all_Members}) {
    # Stores the member if not yet stored
    $self->db->get_MemberAdaptor->store($member) unless (defined $member->dbID);
    $sth->execute($self->dbID, $member->dbID, $member->member_start, $member->member_end);
  }

  return $dom->dbID;
}


1;
