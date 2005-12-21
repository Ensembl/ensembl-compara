package EnsEMBL::Web::Object::Chromosome;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(EnsEMBL::Web::Object);

use EnsEMBL::Web::DataUpload;
use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;
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
    return $self->{'_local_genes'} if $self->{'_local_genes'};
    
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
        $slice = $sliceAdaptor->fetch_by_region
      ('chromosome', $chr, 1, $start );
        @localgenes = @{$slice->get_all_Genes( 'ensembl' )};
        if(@localgenes>-$num) {
            @localgenes = @localgenes[$num..-1]; 
            $start = 1;
        } elsif(@localgenes==0) {
             $slice = $sliceAdaptor->fetch_by_region
           ('chromosome',$chr, $start ,$chr_length);
            @localgenes = @{$slice->get_all_Genes( 'ensembl' )};
            @localgenes = @localgenes[0..(-$num-1)] if(@localgenes>-$num);
        } else { 
            $start = 1;
        }
    } else {
    $slice = $sliceAdaptor->fetch_by_region
      ( 'chromosome', $chr, $start, $chr_length );
         @localgenes = @{$slice->get_all_Genes( 'ensembl' )};
        if(@localgenes>$num) {
            @localgenes = @localgenes[0..($num-1)]; 
        } elsif(@localgenes==0) {
      $slice = $sliceAdaptor->fetch_by_region
        ('chromosome', $chr, 1 , $start);
      @localgenes = @{$slice->get_all_Genes( 'ensembl' )};
      @localgenes = @localgenes[(-$num)..-1] if(@localgenes>$num);
      $start = 1;
        }
    }
    foreach my $gene( @localgenes ){ 
      $gene->start( $gene->start + $start - 1 ); 
      $gene->end( $gene->end + $start - 1 ); 
    }
    $self->{'_local_genes'} = \@localgenes;
    return \@localgenes;
}


sub get_synteny_matches {
 
    my $self = shift;

    my @data;
    my $OTHER = $self->param('otherspecies') ||$self->param('species')|| ($ENV{ 'ENSEMBL_SPECIES' } eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens');
    my $gene2_adaptor = $self->database('core', $OTHER)->get_GeneAdaptor();
    my @localgenes = @{$self->get_synteny_local_genes};
    foreach my $localgene (@localgenes){
        my ($sppgene, $separate, $syntenygene);
        my $data;
        my $spp = $ENV{ 'ENSEMBL_SPECIES'};
        my $homol_id = "";
        my $homologues = $self->fetch_homologues_of_gene_in_species($localgene->stable_id, $OTHER);
        my $homol_num = scalar @{$homologues};
        my $gene_synonym = $localgene->external_name || $localgene->stable_id;
   
        foreach my $homol(@{$homologues}){
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
                'sp_length'         =>  $self->bp_to_nearest_unit($localgene->start()),
                'other_stable_id'   =>  $homol->stable_id,
                'other_synonym'     =>  $homol_id,
                'other_chr'         =>  $H_CHR,
                'other_length'      =>  $self->bp_to_nearest_unit($H_START),
                'homologue_no'      =>  $homol_num
                };
 
            push @data, $data_row;
        }
    }
    return \@data;

}

sub get_synteny_nav {
 
    my $object = shift;

    my @data;

    my @localgenes = @{$object->get_synteny_local_genes};
    my $first_start = @localgenes ? $localgenes[0]->start : 0;
    my $last_end    = @localgenes ? $localgenes[-1]->end  : 0;
    my $up_length   = $object->bp_to_nearest_unit($first_start);
    my $down_length = $object->bp_to_nearest_unit($last_end);

    push (@data, $first_start, $last_end, $up_length, $down_length);

    return \@data;

}

#----------------------

=head2 parse_user_data

 Arg[1]		 : $parser - a Data::Bio::Text parser object
 Example     : 
 Description : Parses user input and stores each feature as an object 
 Return type : None

=cut
  
sub parse_user_data {

    my ($self, $parser, $track_id) = @_;

    if (my $data = $self->param("upload_file_$track_id")) {
        warn "Trying to upload file ".$self->param("upload_file_$track_id");
        # parse data, not file name!
        my $du = EnsEMBL::Web::DataUpload->new();
        if (defined(my $error = $du->upload_data("upload_file_$track_id"))) {
            $self->problem('fatal', "Sorry, unable to upload your file at this time. Please try again later.");
            #$self->Output->error_page($self->problem->[0]);
            #$self->Output->ensembl_exit;
        }
        my $file_data = $du->data;
        $parser->parse($file_data);
    }
    elsif ($data = $self->param("url_file_$track_id")) {
        $parser->parse_URL($data);
    }
    else {
        $parser->parse($self->param("paste_file_$track_id"));
    }

}
  

1;
