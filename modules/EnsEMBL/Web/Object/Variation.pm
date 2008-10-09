package EnsEMBL::Web::Object::Variation;

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 

### Purpose: to store and manipulate ensembl Variation and Variation Feature objects
### it provides a thin wrapper around the ensembl-core-api

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

CONTACT Fiona Cunningham - webmaster@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);


sub short_caption {
  my $self = shift;
  my $label = $self->name;
  if( length($label)>30) {
    return "Var: $label";
  } else {
    return "Variation: $label";
  }
}

sub counts {
 my $self = shift;
 my @vari_mappings = @{ $self->get_variation_features };
 my $counts = @vari_mappings;
 
return $counts;
}

sub caption {
 my $self = shift; 
 my $caption = 'Variation: '.$self->name;

 return $caption;
}

# Location ----------------------------------------------------------------------

sub location_string {

  ### Variation_location
  ### Example    : my $location = $self->location_string;
  ### Description: Gets chr:start-end for the SNP with 100 bases on either side
  ### Returns string: chr:start-end

  my ($self, $unique) = @_;
  my( $sr, $st ) = $self->_seq_region_($unique);
  return $sr ? "$sr:@{[$st-100]}-@{[$st+100]}" : undef;
}

sub var_location {
  ### Variation_location
  ### Example    : my $location = $self->location_string;
  ### Description: Gets chr:start-end for the SNP 
  ### Returns string: chr:start-end

  my ($self, $unique) = @_;
  my( $sr, $st ) = $self->_seq_region_($unique);
  return $sr ? "$sr:@{[$st]}-@{[$st]}" : undef;
}

sub _seq_region_ {

  ### Variation_location
  ### Args        : $unique
  ###               if $unique=1 -> returns undef if there are more than one 
  ###               variation features returned)
  ###               if $unique is 0 or undef, it returns the data for the first
  ###               mapping postion
  ### Example    : my ($seq_region, $start) = $self->_seq_region_;
  ### Description: Gets the sequence region, start and coordinate system name
  ### Returns $seq_region, $start, $seq_type

  my $self = shift;
  my $unique = shift;
  my($seq_region, $start, $seq_type);
  if (  my $region  = $self->param('c') ) {
    ($seq_region, $start) = split /:/, $region;
    my $slice = $self->database('core')->get_SliceAdaptor->fetch_by_region(undef,$seq_region);
    return unless $slice;
    $seq_type = $slice->coord_system->name;
  }
  else {
    my @vari_mappings = @{ $self->get_variation_features };
    return (undef, undef, undef, "no") unless  @vari_mappings;

    if ($unique) {
      return (undef, undef, undef, "multiple") if $#vari_mappings > 0;
    }
    $seq_region  = $self->region_name($vari_mappings[0]);
    $start       = $self->start($vari_mappings[0]);
    $seq_type    = $self->region_type($vari_mappings[0]);
  }
  return ( $seq_region, $start, $seq_type );
}


sub seq_region_name    {

  ### Variation_location 
  ### a

  my( $sr,$st) = $_[0]->_seq_region_; return $sr; 
}
sub seq_region_start   {
  ### Variation_location 
  ### a
  my( $sr,$st) = $_[0]->_seq_region_; return $st; 
}
sub seq_region_end     {
  ### Variation_location 
  ### a
  my( $sr,$st) = $_[0]->_seq_region_; return $st; 
}
sub seq_region_strand  {
  ### Variation_location 
  ### a
  return 1; 
}
sub seq_region_type    { 
  ### Variation_location
  ### a
  my($sr,$st,$type) = $_[0]->_seq_region_; return $type; 
}

sub seq_region_data {

  ### Variation_location
  ### Args       : none
  ### Example    : my ($seq_region, $start, $type) = $object->seq_region_data;
  ### Description: Only returns sequence region, start and coordinate system name 
  ###              if this Variation Object maps to one Variation Feature obj
  ### Returns $seq_region, $start, $seq_type, $error(optional) which specifies
  ### 'no' if no mapping or 'multiple' if has several hits
  ### If there is an error, the first 3 args returned are undef

  my($sr,$st,$type, $error) = $_[0]->_seq_region_(1); 
  return ($sr, $st, $type, $error);
}


# Variation calls ----------------------------------------------------------------
sub vari {

  ### Variation_object_calls
  ### Args: none
  ### Example    : my $ensembl_vari = $object->vari
  ### Description: Gets the ensembl variation object stored on the variation data object
  ### Returns Bio::EnsEmbl::Variation

  my $self = shift;
  return $self->Obj;
}

