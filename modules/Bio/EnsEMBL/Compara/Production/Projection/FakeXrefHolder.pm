=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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


=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder

=head1 DESCRIPTION

This class is used as a way of getting database entries from a core
database quickly by not having to go through core objects and being able
to do the join using stable IDs alone. At the moment it will return XRefs
linked to the peptide if given a gene or peptide member.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref wrap_array);

use Bio::EnsEMBL::DBEntry;
use Bio::EnsEMBL::OntologyXref;

=head2 new()

  Arg[-dbentries] : required; ArrayRef of entries of type DBEntry
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  my ( $dbentries, ) = rearrange( [qw(dbentries )], @args );

  assert_ref( $dbentries, 'ARRAY' );
  confess('The attribute dbentries must be specified during construction or provide a builder subroutine') if !defined $dbentries;
  $self->{dbentries} = $dbentries;

  return $self;
}

=head2 dbentries()

  Description : Getter. ArrayRef of entries of type DBEntry

=cut

sub dbentries {
  my ($self) = @_;
  return $self->{dbentries};
}

=head2 get_all_DBEntries()

  Arg[1]      : String; entry type where the value given is a dbname
  Description : Returns all DBEntries or just the DBEntries matching the given
                db name
  Returntype  : ArrayRef of the entries 

=cut

sub get_all_DBEntries {
  my ($self, $entry_type) = @_;
  
  return $self->dbentries() unless $entry_type;
  
  my @entries;
  foreach my $entry (@{$self->dbentries()}) {
    if($entry->dbname() eq $entry_type) {
      push(@entries, $entry);
    }
  }
  
  return \@entries;
}

### Factory

=head2 build_display_xref_from_Member()

  Arg[1]      : Bio::EnsEMBL::Compara::Member; The member to search by
  Description : Returns the display DBEntry from the given Member. If the 
                member was an ENSEMBLGENE we consult the Gene otherwise
                for ENSEMBLPEP we consult the Translation (both from core). If
                the DBEntry was empty we will return an object 
                containing no elements
  Returntype  : Instance of FakeXrefHolder

=cut

sub build_display_xref_from_Member {
  my ($class, $member) = @_;
  my $display_xref;
  my $source_name = $member->source_name();
  if($source_name eq 'ENSEMBLGENE') {
    $display_xref = $member->get_Gene()->display_xref();
  }
  elsif($source_name eq 'ENSEMBLPEP') {
    $display_xref = $member->get_Translation()->display_xref();
  }
  else {
    throw('I do not understand how to process the source_name '.$source_name);
  }
  my @entries = (defined $display_xref) ? ($display_xref) : () ;
  return $class->new(-DBENTRIES => \@entries);
}

=head2 build_peptide_dbentries_from_member()

  Arg[1]      : Bio::EnsEMBL::Compara::Member; The member to search by
  Arg[2]      : String; The dbname to look for. Supports like
  Description : Searches for entries linked to the given Member. If given
                a gene member it will look for the cannonical links and if
                given a peptide member it assumes this is the correct 
                identifier to use.
  Returntype  : Instance of FakeXrefHolder

=cut

sub build_peptide_dbentries_from_Member {
  my ($class, $member, $db_names) = @_;
  
  if(defined $db_names) {
    $db_names = wrap_array($db_names);
  }
  else {
    $db_names = [];
  }
  
  #my $peptide_member = ($member->source_name() eq 'ENSEMBLGENE') ? $member->get_canonical_SeqMember() : $member;
  my $canonical_member = $member->get_canonical_SeqMember;

  my $dbc = $canonical_member->genome_db()->db_adaptor()->dbc();
  
  my $columns  = 'x.xref_id, x.external_db_id, x.dbprimary_acc, x.display_label, x.version, x.description, x.info_type, x.info_text, oxr.linkage_type, ed.db_name, ed.type, ed.db_release, oxr.object_xref_id';
  my $xref_join = <<'SQL';
JOIN xref x USING (xref_id)
JOIN external_db ed on (x.external_db_id = ed.external_db_id)
LEFT JOIN ontology_xref oxr ON (ox.object_xref_id = oxr.object_xref_id)
SQL
  my $where = 'WHERE si.stable_id =?';

  my $translation_sql = <<SQL;
SELECT $columns
FROM translation si
JOIN object_xref ox ON (si.translation_id = ox.ensembl_id AND ox.ensembl_object_type =?)
$xref_join
$where
SQL

  my $transcript_sql = <<SQL;
SELECT $columns
FROM transcript si
JOIN object_xref ox ON (si.transcript_id = ox.ensembl_id AND ox.ensembl_object_type =?)
$xref_join
$where
SQL

  my $gene_sql = <<SQL;
SELECT $columns
FROM gene si
JOIN object_xref ox ON (si.gene_id = ox.ensembl_id AND ox.ensembl_object_type =?)
$xref_join
$where
SQL

  my $sql = {
    ENSEMBLGENE => $gene_sql,
    ENSEMBLTRANS => $transcript_sql,
    ENSEMBLPEP => $translation_sql
  }->{$member->source_name()};
  my $type = {
    ENSEMBLGENE => 'Gene',
    ENSEMBLTRANS => 'Transcript',
    ENSEMBLPEP => 'Translation'
  }->{$member->source_name()};
  my $stable_id = {
    ENSEMBLGENE => $member->stable_id,
    ENSEMBLTRANS => $member->get_canonical_SeqMember->stable_id,
    ENSEMBLPEP  => $member->get_canonical_SeqMember->stable_id,
  }->{$member->source_name()};

  my $params = [$type, $stable_id];
  
  if($db_names) {
    my @conditions;
    foreach my $dbname (@{$db_names}) {      
      push(@conditions, 'ed.db_name like ?');
      push(@{$params}, $dbname);
    }
    my $joined_condition = join(' OR ', @conditions);
    $sql .= " AND ($joined_condition)";
  }

  my $callback = sub {
    my ($row) = @_;
    
    my ($xref_id, $external_db_id, $primary_ac, $display_label, 
        $version, $description, $info_type, $info_text, 
        $linkage, $dbname, $type, $db_release, 
        $ontology_xref_ox_id) = @{$row};
    
    my $hash_to_bless = {
      dbID => $xref_id,
      primary_id => $primary_ac,
      display_id => $display_label,
      version => $version,
      info_type => $info_type,
      info_text => $info_text,
      type => $type,
      dbname => $dbname,
      description => $description,
      release => $db_release
    };
    
    my $xref;
    
    #It was an OntologyXref if we had linked into ontology_xref
    if($ontology_xref_ox_id) {
      #only add linkage types if we had some
      $hash_to_bless->{linkage_types} = [[$linkage]] if $linkage;
      $xref = Bio::EnsEMBL::OntologyXref->new_fast($hash_to_bless);
    } else {
      $xref = Bio::EnsEMBL::DBEntry->new_fast($hash_to_bless);
    }
    return $xref;
  };

  my $entries = $dbc->sql_helper->execute(-SQL => $sql, -CALLBACK => $callback, -PARAMS => $params);
  
  return $class->new(-DBENTRIES => $entries);
}

1;
