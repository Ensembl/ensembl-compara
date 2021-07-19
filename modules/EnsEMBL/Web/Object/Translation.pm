=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::Translation;

### NAME: EnsEMBL::Web::Object::Translation
### Wrapper around a Bio::EnsEMBL::Translation object  

### STATUS: At Risk
### Required functionality now moved to Object::Transcript

### DESCRIPTION

use strict;

use HTML::Entities  qw(encode_entities);

use base qw(EnsEMBL::Web::Object);

sub translation_object { return $_[0]; }
sub translation        { return $_[0]->Obj; }
sub type_name          { return $_[0]->species_defs->translate('Translation'); }
sub source             { return $_[0]->gene ? $_[0]->gene->source : undef;      }
sub gene_description   { return $_[0]->gene ? encode_entities($_[0]->gene->description) : undef; }
sub feature_type       { return $_[0]->Obj->type;       }
sub version            { return $_[0]->Obj->version;    }
sub length             { return $_[0]->Obj->length;    }
sub coord_system       { return $_[0]->transcript->slice->coord_system->name; }
sub seq_region_type    { return $_[0]->coord_system; }
sub seq_region_name    { return $_[0]->transcript->slice->seq_region_name; }
sub seq_region_start   { return $_[0]->transcript->coding_region_start; }
sub seq_region_end     { return $_[0]->transcript->coding_region_end; }
sub seq_region_strand  { return $_[0]->transcript->strand; }

sub logic_name { 
  my $self = shift;
  return $self->gene->analysis ? $self->gene->analysis->logic_name : undef if $self->gene;
  return $self->transcript->analysis ? $self->transcript->analysis->logic_name : undef;
}

=head2 gene

 Arg[1]      : Bio::EnsEMBL::Translation - (OPTIONAL)
 Example     : $ensembl_gene = $pepdata->gene
               $pepdata->gene( $ensembl_gene )
 Description : returns the ensembl gene object if it exists on the
               translation object else it creates it from the
               core-api. Alternativly a ensembl gene object reference
               can be passed to the function if the translation is
               being created via a gene and so saves on creating a new
               gene object.


 Return type : Bio::EnsEMBL::Translation

=cut

sub gene {
  my $self = shift ;
  if(@_) {
    $self->__data->{'_gene'} = shift;
  } elsif( !$self->__data->{'_gene'} ) {
    my $db = $self->get_db() ;
    my $adaptor_call = $self->param('gene_adaptor') || 'get_GeneAdaptor';
    my $GeneAdaptor = $self->database($db)->$adaptor_call;
    my $Gene = $GeneAdaptor->fetch_by_translation_stable_id($self->stable_id);    
    $self->__data->{'_gene'} = $Gene if ($Gene);
  }
  return $self->__data->{'_gene'};
}

=head2 transcript

 Arg[1]         : Bio::EnsEMBL::transcript - (OPTIONAL)
 Example     : $ensembl_transcript = $pepdata->transcript
               $pepdata->transcript( $ensembl_transcript )
 Description : returns the ensembl transcript object if it exists on
               the translation object else it creates it from the
               core-api. Alternativly a ensembl transcript object
               reference can be passed to the function if the
               translation is being created via a transcript and so
               saves on creating a new transcript object.

 Return type : Bio::EnsEMBL::Transcript

=cut

sub transcript {
  my $self = shift;
  if(@_) {
    $self->__data->{'_transcript'} = shift;
  } elsif( !$self->__data->{'_transcript'} ) {
    my $db = $self->get_db() ;
    my $adaptor_call = $self->param('transcript_adaptor') || 'get_TranscriptAdaptor';
    my $transcriptAdaptor = $self->database($db)->$adaptor_call;
    my $transcript = $transcriptAdaptor->fetch_by_translation_stable_id($self->stable_id);    
    $self->__data->{'_transcript'} = $transcript if ($transcript);
  }
  return $self->__data->{'_transcript'} 
}

=head2 db_type

 Arg[1]         : none
 Example     : $type = $pepdata->db_type
 Description : Gets the db type of ensembl feature
 Return type : string
                a db type (EnsEMBL, Vega, EST, etc.)

=cut

sub db_type {
    my $self = shift;
    my $db     = $self->get_db;
    my %db_hash = (  'core'       => 'Ensembl',
                     'est'       => 'EST',
                     'estgene'       => 'EST',
                     'vega'          => 'Vega');
    
    return $db_hash{$db};
}

=head2 gene_type

  Arg [1]   : 
  Function  : Pretty-print type of gene; Ensembl, Vega, Pseudogene etc
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub gene_type {
  my $self = shift;
  my $db = $self->get_db;
  my $type = '';
  if( $db eq 'core' ){
    $type = $self->logic_name;
    $type ||= $self->db_type;
  } else {
    $type = $self->db_type;
    $type ||= $self->logic_name;
  }
  $type ||= $db;
  if( $type !~ /[A-Z]/ ){ $type = ucfirst($type) } #All lc, so format
  return $type;
}