sub name {

   ### Variation_object_calls
   ### a
   ### Arg (optional):   Variation object name (string)
   ### Example    : my $vari_name = $object->vari_name;
   ### Example    : $object->vari_name('12335');
   ### Returns String for variation name

  my $self = shift;
  if (@_) {
      $self->vari->name(shift);
  }
  return $self->vari->name;
}


sub source {

  ### Variation_object_calls
  ### Args: none
  ### Example    : my $vari_source = $object->source;
  ### Description: gets the Variation source
  ### Returns String

  $_[0]->vari->source;
}



sub get_genes {

  ### Variation_object_calls
  ### a
  ### Args: none
  ### Example    : my @genes = @ {$obj->get_genes};
  ### Returns arrayref of Bio::EnsEMBL::Gene objects

  $_[0]->vari->get_all_Genes; 
}


sub source_version { 

  ### Variation_object_calls
  ### a
  ### Example    : my $vari_source_version = $object->source
  ### Description: gets the Variation source version e.g. dbSNP version 119
  ### Returns String

  my $self    = shift;
  my $source  = $self->vari->source;
  my $version = $self->vari->adaptor->get_source_version($source);
  return $version;
}


sub dblinks {

  ### Variation_object_calls
  ### Args: none
  ### Example    : my $dblinks = $object->dblinks;
  ### Description: gets the SNPs links to external database
  ### Returns Hashref (external DB => listref of external IDs)

  my $self = shift;
  my @sources = @{  $self->vari->get_all_synonym_sources  };
  my %synonyms;
  foreach (@sources) {
    $synonyms{$_} = $self->vari->get_all_synonyms($_);
  }
  return \%synonyms;
}

sub consequence_type {
  my $self = shift;
  my $consequence_type;
  my @vari_mappings = @{ $self->get_variation_features };
  foreach my $f (@vari_mappings){
    return '-' unless $f->variation_name eq $self->name;
    $consequence_type = $f->display_consequence;
  }
  $consequence_type =~s/_/ /g;
 
  return $consequence_type;
}

sub status { 

  ### Variation_object_calls
  ### a
  ### Example    : my $vari_status = $object->get_all_validation_states;
  ### Returns List of states

  my $self = shift;
  return $self->vari->get_all_validation_states;
}



sub flanking_seq {

  ### Variation_object_calls
  ### Args: "up" or "down" (string)
  ### Example    : my $down_seq = $object->flanking_seq($down);
  ### Description: gets the sequence downstream of the SNP
  ### Returns String

  my $self = shift;
  my $direction = shift;
  my $call = $direction eq 'up' ? "five_prime_flanking_seq" : "three_prime_flanking_seq";
  my $sequence;
  eval { 
    $sequence = $self->vari->$call;
  };
  if ($@) {
    warn "*****[ERROR]: No flanking sequence!";
    return 'unavailable';
  }
  return uc($sequence);
}


sub alleles {

  ### Variation_object_call
  ### Args: none
  ### Example    : my $alleles = $object->alleles;
  ### Description: gets the SNP alleles
  ### Returns Array or string

  my $self = shift;

  my  @vari_mappings = @{ $self->unique_variation_feature };
  return $vari_mappings[0]->allele_string if @vari_mappings == 1;

  # Several mappings or no mappings
  my @allele_obj = @{$self->vari->get_all_Alleles};
  my %alleles;
  map { $alleles{$_->allele} = 1; } @allele_obj;

  my $observed_alleles = "Observed alleles are: ". join ", ", (keys %alleles);
  if (@vari_mappings) {
    return "$observed_alleles";
  } else {
    return "This variation has no mapping.  $observed_alleles";
  }
}



sub vari_class{

  ### Variation_object_calls
  ### a
  ### Example    : my $vari_class = $object->vari_class
  ### Description: returns the variation class (indel, snp, het) for a varation
  ### Returns String

  return $_[0]->vari->var_class;
 }



sub moltype {

  ### Variation_object_calls
  ### a
  ### Example    : $object->moltype;
  ### Description: returns the molecular type of the variation
  ### Returns String

  my $self = shift;
  return $self->vari->moltype;
}



sub ancestor {

  ### Variation_object_calls 
  ### a
  ### Example    : $object->ancestral_allele;
  ### Description: returns the ancestral allele for the variation
  ### Returns String

  my $self = shift;
  return $self->vari->ancestral_allele;
}



