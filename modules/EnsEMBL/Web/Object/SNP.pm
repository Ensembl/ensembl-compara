package EnsEMBL::Web::Object::SNP;

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 

=head1 NAME

EnsEMBL::Web::Object::SNP - store and manipulate ensembl Variation and Variation Feature objects

=head1 DESCRIPTION

This object stores ensembl snp objects and provides a thin wrapper around the
  ensembl-core-api. It also can create a snp render object

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Fiona Cunningham - webmaster@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);


#### Variation object calls ###################################################


=head2 location_string

   Example     : my $location = $self->location_string;
   Description : Gets chr:start-end for the SNP with 100 bases on either side
   Return type : string: chr:start-end

=cut

sub location_string {
  my( $sr, $st ) = $_[0]->_seq_region_;
  return $sr ? "$sr:@{[$st-100]}-@{[$st+100]}" : undef;
}


=head2 _seq_region

   Args        : $unique
                 if $unique=1 -> returns undef if there are more than one 
                 variation features returned)
                 if $unique is 0 or undef, it returns the data for the first
                 mapping postion
   Example     : my ($seq_region, $start) = $self->_seq_region_;
   Description : Gets the sequence region, start and coordinate system name
   Return type : $seq_region, $start, $seq_type

=cut

sub _seq_region_ {
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
    return undef unless  @vari_mappings;

    if ($unique) {
      return undef if $#vari_mappings > 0;
    }
    $seq_region  = $self->region_name($vari_mappings[0]);
    $start       = $self->start($vari_mappings[0]);
    $seq_type    = $self->region_type($vari_mappings[0]);
  }
  return ( $seq_region, $start, $seq_type );
}


sub seq_region_name    { my( $sr,$st) = $_[0]->_seq_region_; return $sr; }
sub seq_region_start   { my( $sr,$st) = $_[0]->_seq_region_; return $st; }
sub seq_region_end     { my( $sr,$st) = $_[0]->_seq_region_; return $st; }
sub seq_region_strand  { return 1; }
sub seq_region_type    { my($sr,$st,$type) = $_[0]->_seq_region_; return $type; }


=head2 seq_region_data

   Args        : none
   Example     : my ($seq_region, $start, $type) = $object->seq_region_data;
   Description : Gets the sequence region, start and coordinate system name
   Return type : $seq_region, $start, $seq_type

=cut

sub seq_region_data {
  my($sr,$st,$type) = $_[0]->_seq_region_(1); 
  return ($sr, $st, $type);
}



=head2 vari

  Arg[1]      : none
  Example     : my $ensembl_vari = $object->vari
  Description : Gets the ensembl variation object stored on the variation data object
  Return type : Bio::EnsEmbl::Variation

=cut

sub vari {
  my $self = shift;
  return $self->Obj;
}


=head2 name

   Arg[1]      : (optional) String
                 Variation object name
   Example     : my $vari_name = $object->vari_name;
                 $object->vari_name('12335');
   Description : getter/setter for Variation name
   Return type : String for variation name

=cut

sub name {
  my $self = shift;
  if (@_) {
      $self->vari->name(shift);
  }
  return $self->vari->name;
}


=head2 source

  Arg[1]      : none
  Example     : my $vari_source = $object->source;
  Description : gets the Variation source
  Return type : String

=cut

sub source {   $_[0]->vari->source }


=head2 get_genes

  Arg[1]      : none
  Example     : my @genes = @ {$obj->get_genes};
  Description : gets the genes affected by this variation
  Return type : arrayref of Bio::EnsEMBL::Gene objects

=cut


sub get_genes {   $_[0]->vari->get_all_Genes; }


=head2 source_version

  Arg[1]      : none
  Example     : my $vari_source_version = $object->source
  Description : gets the Variation source version e.g. dbSNP version 119
  Return type : String

=cut

sub source_version { 
  my $self    = shift;
  my $source  = $self->vari->source;
  my $version = $self->vari->adaptor->get_source_version($source);
  return $version;
}


=head2 dblinks

  Arg[1]      : none
  Example     : my $dblinks = $object->dblinks;
  Description : gets the SNPs links to external database
  Return type : Hashref (external DB => listref of external IDs)

=cut

sub dblinks {
  my $self = shift;
  my @sources = @{  $self->vari->get_all_synonym_sources  };
  my %synonyms;
  foreach (@sources) {
    next if $_ eq 'dbSNP';  # these are ss IDs and aren't really synonyms
    $synonyms{$_} = $self->vari->get_all_synonyms($_);
  }
  return \%synonyms;
}


