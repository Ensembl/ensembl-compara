# $Id$
# 
# BioPerl module for Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor
# 
# Initially cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk>
# Now cared by Elia Stupka <elia@fugu-sg.org> and Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

FamilyAdaptor - DESCRIPTION of Object

  This object represents a family coming from a database of protein families.

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

  my $famdb = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-user   => 'myusername',
								       -dbname => 'myfamily_db',
								       -host   => 'myhost');

  my $fam_adtor = $famdb->get_FamilyAdaptor;

  my $fam = $fam_adtor->fetch_by_stable_id('ENSF000013034');
  my @fam = @{$fam_adtor->fetch_by_dbname_id('SPTR', 'P000123')};
  @fam = @{$fam_adtor->fetch_by_description_with_wildcards('interleukin',1)};
  @fam = @{$fam_adtor->fetch_all()};

  ### You can add the FamilyAdaptor as an 'external adaptor' to the 'main'
  ### Ensembl database object, then use it as:

  $ensdb = new Bio::EnsEMBL::DBSQL::DBAdaptor->(-user....);

  $ensdb->add_db_adaptor('MyfamilyAdaptor', $fam_adtor);

  # then later on, elsewhere: 
  $fam_adtor = $ensdb->get_db_adaptor('MyfamilyAdaptor');

  # also available:
  $ensdb->get_all_db_adaptors;
  $ensdb->remove_db_adaptor('MyfamilyAdaptor');

=head1 DESCRIPTION

This module is an entry point into a database of protein families,
clustering SWISSPROT/TREMBL and ensembl protein sets using the TRIBE MCL algorithm.
The clustering neatly follows the SWISSPROT DE-lines, which are 
taken as the description of the whole family.

The objects can be read from and write to a family database.

For more info, see ensembl-doc/family.txt

=head1 CONTACT

 Philip Lijnzaad <Lijnzaad@ebi.ac.uk> [original perl modules]
 Anton Enright <enright@ebi.ac.uk> [TRIBE algorithm]
 Elia Stupka <elia@fugu-sg.org> [refactoring]
 Able Ureta-Vidal <abel@ebi.ac.uk> [multispecies migration]

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

# needed by convert_store_family
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::FamilyConf;
use Bio::EnsEMBL::Compara::Taxon;

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);

