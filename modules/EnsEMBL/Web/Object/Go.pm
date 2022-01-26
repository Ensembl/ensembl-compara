=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::Go;

### NAME: EnsEMBL::Web::Object::Go

### DESCRIPTION                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use base qw(EnsEMBL::Web::Object);

sub acc_id  { return $_[0]->Obj->{'acc_id'} if $_[0]->Obj->{'acc_id'}; }

sub name  {
  my $self = shift;
  if( @{$self->Obj->{'terms'}||[]} ) {
    return $self->Obj->{'terms'}->[0]->name;
  }
}

sub families { return $_[0]->Obj->{'families'} if $_[0]->Obj->{'families'};}

sub count_genes {
  my( $self, $id ) = @_;
  return scalar $self->db_entry_adaptor->list_gene_ids_by_extids($id);
}

sub load_genes {
  my( $self, $id ) = @_;
  my $acc_id = $self->acc_id;
  unless( $self->Obj->{'families'}{$acc_id} ) { 
    my $ga  = $self->gene_adaptor;
    my $fa  = $self->family_adaptor;
    my $array_ref = [];
    my @genes = $self->db_entry_adaptor->list_gene_ids_by_extids($acc_id);
    foreach my $gene (@genes) {
      my $subarray_ref = [];
      my $gene_obj = $ga->fetch_by_dbID($gene);
      push (@$subarray_ref, $gene_obj);
      if($self->param('display')) {
        my $fam_obj = $fa->fetch_all_by_Gene($gene_obj);
        if( @$fam_obj ) {
          push (@$subarray_ref, $fam_obj->[0]);
        } else {
          warn "NO FAMILY OBJ ", $gene_obj->stable_id ;
        }
      }
      push (@$array_ref, $subarray_ref);
    }
    $self->Obj->{'families'}{$acc_id} = $array_ref;
  } 
  return $self->Obj->{'families'}{$acc_id};
}

sub db_entry_adaptor { return $_[0]->Obj->{_db_entry_adaptor} ||= $_[0]->database('core')->get_DBEntryAdaptor(); }
sub gene_adaptor     { return $_[0]->Obj->{_gene_adaptor}     ||= $_[0]->database('core')->get_GeneAdaptor(); }
sub family_adaptor   { return $_[0]->Obj->{_family_adaptor}   ||= $_[0]->database('compara')->get_FamilyAdaptor(); }
sub iterator { 
  my $graph = $_[0]->Obj->{'graph'};
  return undef unless $graph;
  my $iterator = $graph->create_iterator();
  return $iterator;
}

sub retrieve_features {
  my $acc_id = $_[0]->Obj->{'acc_id'};
  my $array_ref = $_[0]->Obj->{'families'}{$acc_id};
  my $results = [];
  
  foreach my $subarray_ref (@$array_ref) {
    my @subarray = @$subarray_ref;
    my $gene = $subarray[0];
    push @$results, {
      'region'   => $gene->seq_region_name,
      'start'    => $gene->start,
      'end'      => $gene->end,
      'strand'   => $gene->strand,
      'length'   => $gene->end-$gene->start+1,
      'extname'  => $gene->external_name, 
      'label'    => $gene->stable_id,
      'extra'    => [ $gene->description ]
    }
  }
  
  return ( $results, ['Description'] );
}

sub get_geneinfo {
  my $acc_id = $_[0]->Obj->{'acc_id'};
  my $array_ref = $_[0]->Obj->{'families'}{$acc_id};
  my $results = [];
  
  my $go_map = $_[0]->database('core')->dbc->db_handle->selectall_arrayref(
    'select distinct t.gene_id, gx.linkage_type
  from transcript as t, translation as tr,
       object_xref as ox, go_xref as gx,
       xref as x, external_db as ed
 where ed.db_name="GO" and ed.external_db_id=x.external_db_id and
       x.dbprimary_acc = ? and x.xref_id = ox.xref_id and
       ox.ensembl_id = tr.translation_id and tr.transcript_id = t.transcript_id and
       ox.object_xref_id = gx.object_xref_id', {}, $acc_id
  );
  my %go_evidence;
  foreach( @$go_map ) { push @{$go_evidence{$_->[0]}},$_->[1]; }
  foreach my $subarray_ref (@$array_ref) {
    my @subarray = @$subarray_ref;
    my $gene = $subarray[0];
    my $ev = $go_evidence{ $gene->dbID } ? join( ', ', @{$go_evidence{ $gene->dbID }}) : '???';
    push @$results, {
        'stable_id'     => $gene->stable_id,
        'evidence'      => $ev,
        'description'   => $gene->description
    }
  }
  return $results;
} 

sub get_faminfo {
  my $acc_id = $_[0]->Obj->{'acc_id'};
  my $array_ref = $_[0]->Obj->{'families'}{$acc_id};
  my $results = [];
  
  foreach my $subarray_ref (@$array_ref) {
    my @subarray = @$subarray_ref;
    my $family = $subarray[1];
    push @$results, $family ? {
      'stable_id'     => $family->stable_id,
      'description'   => $family->description
    } : {};
  }
  return $results;
}

1;
