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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor

=head1 SYNOPSIS

=head2 Get the adaptor from the Registry

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_db(
      -host => "ensembldb.ensembl.org",
      -user => "anonymous");

  my $dnafrag_region_adaptor = $reg->get_adaptor(
      "Multi", "compara", "DnaFragRegion");


=head2 Storing method

  $dnafrag_region_adaptor->store($dnafrag_region); # Usually called by the Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor->store() method.


=head2 Fetching methods

  $dnafrag_region_adaptor->fetch_all_by_synteny_region_id($sinteny_region->dbID);  # Usually called by the Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor->fetch...() methods.


=head1 DESCRIPTION

A Bio::EnsEMBL::Compara::DBSQL::DnaFragRegion object stores the coordinates of a region that is in synteny with at least another one. These are linked in a Bio::EnsEMBL::Compara::DBSQL::SyntenyRegion object.

Please refer to the Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor for further info on how to fetch synteny blocks

=head1 CONTACT

Ensembl - http://lists.ensembl.org/mailman/listinfo/dev

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);



=head2 fetch_all_by_synteny_region_id

  Arg  1     : int $synteny_region_id
  Example    : my $these_dnafrag_regions = $dnafrag_region_adaptor->
                  fetch_all_by_synteny_region_id($synteny_region_id)
  Description: Fetches the corresponding Bio::EnsEMBL::Compara::DnaFragRegion
               objects.
  Returntype : Listref of Bio::EnsEMBL::Compara::DnaFragRegion objects
  Exception  : Thrown if the argument is not defined
  Caller     : Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor
  Status     : At risk

=cut

sub fetch_all_by_synteny_region_id {
  my ($self, $synteny_region_id) = @_;
  
  if( !defined $synteny_region_id ) {
    throw("fetch_all_by_synteny_region_id with no synteny_region_id!");
  }
#  print "synteny_region_id : $synteny_region_id\n";
  my $sth = $self->prepare('SELECT synteny_region_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand FROM dnafrag_region WHERE synteny_region_id = ?');
  $sth->execute($synteny_region_id);

  
  my ($dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand);
  $sth->bind_columns(\$synteny_region_id, \$dnafrag_id, \$dnafrag_start, \$dnafrag_end, \$dnafrag_strand);
  
  my $dfrs;
  while ($sth->fetch()) {
    my $dfr = Bio::EnsEMBL::Compara::DnaFragRegion->new_fast( {
            'synteny_region_id' => $synteny_region_id,
            'dnafrag_id'        => $dnafrag_id,
            'dnafrag_start'     => $dnafrag_start,
            'dnafrag_end'       => $dnafrag_end,
            'dnafrag_strand'    => $dnafrag_strand,
            'adaptor'           => $self,
        } );
    push @{$dfrs}, $dfr;
  }
  return $dfrs;
}


=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::DnaFragRegion $dnafrag_region
  Example    : $dnafrag_region_adaptor->store($dnafrag_region)
  Description: Stores the corresponding Bio::EnsEMBL::Compara::DnaFragRegion
               in the database.
  Returntype : none
  Exception  : Thrown if the argument is not defined
  Caller     : Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor
  Status     : At risk

=cut


sub store {
   my ($self,$dfr) = @_;

   assert_ref($dfr, 'Bio::EnsEMBL::Compara::DnaFragRegion', 'dfr');

   my $sth = $self->prepare("insert into dnafrag_region (synteny_region_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand) VALUES (?,?,?,?,?)");
   
   $sth->execute($dfr->synteny_region_id, $dfr->dnafrag_id, $dfr->dnafrag_start, $dfr->dnafrag_end, $dfr->dnafrag_strand);
   $dfr->adaptor($self);
}

1;