=head2 status

  Arg[1]      : none
  Example     : my $vari_status = $object->get_all_validation_states;
  Description : gets the Variation status
  Return type : List of states

=cut

sub status { 
  my $self = shift;
  return $self->vari->get_all_validation_states;
}


=head2 alleles

  Arg[1]      : none
  Example     : my $alleles = $object->alleles;
  Description : gets the SNP alleles
  Return type : Array

=cut

sub alleles {
  my $self = shift;
  my  @vari_mappings = @{ $self->get_variation_features };

  my %allele_string;
  if (@vari_mappings) {
    map { $allele_string{$_->allele_string} = 1; } @vari_mappings;
    return (keys %allele_string) unless scalar (keys %allele_string) > 1;
  }

  # Several mappings or no mappings
  my @allele_obj = @{$self->vari->get_all_Alleles};
  my %alleles;
  map { $alleles{$_->allele} = 1; } @allele_obj;

  my $observed_alleles = "Observed alleles are: ". join ", ", (keys %alleles);
  if (@vari_mappings) {
    return "This variation maps to several locations. $observed_alleles";
  }
  else {
    return "This variation has no mapping.  $observed_alleles";
  }
}

=head2 vari_class

  Arg[1]      : none
  Example     : my $vari_class = $object->vari_class
  Description : returns the variation class (indel, snp, het) for a varation
  Return type : String

=cut

sub vari_class{ $_[0]->vari->var_class }



=head2 moltype

  Arg[1]      : none
  Example     : $object->moltype;
  Description : returns the molecular type of the variation
  Return type : String

=cut

sub moltype {
  my $self = shift;
  return $self->vari->moltype;
}


=head2 ancestor

  Arg[1]      : none
  Example     : $object->ancestral_allele;
  Description : returns the ancestral allele for the variation
  Return type : String

=cut

sub ancestor {
  my $self = shift;
  return $self->vari->ancestral_allele;
}

=head2 tagged_snp

  Arg[1]      : none
  Example     : my $pops = $object->tagged_snp
  Description : The "is_tagged" call returns an array ref of populations 
                objects Bio::Ensembl::Variation::Population where this SNP 
                is a tag SNP
  Return type : arrayref of pop_name

=cut

sub tagged_snp { 
  my $self = shift;
  my  @vari_mappings = @{ $self->get_variation_features };
  return [] unless @vari_mappings;

  my @pops;
  foreach my $vf ( @vari_mappings ) {
    foreach my $pop_obj ( @{ $vf->is_tagged } ) {
      push @pops, $self->pop_name($pop_obj);
    }
  }
  return \@pops or [];
}


# Population Genotype frequencies and Allele Frequencies ######################

=head2 pop_table

  Arg[1]      : Bio::EnsEMBL::Variation::Variation object
  Example     : my ($header_row, $rows) = $object->pop_table
  Description : gets Population genotypes for this Variation
  Return type : hash of data, key is pop name, second key is type of data

=cut

sub pop_table {
  my $self = shift;
  return {} unless $self->pop_genotype_obj;

  my %data;
  foreach my $pop_gt_obj ( @{ $self->pop_genotype_obj } ) {
    my $pop_obj = $pop_gt_obj->population;
    my $pop_id  = $self->pop_id($pop_obj);
    push (@{ $data{$pop_id}{Frequency} }, $pop_gt_obj->frequency);
    push (@{ $data{$pop_id}{Genotypes} }, $self->pop_genotypes($pop_gt_obj));
    next if $data{$pop_id}{pop_info};
    $data{$pop_id}{pop_info} = $self->pop_info($pop_obj);
  }
  return (\%data);
}


=head2 allele_freqs

  Arg[1]      : Bio::EnsEMBL::Variation::Variation object
  Example     : my $data = $object->allele_freqs;
  Description : gets allele frequencies for this Variation
  Return type : hash of data, 

=cut

sub allele_freqs {
  my $self = shift;
  my $allele_list = $self->vari->get_all_Alleles;
  return {} unless $allele_list;

  my %data;
  foreach my $allele_obj ( @{ $allele_list } ) {
    my $pop_obj = $allele_obj->population;
    next unless $pop_obj;
    my $pop_id  = $self->pop_id($pop_obj);
    push (@{ $data{$pop_id}{Frequency} }, $allele_obj->frequency);
    push (@{ $data{$pop_id}{Alleles} },   $allele_obj->allele);

    next if $data{$pop_id}{pop_info};
    $data{$pop_id}{pop_info} = $self->pop_info($pop_obj);
  }
  return \%data;
}