=head2 analysis

  Arg [1]   : 
  Function  : Returns the analysis object from either the gene or transcript
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub analysis {
  my $self = shift;
  if( $self->gene ){ return $self->gene->analysis  } # for "real" gene objects
  else{ return $self->transcript->analysis } # for things like genscans
}

=head2 stable_id

 Arg[1]         : none
 Example     : $stable_id = $pepdata->stable_id
 Description : Wrapper for stable_id on core_API
 Return type : string
                The features stable_id

=cut

sub stable_id {
  my $self = shift;
  return $self->translation ? $self->translation->stable_id : undef;
}

=head2 display_xref

 Arg[1]         : none
 Example     : ($xref_display_id, $xref_dbname) = $pep_data->display_xref
 Description : returns a pair value of xref display_id and xref dbname  (BRCA1, HUGO)
 Return type : a list

=cut

sub display_xref {
    my $self = shift;
    my $trans_xref = $self->transcript->display_xref;
    return ($trans_xref->display_id, $trans_xref->dbname, $trans_xref->primary_id, $trans_xref->db_display_name ) if $trans_xref;
}

=head2 get_protein_domains

 Arg[1]           : none
 Example     : $protein_domains = $pepdata->get_protein_domains
 Description : Returns all protein domains
 Return type : hashref for protein domains

=cut

sub get_protein_domains {
    my $self = shift;
    my $translation = $self->translation;
    $translation->dbID || return []; # E.g. PredictionTranscript
    return ( $translation->get_all_DomainFeatures);
}

=head2 get_all_ProteinFeatures

 Arg[1]           : type of feature :string
 Example     : $transmem_domains = $pepdata->get_all_ProteinFeatures
 Description : Returns features for a translation object
 Return type : array of ftranslation features

=cut

sub get_all_ProteinFeatures {
    my $self = shift;
    my $translation = $self->translation;
    $translation->dbID || return []; # E.g. PredictionTranscript
    return ( $translation->get_all_ProteinFeatures(shift));
}

sub get_Slice {
  my( $self, $context, $ori ) = @_;

  my $db  = $self->get_db ;
  my $gene = $self->gene;
  my $slice = $gene->feature_Slice;
  if( $context && $context =~ /(\d+)%/ ) {
    $context = $slice->length * $1 / 100;
  }
  if( $ori && $slice->strand != $ori ) {
    $slice = $slice->invert();
  }
  return $slice->expand( $context, $context );
}

=head2 get_similarity_hash

 Arg[1]      : none
 Example     : @similarity_matches = $pepdata->get_similarity_hash
 Description : Returns an arrayref of hashes containing similarity matches
 Return type : an array ref

=cut

sub get_similarity_hash {
  my $self = shift;
  my $transl = $self->translation;
  my @DBLINKS;
  eval { @DBLINKS = @{$transl->get_all_DBEntries};};   
  warn ("SIMILARITY_MATCHES Error on retrieving translation DB links $@") if ($@);    
  return \@DBLINKS  || [];
}

#######################################################################
## ID history view stuff............................................ ##
#######################################################################

sub get_archive_object {
  my $self = shift;
  my $id = $self->stable_id;
  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  my $archive_object = $archive_adaptor->fetch_by_stable_id($id, 'Translation');

 return $archive_object;
}

=head2 history

 Arg1        : data object
 Description : gets the archive id history tree based around this ID
 Return type : listref of Bio::EnsEMBL::ArchiveStableId
               As every ArchiveStableId knows about it's successors, this is
                a linked tree.

=cut

sub history {
  my $self = shift;

  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  return unless $archive_adaptor;

  my $history = $archive_adaptor->fetch_history_tree_by_stable_id($self->stable_id);
  return $history;
}

=head2 vega_projection

 Arg[1]         : Alternative assembly name
 Example     : my $v_slices = $object->ensembl_projection($alt_assembly)
 Description : map an object to an alternative (vega) assembly
 Return type : arrayref

=cut

sub vega_projection {
    my $self = shift;
    my $alt_assembly = shift;
    my $slice = $self->database('vega')->get_SliceAdaptor->fetch_by_region( undef,
       $self->seq_region_name, $self->seq_region_start, $self->seq_region_end );
    my $alt_projection = $slice->project('chromosome', $alt_assembly);
    my @alt_slices = ();
    foreach my $seg (@{ $alt_projection }) {
        my $alt_slice = $seg->to_Slice;
        push @alt_slices, $alt_slice;
    }
    return \@alt_slices;
}

1;