sub tagged_snp { 

  ### Variation_object_calls
  ### Args: none
  ### Example    : my $pops = $object->tagged_snp
  ### Description: The "is_tagged" call returns an array ref of populations 
  ###              objects Bio::Ensembl::Variation::Population where this SNP 
  ###              is a tag SNP
  ### Returns hashref of pop_name

  my $self = shift;
  my  @vari_mappings = @{ $self->get_variation_features };
  return {} unless @vari_mappings;

  my %pops;
  foreach my $vf ( @vari_mappings ) {
    foreach my $pop_obj ( @{ $vf->is_tagged } ) {
      $pops{$self->pop_name($pop_obj)} = "Tag SNP";
    }
  }
  return \%pops or {};
}



sub freqs {

  ### Population_allele_genotype_frequencies
  ### Args      : none
  ### Example    : my $data = $object->freqs;
  ### Description: gets allele and genotype frequencies for this Variation
  ### Returns hash of data, 

  my $self = shift;
  my $allele_list = $self->vari->get_all_Alleles;
  return {} unless $allele_list;

  my %data;
  foreach my $allele_obj ( @{ $allele_list } ) {
    my $pop_obj = $allele_obj->population;
    next unless $pop_obj;
    my $pop_id  = $self->pop_id($pop_obj);
    push (@{ $data{$pop_id}{AlleleFrequency} }, $allele_obj->frequency || "");
    push (@{ $data{$pop_id}{Alleles} },   $allele_obj->allele);
    next if $data{$pop_id}{pop_info};
    $data{$pop_id}{pop_info} = $self->pop_info($pop_obj);
  }

  # Add genotype data;
  return {} unless $self->pop_genotype_obj;

  foreach my $pop_gt_obj ( @{ $self->pop_genotype_obj } ) {
    my $pop_obj = $pop_gt_obj->population;
    my $pop_id  = $self->pop_id($pop_obj);
    push (@{ $data{$pop_id}{GenotypeFrequency} }, $pop_gt_obj->frequency);
    push (@{ $data{$pop_id}{Genotypes} }, $self->pop_genotypes($pop_gt_obj));
    next if $data{$pop_id}{pop_info};
    $data{$pop_id}{pop_info} = $self->pop_info($pop_obj);
  }
  return \%data;
}


# Population genotype and allele frequency table calls ----------------

sub pop_genotype_obj {

  ### frequencies_table
  ### Example    : my $pop_genotype_obj = $object->pop_genotype_obj;
  ### Description: gets Population genotypes for this Variation
  ### Returns listref of Bio::EnsEMBL::Variation::PopulationGenotype

  my $self = shift;
  return  $self->vari->get_all_PopulationGenotypes;
}




sub pop_genotypes {

  ### frequencies_table
  ###  Args      : Bio::EnsEMBL::Variation::PopulationGenotype object
  ### Example    : $genotype_freq = $object->pop_genotypes($pop);
  ### Description: gets the Population genotypes
  ### Returns String

  my ($self, $pop_genotype_obj)  = @_;
  return join "|", sort($pop_genotype_obj->allele1, $pop_genotype_obj->allele2);

}



sub pop_info {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : my $data = $self->pop_info
  ### Description: returns a hash with data about this population
  ### Returns hash of data

  my $self = shift;
  my $pop_obj = shift;
  my %data;
  $data{Name}               = $self->pop_name($pop_obj);
  $data{PopLink}            = $self->pop_links($pop_obj);
  $data{Size}               = $self->pop_size($pop_obj);
  $data{Description}        = $self->pop_description($pop_obj);
  $data{"Super-Population"} = $self->extra_pop($pop_obj,"super");
  $data{"Sub-Population"}   = $self->extra_pop($pop_obj,"sub");
  return \%data;
}



sub pop_name {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $object->pop_name($pop);
  ### Description: gets the Population name
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->name;
}



sub pop_id {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $object->pop_id($pop);
  ### Description: gets the Population ID
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->dbID;
}



sub pop_links {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $genotype_freq = $object->pop_links($pop);
  ### Description: gets the Population description
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->get_all_synonyms("dbSNP");
}



sub pop_size {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $genotype_freq = $object->pop_size($pop);
  ### Description: gets the Population size
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->size;
}



sub pop_description {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $genotype_freq = $object->pop_description($pop);
  ### Description: gets the Population description
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->description;
}