# Methods used by pop_table --------------------------------------------------
=head2 pop_genotype_obj

  Arg[1]      : Bio::EnsEMBL::Variation::Variation object
  Example     : my $pop_genotype_obj = $object->pop_genotype_obj;
  Description : gets Population genotypes for this Variation
  Return type : listref of Bio::EnsEMBL::Variation::PopulationGenotype

=cut

sub pop_genotype_obj {
  my $self = shift;
  return  $self->vari->get_all_PopulationGenotypes;
}


=head2 pop_genotypes

  Arg[1]      : Bio::EnsEMBL::Variation::PopulationGenotype object
  Example     : $genotype_freq = $object->pop_genotypes($pop);
  Description : gets the Population genotypes
  Return type : String

=cut

sub pop_genotypes {
  my ($self, $pop_genotype_obj)  = @_;
  return $pop_genotype_obj->allele1."/".$pop_genotype_obj->allele2;

}

=head2 pop_info

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : my $data = $self->pop_info
  Description : returns a hash with data about this population
  Return type : hash of data, 

=cut

sub pop_info {
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


=head2 pop_name

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $object->pop_name($pop);
  Description : gets the Population name
  Return type : String

=cut

sub pop_name {
  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->name;
}


=head2 pop_id

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $object->pop_id($pop);
  Description : gets the Population ID
  Return type : String

=cut

sub pop_id {
  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->dbID;
}


=head2 pop_links

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $object->pop_links($pop);
  Description : gets the Population description
  Return type : String

=cut

sub pop_links {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->get_all_synonyms("dbSNP");
}


=head2 pop_size

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $object->pop_size($pop);
  Description : gets the Population size
  Return type : String

=cut

sub pop_size {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->size;
}


=head2 pop_description

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $object->pop_description($pop);
  Description : gets the Population description
  Return type : String

=cut

sub pop_description {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->description;
}


=head2 extra_pop

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Arg[2]      : string "super", "sub"
  Example     : $genotype_freq = $object->extra_pop($pop, "super");
  Description : gets any super/sub populations
  Return type : String

=cut

sub extra_pop {
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


# Individual table ##########################################################

=head2 individual_table

  Arg[1]      : none
  Example     : my $ind_genotypes = $object->individual_table;
  Description : gets Individual Genotype data for this variation
  Return type : hashref with all the data

=cut

sub individual_table {
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


# Individual genotypes table calls --------------------------------------------

=head2 individual_genotypes_obj

  Arg[1]      : none
  Example     : my $ind_genotypes = $object->individual_genotypes;
  Description : gets IndividualGenotypes for this Variation
  Return type : listref of IndividualGenotypes

=cut

sub individual_genotypes_obj {
  my $self = shift;
  my $individuals;
  eval {
    $individuals = $self->vari->get_all_IndividualGenotypes;
  };
  if ($@) {
    print STDERR "\n\n************ERROR************:  Bio::EnsEMBL::Variation::Variation::get_all_IndividualGenotypes fails.\n\n ";
  }
  return $individuals;
}


=head2 individual_genotype

  Arg[1]      : Bio::EnsEMBL::Variation::IndividualGenotype object
  Example     : $genotype_freq = $object->individual_genotypes($individual);
  Description : gets the Individual genotypes
  Return type : String

=cut

sub individual_genotype {
  my ($self, $individual)  = @_;
  return $individual->allele1.$individual->allele2;

}

=head2 individual_description

  Arg[1]      : Bio::EnsEMBL::Variation::Individual object
  Example     : $genotype_freq = $object->individual_description($individual);
  Description : gets the Individual description
  Return type : String

=cut

sub individual_description {
  my ($self, $individual_obj)  = @_;
  return $individual_obj->description;
}

=head2 parent

  Arg[1]      : Bio::EnsEMBL::Variation::Individual object
  Arg[2]      : string  "mother" "father"
  Example     : $mother = $object->parent($individual, "mother");
  Description : gets any related individuals
  Return type : Bio::EnsEMBL::Variation::Individual

=cut

sub parent {
  my ($self, $ind_obj, $type)  = @_;
  my $call =  $type. "_Individual";
  my $parent = $ind_obj->$call;
  return {} unless $parent;

  # Gender is obvious, not calling their parents
  return  { Name        => $parent->name,
	    Description => $self->individual_description($ind_obj),
	  };
}

=head2 child

  Arg[1]      : Bio::EnsEMBL::Variation::Individual object
  Example     : %children = %{ $object->extra_individual($individual)};
  Description : gets any related individuals
  Return type : Bio::EnsEMBL::Variation::Individual

=cut

sub child {
  my ($self, $individual_obj)  = @_;
  my %children;

  foreach my $individual ( @{ $individual_obj->get_all_child_Individuals} ) {
    my $gender = $individual->gender;
    $children{$individual->name} = [$gender, 
				   $self->individual_description($individual)];
  }
  return \%children;
}

=head2 get_individuals_pop

  Arg[1]      : Bio::EnsEMBL::Variation::Individual object
  Example     : $pops =  $object->get_individuals_pop($individual)};
  Description : gets any individual''s populations
  Return type : Bio::EnsEMBL::Variation::Population

=cut

sub get_individuals_pops {
  my ($self, $individual) = @_;
  my @populations = @{$individual->get_all_Populations};
  my @pop_string;

  foreach (@populations) {
    push (@pop_string,  {Name => $self->pop_name($_), 
			 Link => $self->pop_links($_)});
  }
  return \@pop_string;
}

########## NOT USED ############################
=head2 _get_slice

   Arg[1]      : none
   Example     : my $slice = $self->_get_slice
   Description : get slice for this variation object
   Return type : Bio::EnsEMBL::Slice

=cut

sub _get_slice {
   my $self    = shift;
   my $width   = shift;
   my $region  = $self->param('c');
   #my $gene_id = $self->param('gene');
   my $seq_region;
   my $start;

   my $slice_adaptor = $self->database('core')->get_SliceAdaptor;
   my $slice;

   #if ( $gene_id and $self->param('usegene') eq 'yes') {
   #  my $gene_adaptor = $self->database('core')->get_GeneAdaptor;
   #  my $gene = $gene_adaptor->fetch_by_stable_id($gene_id);
   #  my $length = $gene->length;
   #  my $flank = ($width - $length);
   #  $slice =  $slice_adaptor->fetch_by_gene_stable_id(
   #				          $gene_id,
   # 					  $flank/2
   #					 );
   #}

   #else {
     # get $chr and $chr_start from variation feature unless in url
     if ($region) {
       ($seq_region, $start) = split /:/, $region;
     }
     else {
       my @vari_mappings = @{ $self->get_variation_features };
       if (scalar @vari_mappings == 1) {
	 $seq_region  = $self->region_name($vari_mappings[0]);
	 $start       = $self->start($vari_mappings[0]);
       }
     }
     return unless ($seq_region && $start);

     $slice = $slice_adaptor->fetch_by_region(
					      undef,
					      $seq_region,
					      $start - ($width/2),
					      $start + ($width/2)
					     );
  # }

   $self->{'_slice'} = $slice;
   return $slice;
}


=head2 flanking_seq

  Arg[1]      : none
  Example     : my $down_seq = $object->flanking_seq($down);
  Description : gets the sequence downstream of the SNP
  Return type : String

=cut

sub flanking_seq {
  my $self = shift;
  my $direction = shift;
  my $call = $direction eq 'up' ? "five_prime_flanking_seq" : "three_prime_flanking_seq";
  my $sequence;
  eval { 
    $sequence = $self->vari->$call;
  };
  if ($@) {
    print STDERR "*****[ERROR]: No flanking sequence!\n\n\n";
    return 'unavailable';
  }
  return uc($sequence);
}


# Variation mapping ###########################################################

=head2 variation_feature_mapping

  Arg[1]      : none
  Example     : my @vari_features = $object->variation_feature_mappin
  Description : gets the Variation features found on a variation object;
  Return type : Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

=cut

sub variation_feature_mapping { ## used for snpview
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

=head2 get_variation_features

  Arg[1]      : none
  Example     : my @vari_features = $object->get_variation_features;
  Description : gets the Variation features found  on a variation object;
  Return type : Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

=cut

sub get_variation_features {
   my $self = shift;
   return unless $self->vari;

   # return VariationFeatures that were added by add_variation_feature if
   # present
   return $self->{'_variation_features'} if ($self->{'_variation_features'});

   my $dbs = $self->DBConnection->get_DBAdaptor('variation');
   my $vari_f_adaptor = $dbs->get_VariationFeatureAdaptor;
   my $vari_features = $vari_f_adaptor->fetch_all_by_Variation($self->vari);
   #   warn Data::Dumper::Dumper($vari_features);
   return $vari_features || [];
}

=head2 add_variation_feature

  Arg[1]      : a Bio::EnsEBML::Variation::VariationFeature object
  Example     : $object->add_variation_feature($varfeat);
  Description : adds a VariationFeature to the Variation
  Return type : none
  Exceptions  : thrown if wrong object supplied
  Caller      : general

=cut

sub add_variation_feature {
    my ($self, $vari_feature) = @_;
    
    unless ($vari_feature->isa('Bio::EnsEMBL::Variation::VariationFeature')) {
        # throw
        $self->problem('fatal', 'EnsEMBL::Web::Data::SNP->add_variation_feature expects a Bio::EnsEMBL::Variation::VariationFeature as argument');
    }

    push @{ $self->{'_variation_features'} }, $vari_feature;
}

=head2 region_name

  Arg[1]      : Bio::EnsEMBL::Variation::Variation::Feature
  Example     : my $chr = $data->region_name($vari)
  Description : gets the VariationFeature slice seq region name
  Return type : String

=cut

sub region_type { 
  my ($self, $vari_feature) = @_;
  my $slice =  $vari_feature->slice;
  return $slice->coord_system->name if $slice;
}

sub region_name { 
  my ($self, $vari_feature) = @_;
  my $slice =  $vari_feature->slice;
  return $slice->seq_region_name() if $slice;
}

=head2 start

  Arg[1]      : Bio::EnsEMBL::Variation::Variation::Feature
  Example     : my $vari_start = $object->start($vari);
  Description : gets the Variation start coordinates
  Return type : String

=cut

sub start {
  my ($self, $vari_feature) = @_;
  return $vari_feature->start;

}

=head2 transcript_variation

  Arg[1]      : Bio::EnsEMBL::Variation::Variation::Feature
  Example     : my $consequence = $object->consequence($vari);
  Description : returns SNP consequence (synonymous, stop gained, ...)
  Return type : arrayfre of transcript variation objs

=cut

sub transcript_variation {
  my ($self, $vari_feature) = @_;
  my $dbs = $self->DBConnection->get_DBAdaptor('variation');
  $dbs->dnadb($self->database('core'));
  my $transcript_variation_obj =  $vari_feature->get_all_TranscriptVariations;
  return [] unless $transcript_variation_obj;

  my @data;
  foreach my $tvari_obj ( @{ $transcript_variation_obj } )  {
    next unless $tvari_obj->transcript;
    my $type = $tvari_obj->consequence_type;
    if ($tvari_obj->splice_site or $tvari_obj->regulatory_region) {
      $type .=", ". $tvari_obj->splice_site;
      $type .= $tvari_obj->regulatory_region;
    }
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

=head2 ld_pops_for_snp

  Arg         : none
  Description : gets an LDfeature container for this SNP and calls all the populations on this
  Return type : array ref of population IDs

=cut

sub ld_pops_for_snp {
  my $self = shift;
  my @vari_mappings = @{ $self->get_variation_features };
  return [] unless @vari_mappings;
  
  my @pops;
  foreach ( @vari_mappings ) {
    my $ldcontainer = $_->get_all_LD_values;
    push @pops, @{$ldcontainer->get_all_populations};

  }
  return \@pops;
}


=head2 find_location

  Arg[1]      : 
  Example     : my $data = $object->find_location
  Description : returns the genomic location for the current slice
  Return type : hash of data

=cut

sub find_location {
  my $self = shift;
  my $width = shift || $self->param('w') || 50000;
  unless ( $self->{'_slice'} ) {
    $self->_get_slice($width);
  }

  my $slice = $self->{'_slice'};
  return {} unless $slice;
  return $slice->name;
}


=head2 pop_obj_from_id

  Arg[1]      : Population ID
  Example     : my $pop_name = $object->pop_obj_from_id($pop_id);
  Description : returns population name for the given population dbID
  Return type : population object

=cut

sub pop_obj_from_id {
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

=head2 get_default_pop_name

  Arg[1]      : 
  Example     : my $pop_id = $object->get_default_pop_name
  Description : returns population id for default population for this species
  Return type : population dbID

=cut

sub get_default_pop_name {
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
