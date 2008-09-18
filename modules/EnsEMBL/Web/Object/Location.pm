package EnsEMBL::Web::Object::Location;

use strict;
use warnings;
no warnings "uninitialized";
use Data::Dumper;
use POSIX qw(floor ceil);
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Object);

our $memd = new EnsEMBL::Web::Cache;

sub counts {
  my $self = shift;
  my $obj = $self->Obj;

  my $key = '::COUNTS::'. join '::', values %{ $self->core_objects->{parameters} };
  my $counts;

  $counts = $memd->get($key) if $memd;

  unless ($counts) {
    $counts = {};
    my %synteny_hash = $self->species_defs->multi('SYNTENY');
    $counts->{'synteny'} = keys %synteny_hash; 

  }
  return $counts;
}

sub short_caption {
  my $self = shift;
  return 'Location-based displays';
  return $self->seq_region_name.': '.$self->thousandify($self->seq_region_start).'-'.
    $self->thousandify($self->seq_region_end);

}

sub caption {
  my $self = shift;
  return 'Location: '.$self->neat_sr_name($self->seq_region_type,$self->seq_region_name).': '.$self->thousandify($self->seq_region_start).'-'.
                                     $self->thousandify($self->seq_region_end);
}
sub centrepoint      { return ( $_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_start'} ) / 2; }
sub length           { return   $_[0]->Obj->{'seq_region_end'} - $_[0]->Obj->{'seq_region_start'} + 1; }

sub slice            {
  my $self = shift;
  return $self->Obj->{'slice'} ||= $self->database('core',$self->real_species)->get_SliceAdaptor->fetch_by_region(
    $self->seq_region_type, $self->seq_region_name, $self->seq_region_start, $self->seq_region_end, $self->seq_region_strand );
}

sub chromosome {
  my ($self, $species) = @_;
  my $sliceAdaptor = $self->get_adaptor('get_SliceAdaptor');
  return $sliceAdaptor->fetch_by_region( undef, $self->seq_region_name);
}

sub get_snp { return $_[0]->__data->{'snp'}[0] if $_[0]->__data->{'snp'}; }

sub attach_slice       { $_[0]->Obj->{'slice'} = $_[1];              }
sub real_species       :lvalue { $_[0]->Obj->{'real_species'};       }
sub raw_feature_strand :lvalue { $_[0]->Obj->{'raw_feature_strand'}; }
sub strand             :lvalue { $_[0]->Obj->{'strand'};             }
sub name               :lvalue { $_[0]->Obj->{'name'};               }
sub sub_type           :lvalue { $_[0]->Obj->{'type'};               }
sub synonym            :lvalue { $_[0]->Obj->{'synonym'};            }
sub seq_region_name    :lvalue { $_[0]->Obj->{'seq_region_name'};    }
sub seq_region_start   :lvalue { $_[0]->Obj->{'seq_region_start'};   }
sub seq_region_end     :lvalue { $_[0]->Obj->{'seq_region_end'};     }
sub seq_region_strand  :lvalue { $_[0]->Obj->{'seq_region_strand'};  }
sub seq_region_type    :lvalue { $_[0]->Obj->{'seq_region_type'};    }
sub seq_region_length  :lvalue { $_[0]->Obj->{'seq_region_length'};  }

sub align_species {
    my $self = shift;
    if (my $add_species = shift) {
	$self->Obj->{'align_species'} = $add_species;
    }
    return $self->Obj->{'align_species'};
}


sub coord_systems {
  ## Needed by Location/Karyotype to display DnaAlignFeatures
  my $self = shift;
  my ($exemplar) = keys(%{$self->Obj});
#warn $self->Obj->{$exemplar}->[0];
  return [ map { $_->name } @{ $self->database('core',$self->real_species)->get_CoordSystemAdaptor()->fetch_all() } ];
}

 
sub misc_set_code { 
  my $self = shift;
  if( @_ ) { 
    $self->Obj->{'misc_set_code'} = shift;
  }
  return $self->Obj->{'misc_set_code'};
}

sub setCentrePoint {
  my $self        = shift;
  my $centrepoint = shift;
  my $length      = shift || $self->length;
  $self->seq_region_start = $centrepoint - ($length-1)/2;
  $self->seq_region_end   = $centrepoint + ($length+1)/2;
}

sub setLength {
  my $self        = shift;
  my $length      = shift;
  $self->seq_region_start = $self->centrepoint - ($length-1)/2;
  $self->seq_region_end   = $self->seq_region_start + ($length-1)/2;
}

sub addContext {
  my $self = shift;
  my $context = shift;
  $self->seq_region_start -= int($context);
  $self->seq_region_end   += int($context);
}


######## FeatureView calls ##########################################

sub retrieve_features {
  my ($self, $features) = @_;
  my $method;
  my $results = [];
 
  while (my ($type, $data) = each (%$features)) {
    $method = 'retrieve_'.$type;
    push @$results, [$self->$method($data)] if defined &$method;
  }
  return $results;
}

sub retrieve_Gene {
  my ($self, $data) = @_;

  my $results = [];
  foreach my $g (@$data) {
    if (ref($g) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($g);
      push(@$results, $unmapped);
    }
    else {
      push @$results, {
        'region'   => $g->seq_region_name,
        'start'    => $g->start,
        'end'      => $g->end,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extname'  => $g->external_name,
        'label'    => $g->stable_id,
        'gene_id'  => [ $g->stable_id ],
        'extra'    => [ $g->description ]
      }
    }
  }

  return ( $results, ['Description'] );
}

sub retrieve_Xref {
  my ($self, $data) = @_;

  my $results = [];
  foreach my $array (@$data) {
    my $xref = shift @$array;
    push @$results, {
      'label'     => $xref->primary_id,
      'xref_id'   => [ $xref->primary_id ],
      'extname'   => $xref->display_id,
      'extra'     => [ $xref->description, $xref->dbname ]
    };
    ## also get genes
    foreach my $g (@$array) {
      push @$results, {
        'region'   => $g->seq_region_name,
        'start'    => $g->start,
        'end'      => $g->end,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extname'  => $g->external_name,
        'label'    => $g->stable_id,
        'gene_id'  => [ $g->stable_id ],
        'extra'    => [ $g->description ]
      }
    }
  }

  return ( $results, ['Description'] );
}

sub retrieve_OligoProbe {
  my ($self, $data) = @_;

  my $results = [];
  foreach my $probe (@$data) {
    if (ref($probe) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($probe);
      push(@$results, $unmapped);
    }
    else {
      my $names = join ' ', map { /^(.*):(.*):\2/? "$1:$2" : $_ } sort @{$probe->get_all_complete_names()};
      foreach my $f (@{$probe->get_all_OligoFeatures()}) {
        push @$results, {
          'region'   => $f->seq_region_name,
          'start'    => $f->start,
          'end'      => $f->end,
          'strand'   => $f->strand,
          'length'   => $f->end-$f->start+1,
          'label'    => $names,
          'gene_id'  => [$names],
          'extra'    => [ $f->mismatchcount ]
        }
      }
    }
  }
  return ( $results, ['Mismatches'] );
}

sub retrieve_DnaAlignFeature {
  my ($self, $data) = @_;
  my $results = [];

  foreach my $f ( @$data ) {
    if (ref($f) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($f);
      push(@$results, $unmapped);
    }
    else {
#     next unless ($f->score > 80);
      my $coord_systems = $self->coord_systems();
      my( $region, $start, $end, $strand ) = ( $f->seq_region_name, $f->start, $f->end, $f->strand );
      if( $f->coord_system_name ne $coord_systems->[0] ) {
        foreach my $system ( @{$coord_systems} ) {
          # warn "Projecting feature to $system";
          my $slice = $f->project( $system );
          # warn @$slice;
          if( @$slice == 1 ) {
            ($region,$start,$end,$strand) = ($slice->[0][2]->seq_region_name, $slice->[0][2]->start, $slice->[0][2]->end, $slice->[0][2]->strand );
            last;
          }
        }
      }
      push @$results, {
        'region'   => $region,
        'start'    => $start,
        'end'      => $end,
        'strand'   => $strand,
        'length'   => $f->end-$f->start+1,
        'label'    => $f->display_id." (@{[$f->hstart]}-@{[$f->hend]})",
        'gene_id'  => ["@{[$f->hstart]}-@{[$f->hend]}"],
        'extra' => [ $f->alignment_length, $f->hstrand * $f->strand, $f->percent_id, $f->score, $f->p_value ]
      };
    }
  }
  my $feature_mapped = 1; ## TODO - replace with $self->feature_mapped call once unmapped feature display is added
  if ($feature_mapped) {
    return $results, [ 'Alignment length', 'Rel ori', '%id', 'score', 'p-value' ];
  }
  else {
    return $results;
  }
}

sub retrieve_ProteinAlignFeature {
  my ($self, $data) = @_;
  return $self->retrieve_DnaAlignFeature($data);
}

sub retrieve_RegulatoryFactor {
  my ($self, $data) = @_;
  my $results = [];
  my $flag = 0;

  foreach my $reg (@$data) {
    my @stable_ids;
    my $gene_links;
    my $db_ent = $reg->get_all_DBEntries;
    foreach ( @{ $db_ent} ) {
      push @stable_ids, $_->primary_id;
      $gene_links .= qq(<a href="geneview?gene=$stable_ids[-1]">$stable_ids[-1]</a>);
    #  $flag = 1;
    }

    my @extra_results = $reg->analysis->description;
    $extra_results[0] =~ s/(https?:\/\/\S+[\w\/])/<a rel="external" href="$1">$1<\/a>/ig;

  unshift (@extra_results, $gene_links);# if $gene_links;

    push @$results, {
      'region'   => $reg->seq_region_name,
      'start'    => $reg->start,
      'end'      => $reg->end,
      'strand'   => $reg->strand,
      'length'   => $reg->end-$reg->start+1,
      'label'    => $reg->display_label,
      'gene_id'  => \@stable_ids,
      'extra'    => \@extra_results,
    }
  }
  my $extras = ["Feature analysis"];
  unshift @$extras, "Associated gene";# if $flag;

  return ( $results, $extras );
}

sub unmapped_object {
  my ($self, $unmapped) = @_;
  my $analysis = $unmapped->analysis;

  my $result = {
    'label'     => $unmapped->{'_id_'},
    'reason'    => $unmapped->description,
    'object'    => $unmapped->ensembl_object_type,
    'score'     => $unmapped->target_score,
    'analysis'  => $$analysis{'_description'},
  };

  return $result;
}


######## SYNTENYVIEW CALLS ################################################

sub get_synteny_matches {
  my $self = shift;

  my @data;
  my $OTHER = $self->param('otherspecies') || $self->param('species')
        || ($ENV{ 'ENSEMBL_SPECIES' } eq 'Homo_sapiens' ? 'Mus_musculus' : 'Homo_sapiens');
  my $gene2_adaptor = $self->database('core', $OTHER)->get_GeneAdaptor();
  my $localgenes = $self->get_synteny_local_genes;
  my $offset = $self->seq_region_start;

  foreach my $localgene (@$localgenes){
    my ($sppgene, $separate, $syntenygene);
    my $data;
    my $spp = $ENV{ 'ENSEMBL_SPECIES'};
    my $homol_id = "";
    my $homologues = $self->fetch_homologues_of_gene_in_species($localgene->stable_id, $OTHER);
    my $homol_num = scalar @{$homologues};
    my $gene_synonym = $localgene->external_name || $localgene->stable_id;

    if(@{$homologues}) {
      foreach my $homol(@{$homologues}) {
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
    } 
    else {
      push @data, { 
            'sp_stable_id'      =>  $localgene->stable_id,
            'sp_synonym'        =>  $gene_synonym,
            'sp_length'         =>  $self->bp_to_nearest_unit($localgene->start()+$offset) 
      };
    }
  }
    return \@data;
}

sub get_synteny_local_genes {
  my $self = shift ;

  my $slice = shift || $self->core_objects->location;
  my $localgenes = [];

  ## Ensures that only protein coding genes are included in syntenyview
  my @biotypes = ('protein_coding', 'V_segments', 'C_segments');
  foreach my $type (@biotypes) {
    my $genes = $slice->get_all_Genes_by_type($type);
    push @$localgenes, @$genes if scalar(@$genes);
  }

  my @sorted = sort {$a->start <=> $b->start} @$localgenes;
  return \@sorted;
}

######## LDVIEW CALLS ################################################


sub get_default_pop_name {

  ### Example : my $pop_id = $self->DataObj->get_default_pop_name
  ### Description : returns population id for default population for this species
  ### Returns population dbID

  my $self = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pop_adaptor = $variation_db->get_PopulationAdaptor;
  my $pop = $pop_adaptor->fetch_default_LDPopulation(); 
  return unless $pop;
  return $pop->name;
}

sub pop_obj_from_name {

  ### Arg1    : Population name
  ### Example : my $pop_name = $self->DataObj->pop_obj_from_name($pop_id);
  ### Description : returns population info for the given population name
  ### Returns population object

  my $self = shift;
  my $pop_name = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_name($pop_name);
  return {} unless $pop;
  my $data = $self->format_pop( [$pop] );
  return $data;
}


sub pop_name_from_id {

  ### Arg1 : Population id
  ### Example : my $pop_name = $self->DataObj->pop_name_from_id($pop_id);
  ### Description : returns population name as string
  ### Returns string

  my $self = shift;
  my $pop_id = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_dbID($pop_id);
  return {} unless $pop;
  return $self->pop_name( $pop );
}


sub extra_pop {  ### ALSO IN SNP DATA OBJ

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Arg[2]      : string "super", "sub"
  ### Example : $genotype_freq = $self->DataObj->extra_pop($pop, "super");
  ### Description : gets any super/sub populations
  ### Returns String

  my ($self, $pop_obj, $type)  = @_;
  return {} unless $pop_obj;
  my $call = "get_all_$type" . "_Populations";
  my @populations = @{ $pop_obj->$call};
  return  $self->format_pop(\@populations);
}


sub format_pop {

  ### Arg1 : population object
  ### Example : my $data = $self->format_pop
  ### Description : returns population info for the given population obj
  ### Returns hashref

  my $self = shift;
  my $pops = shift;
  my %data;
  foreach (@$pops) {
    my $name = $self->pop_name($_);
    $data{$name}{Name}       = $self->pop_name($_);
    $data{$name}{dbID}       = $_->dbID;
    $data{$name}{Size}       = $self->pop_size($_);
    $data{$name}{PopLink}    = $self->pop_links($_);
    $data{$name}{Description}= $self->pop_description($_);
    $data{$name}{PopObject}  = $_;  ## ok maybe this is cheating..
  }
  return \%data;
}



sub pop_name {

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Example : $self->DataObj->pop_name($pop);
  ### Description : gets the Population name
  ###  Returns String

  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->name;
}


sub ld_for_slice {

  ### Arg1 : population object (optional)
  ### Arg2 : width for the slice (optional)
  ### Example : my $container = $self->ld_for_slice;
  ### Description : returns all LD values on this slice as a
  ###               Bio::EnsEMBL::Variation::LDFeatureContainer
  ### Returns    :  Bio::EnsEMBL::Variation::LDFeatureContainer

  my ($self, $pop_obj, $width) = @_;
  $width = $self->param('w') || "50000" unless $width;
  my ($seq_region, $start, $seq_type ) = ($self->seq_region_name, $self->seq_region_start, $self->seq_region_type);
  return [] unless $seq_region;

  my $end   = $start + $width;
  my $slice = $self->slice_cache($seq_type, $seq_region, $start, $end, 1);
  return {} unless $slice;

  return  $slice->get_all_LD_values($pop_obj) || {};
}


sub pop_links {

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Example : $genotype_freq = $self->DataObj->pop_links($pop);
  ### Description : gets the Population description
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->get_all_synonyms("dbSNP");
}


sub pop_size {

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Example : $genotype_freq = $self->DataObj->pop_size($pop);
  ### Description : gets the Population size
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->size;
}


sub pop_description {

  ### Arg1 : Bio::EnsEMBL::Variation::Population object
  ### Example : $genotype_freq = $self->DataObj->pop_description($pop);
  ### Description : gets the Population description
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->description;
}



sub location { 

  ### Arg1 : (optional) String  Name of slice
  ### Example : my $location = $self->DataObj->name;
  ### Description : getter/setter for slice name
  ### Returns String for slice name

    return $_[0]; 
}

sub generate_query_hash {
  my $self = shift;
  return {
    'c'     => $self->seq_region_name.':'.$self->centrepoint.':'.$self->seq_region_strand,
    'w'     => $self->length,
    'h'     => $self->highlights_string(),
    'pop'   => $self->param('pop'),
 };
}



sub get_variation_features {

  ### Example : my @vari_features = $self->get_variation_features;
  ### Description : gets the Variation features found  on a slice
  ### Returns Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

   my $self = shift;
   my $slice = $self->slice_cache;
   return unless $slice;
   return $slice->get_all_VariationFeatures || [];
}

sub slice_cache {
  my $self = shift;
  my( $type, $region, $start, $end, $strand ) = @_;
  $type   ||= $self->seq_region_type;
  $region ||= $self->seq_region_name;
  $start  ||= $self->seq_region_start;
  $end    ||= $self->seq_region_end;
  $strand ||= $self->seq_region_strand;

  my $key = join '::', $type, $region, $start, $end, $strand;
  unless ($self->__data->{'slice_cache'}{$key}) {
    $self->__data->{'slice_cache'}{$key} =
      $self->database('core')->get_SliceAdaptor()->fetch_by_region(
        $type, $region, $start, $end, $strand
      );
  }
  return $self->__data->{'slice_cache'}{$key};
}


sub current_pop_name {
  my $self = shift;
  my %pops_on;
  my %pops_off;
  my $view_config = $self->get_viewconfig();

  # Read in all in viewconfig stuff
  foreach ($view_config->options) {
    next unless $_ =~ s/opt_pop_//;
    $pops_on{$_}  = 1 if $view_config->get("opt_pop_$_") eq 'on';
    $pops_off{$_} = 1 if $view_config->get("opt_pop_$_") eq 'off';
  }

  # Set options according to bottom
  # if param bottom   #pop_CSHL-HAPMAP:HapMap-JPT:on;
  if ( $self->param('bottom') ) {
    foreach( split /\|/, ($self->param('bottom') ) ) {
      next unless $_ =~ /opt_pop_(.*):(.*)/;
      if ($2 eq 'on') {
	$pops_on{$1} = 1;
	delete $pops_off{$1};
      }
      elsif ($2 eq 'off') {
	$pops_off{$1} = 1;
	delete $pops_on{$1};
      }
    }
    return ( [keys %pops_on], [keys %pops_off] )  if keys %pops_on or keys %pops_off;
  }

  # Get pops switched on via pop arg if no bottom
  if ( $self->param('pop') ) {
    # put all pops_on keys in pops_off
    map { $pops_off{$_} = 1 } (keys %pops_on);
    %pops_on = ();
    map { $pops_on{$_} = 1 if $_ } $self->param('pop');
  }

  return ( [keys %pops_on], [keys %pops_off] )  if keys %pops_on or keys %pops_off;
  return [] if $self->param('bottom') or $self->param('pop');
  my $default_pop =  $self->get_default_pop_name;
  warn "*****[ERROR]: NO DEFAULT POPULATION DEFINED.\n\n" unless $default_pop;
  return ( [$default_pop], [] );
}


sub pops_for_slice {

   ### Example : my $data = $self->DataObj->ld_for_slice;
   ### Description : returns all population IDs with LD data for this slice
   ### Returns hashref of population dbIDs

  my $self = shift;
  my $width  = shift || 100000;

  my $ld_container = $self->ld_for_slice(undef, $width);
  return [] unless $ld_container;

  my $pop_ids = $ld_container->get_all_populations();
  return [] unless @$pop_ids;

  my @pops;
  foreach (@$pop_ids) {
    my $name = $self->pop_name_from_id($_);
    push @pops, $name;
  }

  my @tmp_sorted =  sort {$a cmp $b} @pops;
  return \@tmp_sorted;
}


sub getVariationsOnSlice {
  my $self = shift;
  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $self->slice_cache, $self->__data
       );

  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures;
  return ($count_snps, $filtered_snps);
}


sub get_genotyped_VariationsOnSlice {
  my $self = shift;
  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $self->slice_cache, $self->__data
       );

  my ($count_snps, $filtered_snps) = $sliceObj->get_genotyped_VariationFeatures;
  return ($count_snps, $filtered_snps);
}

sub get_source {
  my $self = shift;
  my $default = shift;
  my $vari_adaptor = $self->database('variation')->get_db_adaptor('variation');
  unless ($vari_adaptor) {
    warn "ERROR: Can't get variation adaptor";
    return ();
  }

  if ($default) {
    return  $vari_adaptor->get_VariationAdaptor->get_default_source();
  }
  else {
    return $vari_adaptor->get_VariationAdaptor->get_all_sources();
  }
}

sub get_all_misc_sets {
  my $self = shift;
  my $temp  = $self->database('core')->get_db_adaptor('core')->get_MiscSetAdaptor()->fetch_all;
  my $result = {};
  foreach( @$temp ) {
    $result->{$_->code} = $_;
  }
  return $result;
}

#------ Individual stuff ------------------------------------------------

sub individual_genotypes {

  ### individual_table_calls
  ### Arg1: variation feature object
  ### Example    : my $ind_genotypes = $object->individual_table;
  ### Description: gets Individual Genotype data for this variation
  ### Returns hashref with all the data

  my ($self, $vf, $slice_genotypes) = @_;
  if (! defined $slice_genotypes->{$vf->seq_region_name.'-'.$vf->seq_region_start}){
      return {};
  }
  my $individual_genotypes = $slice_genotypes->{$vf->seq_region_name.'-'.$vf->seq_region_start};
  return {} unless @$individual_genotypes; 
  my %data = ();
  my %genotypes = ();

  my %gender = qw (Unknown 0 Male 1 Female 2 );
  foreach my $ind_gt_obj ( @$individual_genotypes ) { 
    my $ind_obj   = $ind_gt_obj->individual;
    next unless $ind_obj;

    # data{name}{AA}
    #we should only consider 1 base genotypes (from compressed table)
    next if ( CORE::length($ind_gt_obj->allele1) > 1 || CORE::length($ind_gt_obj->allele2)>1);
    foreach ($ind_gt_obj->allele1, $ind_gt_obj->allele2) {
      my $allele = $_ =~ /A|C|G|T|N/ ? $_ : "N";
      $genotypes{ $ind_obj->name }.= $allele;
    }
    $data{ $ind_obj->name }{gender}   = $gender{$ind_obj->gender} || 0;
    $data{ $ind_obj->name }{mother}   = $self->parent($ind_obj, "mother");
    $data{ $ind_obj->name }{father}   = $self->parent($ind_obj, "father");
  }
  return \%genotypes, \%data;
}


sub parent {

  ### Individual_genotype_table_calls
  ### Args1      : Bio::EnsEMBL::Variation::Individual object
  ### Arg2      : string  "mother" "father"
  ### Example    : $mother = $object->parent($individual, "mother");
  ### Description: gets name of parent if known
  ### Returns string (name of parent if known, else 0)

  my ($self, $ind_obj, $type)  = @_;
  my $call =  $type. "_Individual";
  my $parent = $ind_obj->$call;
  return 0 unless $parent;
  return $parent->name || 0;
}


sub get_all_genotypes{
    my $self = shift;

    my $slice = $self->slice_cache;
    my $variation_db = $self->database('variation')->get_db_adaptor('variation');
    my $iga = $variation_db->get_IndividualGenotypeAdaptor;
    my $genotypes = $iga->fetch_all_by_Slice($slice);
    #will return genotypes as a hash, having the region_name-start as key for rapid acces
    my $genotypes_hash = {};
    foreach my $genotype (@{$genotypes}){
	push @{$genotypes_hash->{$genotype->seq_region_name.'-'.$genotype->seq_region_start}},$genotype;
    }
    return $genotypes_hash;
}

1;