sub extra_pop {

  ### frequencies_table
  ### Args1      : Bio::EnsEMBL::Variation::Population object
  ### Args2      : string "super", "sub"
  ### Example    : $genotype_freq = $object->extra_pop($pop, "super");
  ### Description: gets any super/sub populations
  ### Returns String

  my ($self, $pop_obj, $type)  = @_;
  return {} unless $pop_obj;
  my $call = "get_all_$type" . "_Populations";
  my @populations = @{ $pop_obj->$call};

  my %extra_pop;
  foreach my $pop ( @populations ) {
    my $id = $self->pop_id($pop_obj);
    $extra_pop{$id}{Name}       = $self->pop_name($pop);
    $extra_pop{$id}{Size}       = $self->pop_size($pop);
    $extra_pop{$id}{PopLink}    = $self->pop_links($pop);
    $extra_pop{$id}{Description}= $self->pop_description($pop);
  }
  return \%extra_pop;
}


# Individual table -----------------------------------------------------

sub individual_table {

  ### individual_table_calls
  ### Example    : my $ind_genotypes = $object->individual_table;
  ### Description: gets Individual Genotype data for this variation
  ### Returns hashref with all the data

  my $self = shift;
  my $individual_genotypes = $self->individual_genotypes_obj;
  return {} unless @$individual_genotypes; 
  my %data;
  foreach my $ind_gt_obj ( @$individual_genotypes ) { 
    my $ind_obj   = $ind_gt_obj->individual;
    next unless $ind_obj;
    my $ind_id    = $ind_obj->dbID;

    $data{$ind_id}{Name}           = $ind_obj->name;
    $data{$ind_id}{Genotypes}      = $self->individual_genotype($ind_gt_obj);
    $data{$ind_id}{Gender}         = $ind_obj->gender;
    $data{$ind_id}{Description}    = $self->individual_description($ind_obj);
    $data{$ind_id}{Population}     = $self->get_individuals_pops($ind_obj);
    $data{$ind_id}{Mother}        = $self->parent($ind_obj,"mother");
    $data{$ind_id}{Father}        = $self->parent($ind_obj,"father");
    $data{$ind_id}{Children}      = $self->child($ind_obj);
  }
  return \%data;
}



sub individual_genotypes_obj {

  ### Individual_genotype_table_calls
  ### Example    : my $ind_genotypes = $object->individual_genotypes;
  ### Description: gets IndividualGenotypes for this Variation
  ### Returns listref of IndividualGenotypes

  my $self = shift;
  my $individuals;
  eval {
    $individuals = $self->vari->get_all_IndividualGenotypes;
  };
  if ($@) {
    warn "\n\n************ERROR************:  Bio::EnsEMBL::Variation::Variation::get_all_IndividualGenotypes fails.";
  }
  return $individuals;
}



sub individual_genotype {

  ### Individual_genotype_table_calls
  ### Args      : Bio::EnsEMBL::Variation::IndividualGenotype object
  ### Example    : $genotype_freq = $object->individual_genotypes($individual);
  ### Description: gets the Individual genotypes
  ### Returns String

  my ($self, $individual)  = @_;
  return $individual->allele1."|".$individual->allele2;

}


sub individual_description {

  ### Individual_genotype_table_calls
  ### Args      : Bio::EnsEMBL::Variation::Individual object
  ### Example    : $genotype_freq = $object->individual_description($individual);
  ### Description: gets the Individual description
  ### Returns String

  my ($self, $individual_obj)  = @_;
  return $individual_obj->description;
}



sub parent {

  ### Individual_genotype_table_calls
  ### Args1      : Bio::EnsEMBL::Variation::Individual object
  ### Arg2      : string  "mother" "father"
  ### Example    : $mother = $object->parent($individual, "mother");
  ### Description: gets any related individuals
  ### Returns Bio::EnsEMBL::Variation::Individual

  my ($self, $ind_obj, $type)  = @_;
  my $call =  $type. "_Individual";
  my $parent = $ind_obj->$call;
  return {} unless $parent;

  # Gender is obvious, not calling their parents
  return  { Name        => $parent->name,
	    ### Description=> $self->individual_description($ind_obj),
	  };
}


sub child {

  ### Individual_genotype_table_calls
  ### Args      : Bio::EnsEMBL::Variation::Individual object
  ### Example    : %children = %{ $object->extra_individual($individual)};
  ### Description: gets any related individuals
  ### Returns Bio::EnsEMBL::Variation::Individual

  my ($self, $individual_obj)  = @_;
  my %children;

  foreach my $individual ( @{ $individual_obj->get_all_child_Individuals} ) {
    my $gender = $individual->gender;
    $children{$individual->name} = [$gender, 
				   $self->individual_description($individual)];
  }
  return \%children;
}


