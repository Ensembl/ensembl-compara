package EnsEMBL::Web::Object::Chromosome;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(EnsEMBL::Web::Object);

use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;
use EnsEMBL::Web::File::Text;
use Data::Bio::Text::DensityFeatureParser;
use Digest::MD5 ;

#----------------------------------------------------------------------------
# GET FUNCTIONS FOR CHROMOSOME DATA
#----------------------------------------------------------------------------

=head2 is_golden_path 

 Example     : 
 Description : Gets assembly status, i.e. complete chromosomes or not 
 Return type : Boolean

=cut

sub is_golden_path {
  my $self = shift;
  @{ $self->species_defs->ENSEMBL_CHROMOSOMES || [] } ? 1 : 0;
}

#----------------------

=head2 max_chr_length

 Example     : 
 Description : Gets length of longest chromosome in this species 
 Return type : Integer

=cut

sub max_chr_length {
  my $self = shift;
  return $self->species_defs->MAX_CHR_LENGTH;
}

#----------------------

=head2 length

 Example     : 
 Description : Gets length of a given chromosome 
 Return type : Integer

=cut

sub length {
  my $self = shift;
  return $self->Obj->length;
}

#----------------------

=head2 chr_name
 
 Example     : 
 Description : 
 Return type : String 

=cut

sub chr_name {
  my $self = shift;
  return $self->Obj ? $self->Obj->seq_region_name : 'ALL';
}

sub seq_region_name { return $_[0]->Obj ? $_[0]->Obj->seq_region_name : 'ALL'; }
sub seq_region_type { return $_[0]->Obj ? $_[0]->Obj->coord_system->name : ''; }

#----------------------

=head2 all_chromosomes  

 Example     : 
 Description : Gets the names of all chromosomes for this species 
 Return type : Array

=cut

sub all_chromosomes{
  my $self = shift ;
  return $self->species_defs->ENSEMBL_CHROMOSOMES;
}

#----------------------------------------------------------------------------
# WRAPPER FUNCTIONS FOR DATA RETRIEVAL
#----------------------------------------------------------------------------

=head2 get_adaptor  

 Arg[1]      : String $method - name of the adaptor get method
 Example     : my $sa = $self->get_adaptor('get_SliceAdaptor');
 Description : Wrapper to get an adaptor object and throw a fatal error 
                if the database connection fails
 Return type : Adaptor object of type requested

=cut

sub get_adaptor {
  my ($self, $method, $db, $species) = @_;
  $db = 'core' if !$db;
  $species = $self->species if !$species;
  my $adaptor;
  eval { $adaptor =  $self->database($db, $species)->$method(); };
    
  if( $@ ) {
    warn ($@);
    $self->problem('fatal', "Sorry, can't retrieve required information.",$@);
  }
  return $adaptor;
}


#----------------------

sub get_synteny_local_genes {
    
    my $self = shift ;
    return @{$self->{'_local_genes'}} if $self->{'_local_genes'};

    my $slice;
    my @localgenes;
    my $pre = $self->param('pre');
    my $loc = $self->param('loc') ? $self->evaluate_bp($self->param('loc')) : undef ;
    my $chr = $self->chr_name;
    my $chr_length = $self->length;
    my $sliceAdaptor = $self->get_adaptor('get_SliceAdaptor');
    my $num = 15; # minus count means count backwards - get previous genes
    $num = -$num if $pre;
    my $start = $loc < 1 ? 1 : $loc;
    $start = $chr_length if $start > $chr_length;
   
    if( $num < 0 ) {
        $slice = $sliceAdaptor->fetch_by_region('chromosome', $chr, 1, $start );
        @localgenes = _local_genes($slice);
        if(@localgenes>-$num) {
            @localgenes = @localgenes[$num..-1]; 
            $start = 1;
        } elsif(@localgenes==0) {
             $slice = $sliceAdaptor->fetch_by_region
           ('chromosome',$chr, $start ,$chr_length);
            @localgenes = _local_genes($slice);
            @localgenes = @localgenes[0..(-$num-1)] if(@localgenes>-$num);
        } else { 
            $start = 1;
        }
    } 
    else {
      $slice = $sliceAdaptor->fetch_by_region( 'chromosome', $chr, $start, $chr_length );
      @localgenes = _local_genes($slice);
      if(@localgenes>$num) {
        @localgenes = @localgenes[0..($num-1)]; 
      } 
      elsif(@localgenes==0) {
        $slice = $sliceAdaptor->fetch_by_region('chromosome', $chr, 1 , $start);
        @localgenes = _local_genes($slice);
        @localgenes = @localgenes[(-$num)..-1] if(@localgenes>$num);
        $start = 1;
      }
    }
#    foreach my $gene( @localgenes ){ 
#      $gene->start( $gene->start + $start - 1 ); 
#      $gene->end( $gene->end + $start - 1 ); 
#    }
    $self->{'_local_genes'} = [\@localgenes,$start-1];
    return \@localgenes, $start - 1;
}

sub _local_genes {
## Ensures that only protein coding genes are included in syntenyview
  my $slice = shift;
  my @local_genes;
  my @biotypes = ('protein_coding', 'V_segments', 'C_segments');
  foreach my $type (@biotypes) {
    push @local_genes, @{$slice->get_all_Genes_by_type($type)};
  }
  return @local_genes;
}