=head2 fetch_by_relation

 Arg [1]    : string $dbname
 Arg [2]    : string $member_stable_id
 Example    : $fams = $FamilyAdaptor->fetch_of_dbname_id('SPTR', 'P01235');
 Description: find the family to which the given database and  member_stable_id belong
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
              (could be empty or contain more than one Family in the case of ENSEMBLGENE only)
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_by_relation {
  my ($self, $relation) = @_;

  my $join;
  my $constraint;

  $self->throw() 
    unless (defined $relation && ref $relation);
  
  if ($relation->isa('Bio::EnsEMBL::Compara::Member')) {
    $join = [['family_member', 'fm'], 'f.family_id = fm.family_id'];
    my $member_id = $relation->dbID;
    $constraint = "fm.member_id = $member_id";
  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
#    $join = [['domain_family', 'df'], 'f.family_id = df.family_id'];
#    my $domain_id = $relation->dbID;
#    $constraint = "df.domain_id = $domain_id";
#  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
#  }
  else {
    $self->throw();
  }

  return $self->generic_fetch($constraint, $join);
}

sub fetch_by_relation_source {
  my ($self, $relation, $source_name) = @_;

  my $join;
  my $constraint = "s.source_name = $source_name";

  $self->throw() 
    unless (defined $relation && ref $relation);
  
  $self->throw("source_name arg is required\n")
    unless ($source_name);

  if ($relation->isa('Bio::EnsEMBL::Compara::Member')) {
    $join = [['family_member', 'fm'], 'f.family_id = fm.family_id'];
    my $member_id = $relation->dbID;
    $constraint .= " AND fm.member_id = $member_id";
  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
#    $join = [['domain_family', 'df'], 'f.family_id = df.family_id'];
#    my $domain_id = $relation->dbID;
#    $constraint = " AND df.domain_id = $domain_id";
#  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
#  }
  else {
    $self->throw();
  }

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
      $constraint = "f.description LIKE '"."%"."\U$desc"."%"."'";
    }
    else {
      $constraint = "f.description = '$desc'";
    }

    return $self->generic_fetch($constraint);
}

=head2 fetch_Taxon_by_dbname_dbID

 Arg [1]    : string $dbname
              Either "ENSEMBLGENE", "ENSEMBLPEP" or "SPTR" 
 Arg [2]    : int dbID
              a family_id
 Example    : $FamilyAdaptor->fetch_Taxon_by_dbname('ENSEMBLGENE',1)
 Description: get all the taxons that belong to a particular database and family_id
 Returntype : an array reference of Bio::EnsEMBL::Compara::Taxon objects
              (which may be empty)
 Exceptions : when missing argument
 Caller     : general

=cut

sub fetch_Taxon_by_dbname_dbID {
  my ($self,$dbname,$dbID) = @_;
  
  $self->throw("Should give defined databasename and family_id as arguments\n") unless (defined $dbname && defined $dbID);

  my $q = "SELECT distinct(taxon_id) as taxon_id
           FROM family f, family_members fm, external_db edb
           WHERE f.family_id = fm.family_id
           AND fm.external_db_id = edb.external_db_id 
           AND f.family_id = $dbID
           AND edb.name = '$dbname'"; 
  $q = $self->prepare($q);
  $q->execute;

  my @taxons = ();

  while (defined (my $rowhash = $q->fetchrow_hashref)) {
    my $TaxonAdaptor = $self->db->get_TaxonAdaptor;
    my $taxon = $TaxonAdaptor->fetch_by_taxon_id($rowhash->{taxon_id});
    push @taxons, $taxon;
  }
    
  return \@taxons;

}



=head2 fetch_alignment

  Arg [1]    : Bio::EnsEMBL::External::Family::Family $family
  Example    : $family_adaptor->fetch_alignment($family);
  Description: Retrieves the alignment strings for all the members of a 
               family
  Returntype : none
  Exceptions : none
  Caller     : FamilyMember::align_string

=cut

sub fetch_alignment {
  my($self, $family) = @_;

  my $members = $family->get_all_Member;
  return unless(@$members);

  my $sth = $self->prepare("SELECT family_member_id, alignment 
                            FROM family_members
                            WHERE family_id = ?");
  $sth->execute($family->dbID);

  #move results of query into hash keyed on family member id
  my %align_hash = map {$_->[0] => $_->[1]} (@{$sth->fetchall_arrayref});
  $sth->finish;

  #set the slign strings for each of the members
  foreach my $member (@$members) {
    $member->alignment_string($align_hash{$member->dbID()});
  }

  return;
}


##################
# internal methods

#internal method used in multiple calls above to build family objects from table data  

sub _tables {
  my $self = shift;

  return (['family', 'f'], ['source', 's']);
}

sub _columns {
  my $self = shift;

  return qw (f.family_id
             f.stable_id
             f.description
             f.descritpion_score
             s.source_id
             s.source_name);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my ($family_id, $stable_id, $description, $description_score, $source_id, $source_name);

  $sth->bind_columns(\$family_id, \$stable_id, \$description, \$description_score,
                     \$source_id, \$source_name);

  my @families = ();
  
  while ($sth->fetch()) {
    push @families, Bio::EnsEMBL::Compara::Family->new_fast
      ({'_dbID' => $family_id,
       '_stable_id' => $stable_id,
       '_description' => $description,
       '_description_score' => $description_score,
       '_source_id' => $source_id,
       '_source_name' => $source_name,
       '_adaptor' => $self});
  }
  
  return \@families;  
}

sub _default_where_clause {
  my $self = shift;

  return 'f.source_id = s.source_id';
}

###############
# store methods

=head2 store

 Arg [1]    : Bio::EnsEMBL::ExternalData:Family::Family $fam
 Example    : $FamilyAdaptor->store($fam)
 Description: Stores a family object into a family  database
 Returntype : int 
              been the database family identifier, if family stored correctly
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::Family
 Caller     : general

=cut

sub store {
  my ($self,$fam) = @_;

  $fam->isa('Bio::EnsEMBL::Compara::Family') ||
    $self->throw("You have to store a Bio::EnsEMBL::Compara::Family object, not a $fam");

  my $sql = "SELECT family_id from family where stable_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($fam->stable_id);
  my $rowhash = $sth->fetchrow_hashref;
  if ($rowhash->{family_id}) {
    return $rowhash->{family_id};
  }
  
  $fam->source_id($self->store_source($fam->source_name));
  
  $sql = "INSERT INTO family (stable_id, source_id, description, description_score) VALUES (?,?,?,?)";
  $sth = $self->prepare($sql);
  $sth->execute($fam->stable_id,$fam->source_id,$fam->description,$fam->description_score);
  $fam->dbID($sth->{'mysql_insertid'});

  foreach my $member_attribue (@{$fam->get_all_Member}) {   
    $self->store_relation($member_attribue, $fam);
  }

  return $fam->dbID;
}

=head2 convert_store_family

 Arg [1]    : -family => \@Bio::Cluster::SequenceFamily
 Example    : $FamilyAdaptor->convert_store_family(-family=>\@family)
 Description: converts  Bio::Cluster::SequenceFamily objects into a Bio::EnsEMBL::Compara objects
              and store.
 Returntype : array of dbIDs 
              been the database family identifier, if family stored correctly
 Exceptions : 
 Caller     : general

=cut

sub convert_store_family {
    my($self,@args) = @_;
    my ($family) = $self->_rearrange([qw(FAMILY)],@args);

    my %conf = %Bio::EnsEMBL::Compara::FamilyConf::FamilyConf;
    my @ens_species = split(',',$conf{'ENSEMBL_SPECIES'});
    my $family_prefix = $conf{"FAMILY_PREFIX"};
    my $release       = $conf{'RELEASE'};
    my $ext_db_name   = $conf{'EXTERNAL_DBNAME'};
    my %taxon_species;
    my @id;

    my @taxon_str;
    foreach my $sp(@ens_species){
      $sp = uc $sp;
      push @taxon_str, $conf{"$sp"."_TAXON"};
    }
    my  %ens_taxon_info = $self->_setup_ens_taxon(@taxon_str);


    my @ens_fam;
    my $family_count = $conf{"FAMILY_START"} || 1;
    foreach my $fam (@{$family}){
      my @members = $fam->get_members;
      my @ens_mem;
      foreach my $mem (@members){
        my $taxon = $mem->species;
        if(!$taxon->ncbi_taxid){
            foreach my $key (keys %ens_taxon_info){
              if($mem->display_id =~/$key/){
                my %taxon_hash = %{$ens_taxon_info{$key}};
                my @class = split(':',$taxon_hash{'taxon_classification'});
                $taxon = Bio::EnsEMBL::Compara::Taxon->new(-classification=>\@class);
                $taxon->common_name($taxon_hash{'taxon_common_name'});
                $taxon->sub_species($taxon_hash{'taxon_sub_species'});
                $taxon->ncbi_taxid($taxon_hash{'taxon_id'});
                last;
              }
            }
        }

        bless $taxon,"Bio::EnsEMBL::Compara::Taxon";

        my $member = Bio::EnsEMBL::Compara::FamilyMember->new();
        $member->family_id($fam->family_id);
        my ($annot) = $mem->annotation->get_Annotations('dblink');
        $member->database(uc $annot->database);
        $member->stable_id($mem->display_name);
        $taxon->ncbi_taxid || $self->throw($mem->id." has no taxon id!");
        $self->db->get_TaxonAdaptor->store_if_needed($taxon);
	$member->taxon_id($taxon->ncbi_taxid);

        $member->adaptor($self);

        $member->database(uc $ext_db_name) if (! defined $member->database || $member->database eq "");
        push @ens_mem, $member;
      }
      my $stable_id = sprintf ("$family_prefix%011.0d",$family_count);
      $family_count++;
      my $ens_fam= new Bio::EnsEMBL::Compara::Family(-stable_id=>$stable_id,
                                                                  -members=>\@ens_mem,
                                                                  -description=>$fam->description,
                                                                  -score=>$fam->annotation_score,
                                                                  -adpator=>$self);

      $ens_fam->release($release);
      #$ens_fam->annotation_confidence_score($fam->annotation_score);

      push @id,$self->store($ens_fam);
  }

 return @id;

}

#process ensembl taxon information for FamilyConf.pm
sub _setup_ens_taxon {
    my ($self,@taxon_str) = @_;

    my %hash;
    foreach my $str(@taxon_str){

      $str=~s/=;/=undef;/g;
      my %taxon = map{split '=',$_}split';',$str;
      my $prefix = $taxon{'PREFIX'}; 
      delete $taxon{'PREFIX'};
      $hash{$prefix} = \%taxon;
    }
    return %hash;
}

1;