sub get_individuals_pops {

  ### Individual_genotype_table_calls
  ### Args      : Bio::EnsEMBL::Variation::Individual object
  ### Example    : $pops =  $object->get_individuals_pop($individual)};
  ### Description: gets any individual''s populations
  ### Returns Bio::EnsEMBL::Variation::Population

  my ($self, $individual) = @_;
  my @populations = @{$individual->get_all_Populations};
  my @pop_string;

  foreach (@populations) {
    push (@pop_string,  {Name => $self->pop_name($_), 
			 Link => $self->pop_links($_)});
  }
  return \@pop_string;
}




# Variation mapping ###########################################################


sub variation_feature_mapping { ## used for snpview

  ### Variation_mapping
  ### Example    : my @vari_features = $object->variation_feature_mappin
  ### Description: gets the Variation features found on a variation object;
  ### Returns Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

  my $self = shift;

  my %data;
  foreach my $vari_feature_obj (@{ $self->get_variation_features }) {
     my $varif_id = $vari_feature_obj->dbID;
     $data{$varif_id}{Chr}            = $self->region_name($vari_feature_obj);
     $data{$varif_id}{start}          = $self->start($vari_feature_obj);
     $data{$varif_id}{end}            = $vari_feature_obj->end;
     $data{$varif_id}{strand}         = $vari_feature_obj->strand;
     $data{$varif_id}{transcript_vari} = $self->transcript_variation($vari_feature_obj);

  }
  return \%data;
}


# Calls for variation features -----------------------------------------------

sub unique_variation_feature { 

  ### Variation_features
  ### Description: returns {{Bio::Ensembl::Variation::Feature}} object if
  ### this {{Bio::Ensembl::Variation}} has a unique mapping
  ### Returns undef if no mapping
  ### Returns a arrayref of single Bio::Ensembl::Variation::Feature object if one mapping
  ### Returns a arrayref of Bio::Ensembl::Variation::Feature object if multiple mapping

  my $self = shift;
  my @variation_features = @{ $self->get_variation_features || [] };
  return [] unless  @variation_features;
  return \@variation_features unless $#variation_features > 0; # if unique mapping

  # Must have multiple mapping
  my ($sr, $start, $type) = $self->seq_region_data;
  return \@variation_features unless $sr; #$sr undef if no unique mapping

  my @return;
  foreach (@variation_features) {  # try to find vf which matches unique mapping
    next unless $self->start($_) eq $start;
    next unless $self->region_name($_) eq $sr;
    next unless $self->region_type($_) eq $type;
    push @return, $_;
  }
  return \@return;
}



sub get_variation_features {

  ### Variation_features
  ### Example    : my @vari_features = $object->get_variation_features;
  ### Description: gets the Variation features found  on a variation object;
  ### Returns Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

   my $self = shift;
   return [] unless $self->vari;

   # return VariationFeatures that were added by add_variation_feature if
   # present
   return $self->{'_variation_features'} if ($self->{'_variation_features'});

   my $dbs = $self->DBConnection->get_DBAdaptor('variation');
   my $vari_f_adaptor = $dbs->get_VariationFeatureAdaptor;
   my $vari_features = $vari_f_adaptor->fetch_all_by_Variation($self->vari);
   #   warn Data::Dumper::Dumper($vari_features);
   return $vari_features || [];
}


sub add_variation_feature {

  ### Variation_features
  ### Args      : a Bio::EnsEBML::Variation::VariationFeature object
  ### Example    : $object->add_variation_feature($varfeat);
  ### Description: adds a VariationFeature to the Variation
  ### Returns none
  ### Exceptions  : thrown if wrong object supplied

  my ($self, $vari_feature) = @_;
  unless ($vari_feature->isa('Bio::EnsEMBL::Variation::VariationFeature')) {
    # throw
    $self->problem('fatal', 'EnsEMBL::Web::Data::SNP->add_variation_feature expects a Bio::EnsEMBL::Variation::VariationFeature as argument');
  }

  push @{ $self->{'_variation_features'} }, $vari_feature;
}



sub region_type { 

  ### Variation_features
  ### Args      : Bio::EnsEMBL::Variation::Variation::Feature
  ### Example    : my $chr = $data->region_name($vari)
  ### Description: gets the VariationFeature slice seq region name
  ### Returns String

  my ($self, $vari_feature) = @_;
  my $slice =  $vari_feature->slice;
  return $slice->coord_system->name if $slice;
}