sub get_synteny_matches {
 
    my $self = shift;

    my @data;
    my $OTHER = $self->param('otherspecies') ||$self->param('species')|| ($ENV{ 'ENSEMBL_SPECIES' } eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens');
    my $gene2_adaptor = $self->database('core', $OTHER)->get_GeneAdaptor();
    my ($localgenes,$offset ) = $self->get_synteny_local_genes;
    
    foreach my $localgene (@$localgenes){
        my ($sppgene, $separate, $syntenygene);
        my $data;
        my $spp = $ENV{ 'ENSEMBL_SPECIES'};
        my $homol_id = "";
        my $homologues = $self->fetch_homologues_of_gene_in_species($localgene->stable_id, $OTHER);
        my $homol_num = scalar @{$homologues};
        my $gene_synonym = $localgene->external_name || $localgene->stable_id;
   
        #warn $localgene->stable_id;
        if(@{$homologues}) {
        foreach my $homol(@{$homologues}){
            #warn "....    ", $homol->stable_id;
            my $gene = $gene2_adaptor->fetch_by_stable_id( $homol->stable_id,1 );
            $homol_id = $gene->external_name;
            $homol_id ||= $gene->stable_id;
            my $gene_slice = $gene->slice;
            my $H_START = $gene->start;
            my $H_CHR;
            if( $gene_slice->coord_system->name eq "chromosome" ) {
                $H_CHR = $gene_slice->seq_region_name;
            }
            else {
                my $coords =$gene_slice->project("chromosome");
                if( @$coords ) {
                    $H_CHR = $coords->[0]->[2]->seq_region_name();
                }
            }
            my $data_row = {
                'sp_stable_id'      =>  $localgene->stable_id,
                'sp_synonym'        =>  $gene_synonym,
                'sp_length'         =>  $self->bp_to_nearest_unit($localgene->start()+$offset),
                'other_stable_id'   =>  $homol->stable_id,
                'other_synonym'     =>  $homol_id,
                'other_chr'         =>  $H_CHR,
                'other_length'      =>  $self->bp_to_nearest_unit($H_START),
                'homologue_no'      =>  $homol_num
                };
 
            push @data, $data_row;
        }
        } else {
          push @data, { 'sp_stable_id'      =>  $localgene->stable_id,
                'sp_synonym'        =>  $gene_synonym,
                'sp_length'         =>  $self->bp_to_nearest_unit($localgene->start()+$offset) }
        }
    }
    return \@data;

}

sub get_synteny_nav {
 
    my $object = shift;

    my @data;

    my ($localgenes,$offset) = $object->get_synteny_local_genes;
    my $first_start = @$localgenes ? $localgenes->[0]->start +$offset: 0;
    my $last_end    = @$localgenes ? $localgenes->[-1]->end  +$offset: 0;
    my $up_length   = $object->bp_to_nearest_unit($first_start);
    my $down_length = $object->bp_to_nearest_unit($last_end);

    push (@data, $first_start, $last_end, $up_length, $down_length);

    return \@data;

}

#----------------------

=head2 parse_user_data

 Arg[1]     : $parser - a Data::Bio::Text parser object
 Example     : 
 Description : Parses user input and stores each feature as an object 
 Return type : None

=cut
  
sub parse_user_data {
  my ($self, $parser, $track_id) = @_;
  my $data;
  if (my $data_file = $self->param("cache_file_$track_id")) {
    my $cache = new EnsEMBL::Web::File::Text($self->{'_species_defs'}); 
    $data = $cache->retrieve($data_file);
    $parser->parse($data);
  }
  elsif ($data = $self->param("url_file_$track_id")) {
    $parser->parse_URL($data);
  }
  else {
    $parser->parse($self->param("paste_file_$track_id"));
  }
}


=head2 find_available_anchor_points

 Arg[1]     : EnsEMBL::Web::Object::Chromosome
 Example     : my @types = @{$object->find_available_anchor_points};
 Description : Looks in species_defs for available anchor points, ie non-emprty tables
 Return type : Arrayref

=cut

sub find_available_anchor_points {
  my $self=shift;
  my $species      = $self->species;
  my $species_defs = $self->species_defs;
  #define possible anchor here - where 'table' value is undef then option added by default
  my $all_anchor_points = [
    {'table'=>'' ,              'value'=>'bp',     'name'=>'Base pair'},
    {'table'=>'karyotype',      'value'=>'band',   'name'=>'Band'},
    {'table'=>'marker_feature', 'value'=>'marker', 'name'=>'Marker'},
    {'table'=>'misc_feature',   'value'=>'misc_feature', 'name'=>'Clone'},
    {'table'=>'gene' ,          'value'=>'gene',   'name'=>'Gene'},
    {'table'=>'translation' ,   'value'=>'peptide','name'=>'Peptide'},  
  ];

  my $avail_anchor_points = [];
  foreach my $poss_anchor (@$all_anchor_points) {
    if ($poss_anchor->{'table'}) {
      if ($species_defs->get_table_size( {-db=>'DATABASE_CORE',-table => $poss_anchor->{'table'}},$species )) {
        push @$avail_anchor_points, {'value'=>$poss_anchor->{'value'}, 'name'=>$poss_anchor->{'name'} };
      }
    }
    else {
      push @$avail_anchor_points, {'value'=>$poss_anchor->{'value'}, 'name'=>$poss_anchor->{'name'} };
    }
  }
  return $avail_anchor_points;
}

1;
