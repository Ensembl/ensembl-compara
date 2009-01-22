# Copyright EnsEMBL 1999-2009
#
# Ensembl module for Bio::EnsEMBL::DBSQL::ConstrainedElementAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::DBSQL::ConstrainedElementAdaptor - Object adaptor to access data in the constrained_element table

=head2 Get the adaptor from the Registry

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_db(
      -host => "ensembldb.ensembl.org",
      -user => "anonymous");

  my $constrained_element_adaptor = $reg->get_adaptor(
      "Multi", "compara", "ConstrainedElement");

=head2 Store method

  $constrained_element_adaptor->store($mlss_obj,$listref_of_constrained_element_blocks);

=head2 Fetching methods

  my $constrained_elements = $constrained_element_adaptor->fetch_all_by_MethodLinkSpeciesSet_Dnafrag($mlss_obj,$dnafrag_obj);

  my $listref_of_constrained_element_ids = $constrained_element_adaptor->fetch_all_ConstrainedElementIDs_by_MethodLinkSpeciesSet_Dnafrag($mlss_obj,$dnafrag_obj);

  my constrained_elements = $constrained_element_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss_obj,$slice_obj);

  my $listref_of_constrained_element_ids = $constrained_element_adaptor->fetch_all_ConstrainedElementIDs_by_MethodLinkSpeciesSet_Slice($mlss_obj,$slice_obj);

  my constrained_elements = $constrained_element_adaptor->fetch_all_by_ConstrainedElementID($listref_of_constrained_element_ids);

=head2 Other methods

  $genomic_align_adaptor->delete_by_MethodLinkSpeciesSet($mlss_obj);

=head1 DESCRIPTION

This module is intended to access data in the constrained_element table. 

Each species sequence in the constrained element is represented by a Bio::EnsEMBL::Compara::ConstrainedElement object. 
The store module called by Gerp.pm passes a listref (corresponding to all the constrained elements associated with 
a particular aligned segment (generated from the EPO pipeline)) of Bio::EnsEMBL::Compara::ConstrainedElement objects.
The fetch modules ("fetch_all_ConstrainedElementIDs..." or "fetch_all_by_") return either a listref of constrained_element_ids (
each id corresponds to a constrained element block) or a listref of Bio::EnsEMBL::Compara::ConstrainedElement objects

=head1 INHERITANCE

This class inherits all the methods and attributes from Bio::EnsEMBL::DBSQL::BaseAdaptor

=head1 SEE ALSO

 - Bio::EnsEMBL::Registry
 - Bio::EnsEMBL::DBSQL::BaseAdaptor
 - Bio::EnsEMBL::Compara::ConstrainedElement

=head1 AUTHOR

Stephen Fitzgerald (ensembl-compara@ebi.ac.uk)

This module is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::ConstrainedElement;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception;
use Data::Dumper;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->{_use_autoincrement} = 0;
  return $self;
}

#
#=head2 store
#
#  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object 
#  Arg  2     : listref of Bio::EnsEMBL::Compara::ConstrainedElement ($constrained_element) objects 
#               The things you want to store
#  Example    : none
#  Description: It stores the given ConstrainedElements in the database.
#  Returntype : none
#  Exceptions : if it's not a Bio::EnsEMBL::Compara::ConstrainedElement or if 
#		if the first parameter is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
#  Caller     : called by the Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Gerp module 
#
#=cut