sub region_name { 
  my ($self, $vari_feature) = @_;
  my $slice =  $vari_feature->slice;
  return $slice->seq_region_name() if $slice;
}



sub start {

  ### Variation_features
  ### Args      : Bio::EnsEMBL::Variation::Variation::Feature
  ### Example    : my $vari_start = $object->start($vari);
  ### Description: gets the Variation start coordinates
  ### Returns String

  my ($self, $vari_feature) = @_;
  return $vari_feature->start;
}


sub transcript_variation {

  ### Variation_features
  ### Args      : Bio::EnsEMBL::Variation::Variation::Feature
  ### Example    : my $consequence = $object->consequence($vari);
  ### Description: returns SNP consequence (synonymous, stop gained, ...)
  ### Returns arrayref of transcript variation objs

  my ($self, $vari_feature) = @_;
  my $dbs = $self->DBConnection->get_DBAdaptor('variation');
  $dbs->dnadb($self->database('core'));
  my $transcript_variation_obj =  $vari_feature->get_all_TranscriptVariations;
  return [] unless $transcript_variation_obj;

  my @data;
  foreach my $tvari_obj ( @{ $transcript_variation_obj } )  {
    next unless $tvari_obj->transcript;
    my $type = join ", " , @{ $tvari_obj->consequence_type || [] };

    push (@data, {
            conseq =>           $type,
            transcriptname =>   $tvari_obj->transcript->stable_id,
            proteinname  =>     $tvari_obj->transcript->translation->stable_id,
            cdna_start =>       $tvari_obj->cdna_start,
            cdna_end =>         $tvari_obj->cdna_end,
            translation_start =>$tvari_obj->translation_start,
            translation_end =>  $tvari_obj->translation_end,
            pepallele =>        $tvari_obj->pep_allele_string,
    });
  }

  return \@data;
}



# LD stuff ###################################################################


sub ld_pops_for_snp {

  ### LD
  ### Description: gets an LDfeature container for this SNP and calls all the populations on this
  ### Returns array ref of population IDs

  my $self = shift; 
  my @vari_mappings = @{ $self->unique_variation_feature }; 
  return [] unless @vari_mappings;

  my @pops;
  foreach ( @vari_mappings ) { warn $_;
    my $ldcontainer = $_->get_all_LD_values; warn scalar @{$ldcontainer->get_all_populations};
    push @pops, @{$ldcontainer->get_all_populations};

  }
  return \@pops;
}




sub find_location {

  ### LD
  ### Example    : my $data = $object->find_location
  ### Description: returns the genomic location for the current slice
  ### Returns hash of data

  my $self = shift;
  my $width = shift || $self->param('w') || 50000;
  unless ( $self->{'_slice'} ) {
    $self->_get_slice($width);
  }

  my $slice = $self->{'_slice'};
  return {} unless $slice;
  return $slice->name;
}




sub pop_obj_from_id {

  ### LD
  ### Args      : Population ID
  ### Example    : my $pop_name = $object->pop_obj_from_id($pop_id);
  ### Description: returns population name for the given population dbID
  ### Returns population object

  my $self = shift;
  my $pop_id = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop_obj = $pa->fetch_by_dbID($pop_id);
  return {} unless $pop_obj;
  my %data;
  $data{$pop_id}{Name}    = $self->pop_name($pop_obj);
  $data{$pop_id}{Size}    = $self->pop_size($pop_obj);
  $data{$pop_id}{PopLink} = $self->pop_links($pop_obj);
  $data{$pop_id}{Description}= $self->pop_description($pop_obj);
  $data{$pop_id}{PopObject}= $pop_obj;  ## ok maybe this is cheating..
  return \%data;
}


sub get_default_pop_name {

  ### LD
  ### Example: my $pop_id = $object->get_default_pop_name
  ### Description: returns population id for default population for this species
  ### Returns population dbID

  my $self = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pop_adaptor = $variation_db->get_PopulationAdaptor;
  return unless $pop_adaptor;
  my $pop = $pop_adaptor->fetch_default_LDPopulation();
  return unless $pop;
  return [ $self->pop_name($pop) ];
}

sub location { return $_[0]; }

sub generate_query_hash {
  my $self = shift;
  return {
    'h'       => $self->highlights_string,
    'source'  => $self->source || "dbSNP",
    'snp'     => $self->name,
    'c'       => $self->param('c'),
    'pop'     => $self->get_default_pop_name,
  };
}

sub get_source {
  my $self = shift;
  my $default = shift;

  my $vari_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation');
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
1;