sub store {
	my ( $self, $mlss_obj, $constrained_elements ) = @_;

	if (defined($mlss_obj)) {
		throw("$mlss_obj is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")	
		unless ($mlss_obj->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
	} else {
		throw("undefined Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
	}

	my $mlssid = $mlss_obj->dbID;
	my $mlssid_sql =
	"SELECT MAX(constrained_element_id) FROM constrained_element WHERE" .
	" constrained_element_id > " . $mlssid .
	"0000000000 AND constrained_element_id < " .
	($mlssid + 1) . "0000000000";

	my $mlssid_sth = $self->prepare($mlssid_sql);

	my $constrained_element_sql = qq{INSERT INTO constrained_element (
		constrained_element_id,
		dnafrag_id,
		dnafrag_start, 
		dnafrag_end,
		score,
		method_link_species_set_id,
		p_value,
		taxonomic_level
	) VALUES (?,?,?,?,?,?,?,?)};

	my $constrained_element_sth = $self->prepare($constrained_element_sql) or die;

	##lock table 
	$self->dbc->do(qq{ LOCK TABLES constrained_element WRITE });


	foreach my $constrained_element (@$constrained_elements) {
		throw("$constrained_element is not a Bio::EnsEMBL::Compara::ConstrainedElement object")
		unless ($constrained_element->isa("Bio::EnsEMBL::Compara::ConstrainedElement"));

		$mlssid_sth->execute();
		my $constrained_element_id = ($mlssid_sth->fetchrow_array() or
		($mlssid * 10000000000)) + 1;

		foreach my $dnafrag (@{$constrained_element->dnafrags}) {

			$constrained_element_sth->execute(
				$constrained_element_id,
				$dnafrag->[0]->[0],
				$dnafrag->[0]->[1],
				$dnafrag->[0]->[2],
				$constrained_element->score,
				$mlssid,
				($constrained_element->p_value or 0),
				($constrained_element->taxonomic_level or undef)
			);
		}
	}
	## Unlock tables
	$self->dbc->do("UNLOCK TABLES");
}

#=head2 delete_by_MethodLinkSpeciesSet
#
#  Arg  1     : method_link_species_set object $mlss
#  Example    : $constrained_element_adaptor->delete_by_MethodLinkSpeciesSet($mlss);
#  Description: It removes constrained elements with the specified method_link_species_set_id from the database
#  Returntype : none
#  Exceptions : throw if passed parameter is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object 
#  Caller     : general
#
#=cut
#

sub delete_by_MethodLinkSpeciesSet {
  my ($self, $mlss_obj) = @_;

  if (defined($mlss_obj)) {
    throw("$mlss_obj is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")	
      unless ($mlss_obj->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  } else {
    throw("undefined Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
  }

  my $cons_ele_sql =
        qq{DELETE FROM constrained_element WHERE method_link_species_set_id = ?};
  
# Delete constrtained element entries by mlss_id
  my $sth = $self->prepare($cons_ele_sql);
  $sth->execute($mlss_obj->dbID);
}


=head2 fetch_by_dbID

  Arg  1     : int constrained_element_ids
  Example    : my $constrained_element = $constrained_element_adaptor->
               fetch_by_dbID($constrained_element_id);
  Description: Retrieve the corresponding constrained_element.
  Returntype : Bio::EnsEMBL::Compara::ConstrainedElement object
  Exceptions : -none-
  Caller     : object::methodname

=cut

sub fetch_by_dbID {
  my ($self, $constrained_element_id) = @_;
  return ($self->fetch_all_by_dbIDs([$constrained_element_id]))->[0];
}


=head2 fetch_all_by_dbIDs

 Arg  1     : listref of constrained_element_ids
 Example    : my $listref_of_constrained_elements = $constrained_element_adaptor->fetch_all_by_dbIDs($list_ref_of_constrained_element_ids);
 Description: Retrieve the corresponding constrained_elements from a given list of constrained_element_ids 
 Returntype : listref of Bio::EnsEMBL::Compara::ConstrainedElement constrained_elements 
 Exceptions : Returns empty listref if no matching entries are found in the database.
 Caller     : object::methodname

=cut

sub fetch_all_by_dbIDs {
  my ($self, $constrained_element_ids) = @_;
  return $self->fetch_all_by_ConstrainedElementID($constrained_element_ids);
}


#=head2 fetch_all_by_MethodLinkSpeciesSet_Dnafrag
#
#  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet mlss_obj
#  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag dnafrag_obj
#  Example    : my $listref_of_constrained_elements = $constrained_element_adaptor->
#  		fetch_all_ConstrainedElements_by_MethodLinkSpeciesSet_Dnafrag($mlss_obj, $dnafrag_obj);
#  Description: Retrieve the corresponding
#               Bio::EnsEMBL::Compara::ConstrainedElement object listref
#  Returntype : listref of Bio::EnsEMBL::Compara::ConstrainedElement objects
#  Exceptions : Returns empty listref if no matching entries are found in the database.
#  Caller     : object::methodname
#
#=cut

sub fetch_all_by_MethodLinkSpeciesSet_Dnafrag {
	my ($self, $mlss_obj, $dnafrag_obj, $dnafrag_start, $dnafrag_end) = @_;
	if (defined($mlss_obj)) {
		throw("$mlss_obj is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")	
		unless ($mlss_obj->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
	} else {
		throw("undefined Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
	} 
	if(defined($dnafrag_obj)) {
		throw("$dnafrag_obj is not a Bio::EnsEMBL::Compara::DnaFrag object")
		unless ($dnafrag_obj->isa("Bio::EnsEMBL::Compara::DnaFrag"));
	} else {
		throw("undefined Bio::EnsEMBL::Compara::DnaFrag object");
	}

	my @constrained_elements;

	my $sql = qq{
		WHERE
		method_link_species_set_id	= ?
		AND
		dnafrag_id	= ?
	};
	$sql .= qq{ AND dnafrag_start >= ? AND dnafrag_end <= ? } 
	if (defined($dnafrag_start) && defined($dnafrag_end) && ($dnafrag_start <= $dnafrag_end));

	$self->_fetch_all_ConstrainedElements($sql,\@constrained_elements,$mlss_obj->dbID,$dnafrag_obj->dbID,$dnafrag_start,$dnafrag_end);
	return \@constrained_elements;
}

#=head2 fetch_all_ConstrainedElementIDs_by_MethodLinkSpeciesSet_Dnafrag
#
#  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet mlss_obj
#  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag dnafrag_obj
#  Example    : my $listref_of_constrained_element_ids = $constrained_element_adaptor->
#  		fetch_all_ConstrainedElementIDs_by_MethodLinkSpeciesSet_Dnafrag($mlss_obj, $dnafrag_obj);
#  Description: Retrieve the corresponding constrained_element_ids from a given dnafrag and method_link_species_set_id  
#  Returntype : listref of constrained_element_ids (strings)
#  Exceptions : Returns empty listref if no matching entries are found in the database.
#  Caller     : object::methodname
#
#=cut

sub fetch_all_ConstrainedElementIDs_by_MethodLinkSpeciesSet_Dnafrag {
	my ($self, $mlss_obj, $dnafrag_obj, $dnafrag_start, $dnafrag_end) = @_;
	if (defined($mlss_obj)) {
		throw("$mlss_obj is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")	
		unless ($mlss_obj->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
	} else {
		throw("undefined Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
	} 
	if(defined($dnafrag_obj)) {
		throw("$dnafrag_obj is not a Bio::EnsEMBL::Compara::DnaFrag object")
		unless ($dnafrag_obj->isa("Bio::EnsEMBL::Compara::DnaFrag"));
	} else {
		throw("undefined Bio::EnsEMBL::Compara::DnaFrag object");
	}

	my @constrained_element_ids;

	my $sql = qq{
		WHERE
		method_link_species_set_id = ?
		AND
		dnafrag_id = ?
	};

	if (defined($dnafrag_start) && defined($dnafrag_end) && ($dnafrag_start <= $dnafrag_end)) {
		$sql .= qq{ AND dnafrag_start >= ? AND dnafrag_end <= ? };
		$self->_fetch_all_ConstrainedElementIDs($sql,\@constrained_element_ids,$mlss_obj->dbID,
						$dnafrag_obj->dbID,$dnafrag_start,$dnafrag_end);
	} else {
		$self->_fetch_all_ConstrainedElementIDs($sql,\@constrained_element_ids,$mlss_obj->dbID,
						$dnafrag_obj->dbID);
	}
	return \@constrained_element_ids;
}

#=head2 fetch_all_by_MethodLinkSpeciesSet_Slice
#
#  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss_obj
#  Arg  2     : Bio::EnsEMBL::Slice $slice_obj
#  Example    : my $listref_of_constrained_elements = $constrained_element_adaptor->
#  		fetch_all_by_MethodLinkSpeciesSet_Slice($mlss_obj, $slice_obj);
#  Description: Retrieve the corresponding
#               Bio::EnsEMBL::Compara::ConstrainedElement object listref
#  Returntype : listref of Bio::EnsEMBL::Compara::ConstrainedElement objects
#  Exceptions : Returns empty listref if no matching entries are found in the database.
#  Caller     : object::methodname
#
#=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
	my ($self, $mlss_obj, $slice_obj) = @_;
	if (defined($mlss_obj)) {
		throw("$mlss_obj is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")	
		unless ($mlss_obj->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
	} else {
		throw("undefined Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
	}
	if (defined($slice_obj)) {
		throw("$slice_obj is not a Bio::EnsEMBL::Slice object")	
		unless ($slice_obj->isa("Bio::EnsEMBL::Slice"));
	} else {
		throw("undefined Bio::EnsEMBL::Slice object");
	}

	my $dnafrag_adp = $self->db->get_DnaFragAdaptor;
	my $dnafrag = $dnafrag_adp->fetch_by_Slice($slice_obj);
	my @constrained_elements;
	
	my $sql = qq{
		WHERE
		method_link_species_set_id = ?
		AND
		dnafrag_id = ?
		AND
		dnafrag_end >= ? 
		AND
		dnafrag_start <= ?
	};
	
	$self->_fetch_all_ConstrainedElements($sql,\@constrained_elements,
		$mlss_obj->dbID,$dnafrag->dbID,$slice_obj->start,$slice_obj->end);
	return \@constrained_elements;
}

#=head2 fetch_all_ConstrainedElementIDs_by_MethodLinkSpeciesSet_Slice
#
#  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss_obj
#  Arg  2     : Bio::EnsEMBL::Slice $slice_obj
#  Example    : my $listref_of_constrained_element_ids = $constrained_element_adaptor->
#  		fetch_all_ConstrainedElementIDs_by_MethodLinkSpeciesSet_Slice($mlss_obj, $slice_obj);
#  Description: Retrieve the constrained_element_ids corresponding to some mlssid and slice 
#  Returntype : listref of constrained_element_ids (strings)
#  Exceptions : Returns empty listref if no matching entries are found in the database.
#  Caller     : object::methodname
#
#=cut

sub fetch_all_ConstrainedElementIDs_by_MethodLinkSpeciesSet_Slice {
	my ($self, $mlss_obj, $slice_obj) = @_;
	if (defined($mlss_obj)) {
		throw("$mlss_obj is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")	
		unless ($mlss_obj->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
	} else {
		throw("undefined Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
	}
	if (defined($slice_obj)) {
		throw("$slice_obj is not a Bio::EnsEMBL::Slice object")	
		unless ($slice_obj->isa("Bio::EnsEMBL::Slice"));
	} else {
		throw("undefined Bio::EnsEMBL::Slice object");
	}

	my $dnafrag_adp = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "DnaFrag");
	my $dnafrag = $dnafrag_adp->fetch_by_Slice($slice_obj);
	my @constrained_element_ids;
	
	my $sql = qq{
		WHERE
		method_link_species_set_id = ?
		AND
		dnafrag_id = ?
		AND
		dnafrag_end >= ? 
		AND
		dnafrag_start <= ?
	};
	
	$self->_fetch_all_ConstrainedElementIDs($sql,\@constrained_element_ids,
		$mlss_obj->dbID,$dnafrag->dbID,$slice_obj->start,$slice_obj->end);
	return \@constrained_element_ids;
}

sub _fetch_all_ConstrainedElementIDs {
	my ($self) = shift;
	my ($sql, $constrained_element_ids, @filters) = @_;
	$sql = qq{
		SELECT DISTINCT(constrained_element_id) 
		FROM 
       		constrained_element} . $sql;

	my $sth = $self->prepare($sql);
  	$sth->execute( @filters );
	while (my @values = $sth->fetchrow_array()) {
		push(@$constrained_element_ids, $values[0]);
	}
}	

sub _fetch_all_ConstrainedElements_by_ConstrainedElementID {
	my ($self) = shift;
	my ($sql, $constrained_elements, $dbIDs) = @_;
        
	$sql = qq{
       		SELECT
       		constrained_element_id,
       		dnafrag_id,
       		dnafrag_start,
       		dnafrag_end,
       		method_link_species_set_id,
      		score,
      		p_value,
       		taxonomic_level
       		FROM
       		constrained_element} . $sql;

	my $sth = $self->prepare($sql);
	foreach my $constrained_element_id (@{ $dbIDs }) {
		my(%general_attributes, @dnafrags);
		$sth->execute( $constrained_element_id );
		while (my @values = $sth->fetchrow_array()) {
			$general_attributes{dbID} = $values[0];
			$general_attributes{mlssid} = $values[4];
			$general_attributes{score} = $values[5];
			$general_attributes{p_value} = $values[6];
			$general_attributes{taxonomic_level} = $values[7];
			push(@dnafrags, [ @values[1..3] ]);
		}
		my $constrained_element = new Bio::EnsEMBL::Compara::ConstrainedElement(
			-adaptor => $self,
			-constrained_element_id => $general_attributes{dbID},
			-dnafrags => \@dnafrags,
			-method_link_species_set_id => $general_attributes{mlssid},
			-score => $general_attributes{score},
			-p_value => $general_attributes{p_value},
			-taxonomic_level => $general_attributes{taxonomic_level},
		);
		push(@$constrained_elements, $constrained_element);
	}
}

sub _fetch_all_ConstrainedElements {
	my ($self) = shift;
	my ($sql, $constrained_elements, @filters) = @_;
	$sql = qq{
       		SELECT
       		constrained_element_id,
       		dnafrag_id,
       		dnafrag_start,
       		dnafrag_end,
       		method_link_species_set_id,
      		score,
      		p_value,
       		taxonomic_level
       		FROM
       		constrained_element} . $sql;

	my $sth = $self->prepare($sql);
	$sth->execute( @filters );
	while (my @values = $sth->fetchrow_array()) {
		my $constrained_element = new Bio::EnsEMBL::Compara::ConstrainedElement(
			-adaptor => $self,
			-constrained_element_id => $values[0],
			-dnafrags => [ [ @values[1..3] ] ],
			-method_link_species_set_id => $values[4],
			-score => $values[5],
			-p_value => $values[6],
			-taxonomic_level => $values[7],
		);
		push(@$constrained_elements, $constrained_element);
	}
}	


#=head2 fetch_all_by_ConstrainedElementID
#
#  Arg  1     : listref of constrained_element_ids
#  Example    : my $listref_of_constrained_elements = $constrained_element_adaptor->fetch_all_by_ConstrainedElementID($list_ref_of_constrained_element_ids);
#  Description: Retrieve the corresponding constrained_elements from a given list of constrained_element_ids 
#  Returntype : listref of Bio::EnsEMBL::Compara::ConstrainedElement constrained_elements 
#  Exceptions : Returns empty listref if no matching entries are found in the database.
#  Caller     : object::methodname
#
#=cut

sub fetch_all_by_ConstrainedElementID {
	my ($self, $constrained_element_ids) = @_;
	my @constrained_elements;
	my $sql = qq{
		WHERE
		constrained_element_id = ?
	};
	$self->_fetch_all_ConstrainedElements_by_ConstrainedElementID($sql, \@constrained_elements, $constrained_element_ids);
	return \@constrained_elements;
}



1;
