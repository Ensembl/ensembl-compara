package EnsEMBL::Web::Component::UserData;

## Placeholder - no generic methods needed as yet

use base qw(EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

sub get_assemblies {
### Tries to identify coordinate system from file contents
### If on chromosomal coords and species has multiple assemblies,
### return assembly info
  my ($self, $species) = @_;

  my @assemblies = split(',', $self->object->species_defs->get_config($species, 'CURRENT_ASSEMBLIES'));
  return \@assemblies;
}

sub output_das_text {
  my ( $self, $form, @sources ) = @_;
  map {
    $form->add_element( 'type'    => 'Information',
                        'classes'  => ['no-bold'],
                        'value'   => sprintf '<strong>%s</strong><br />%s<br /><a href="%s">%3$s</a>',
                                           $_->label,
                                           $_->description,
                                           $_->homepage );
  } @sources;
}

sub consequence_table {
  my ($self, $filename) = @_;
  my $object = $self->object;
  my $consequence_data = {};

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
  $table->add_columns(
    { 'key' => 'var',         'title' =>'Uploaded Variation', 'align' => 'center'},
    { 'key' => 'location',    'title' =>'Location', 'align' => 'center' },
    { 'key' => 'gene',        'title' =>'Gene', 'align' => 'center'      },
    { 'key' => 'trans',       'title' =>'Transcript', 'align' => 'center'},
    { 'key' => 'con',         'title' =>'Consequence', 'align' => 'center'},
    { 'key' => 'cdna_pos',    'title' =>'Position in cDNA', 'align' => 'center'},
    { 'key' => 'prot_pos',    'title' =>'Position in protein', 'align' => 'center'},
    { 'key' => 'aa',          'title' =>'Amino acid change', 'align' => 'center'},
    { 'key' => 'snp',         'title' =>'Corresponding Variation', 'align' => 'center'}
  );

  my $transcript_variation_adaptor;
  my %species_dbs =  %{$object->species_defs->get_config($object->param('species'), 'databases')};
  if (exists $species_dbs{'DATABASE_VARIATION'} ){
    $transcript_variation_adaptor = $object->get_adaptor('get_TranscriptVariationAdaptor', 'variation', $object->param('species'));
  } else  {
    $transcript_variation_adaptor  = Bio::EnsEMBL::Variation::DBSQL::TranscriptVariationAdaptor->new_fake($object->param('species'));
  }

  my $slice_adaptor = $object->get_adaptor('get_SliceAdaptor', 'core', $object->param('species'));
  my $gene_adaptor = $object->get_adaptor('get_GeneAdaptor', 'core', $object->param('species'));
  my %slices;
  my @table_rows;
  my %data = %{$consequence_data};

  foreach my $feature_set (keys %data) {
    my $var_features = $data{$feature_set};
    # get the consequences
    # note that we don't need to get the return value since the transcript
    # variation objects are attached to the VFs in the array in the calculation
    $transcript_variation_adaptor->fetch_all_by_VariationFeatures($var_features);
    foreach my $var_feature (@{$var_features}){
      my $transcript_variations = $var_feature->get_all_TranscriptVariations();
      foreach my $tv (@{$transcript_variations}){
        foreach my $consequence_string (@{$tv->consequence_type}){
          my $row = {};

          my $location = $var_feature->seq_region_name .":". $var_feature->seq_region_start;
          unless ($var_feature->seq_region_start == $var_feature->seq_region_end){
            $location .= '-' . $var_feature->seq_region_end;
          }
          my $url_location = $var_feature->seq_region_name .":". ($var_feature->seq_region_start -500) .
            "-".($var_feature->seq_region_end + 500);
          my $location_url = $object->_url({
            'type'             => 'Location',
            'action'           => 'View',
            'r'                =>  $url_location,
            'contigviewbottom' => 'variation_feature_variation=normal',
          });

          my $transcript_string = "N/A";
          my $gene_string = "N/A";

          if ($tv->transcript){
            my $transcript = $tv->transcript->stable_id;
            my $gene = $gene_adaptor->fetch_by_transcript_id($tv->transcript->dbID);
            my $gene_id = $gene->stable_id;

            my $transcript_url = $object->_url({
              'type'   => 'Transcript',
              'action' => 'Summary',
              't'      =>  $transcript,
            });
            $transcript_string = qq(<a href="$transcript_url">$transcript</a>);

            my $gene_url = $object->_url({
              'type'   => 'Gene',
              'action' => 'Summary',
              'g'      =>  $gene_id,
            });
            $gene_string = qq(<a href="$gene_url">$gene_id</a>);
          }

          my $translation_position = "N/A";
          if ($tv->translation_start){
            $translation_position = $tv->translation_start;
            unless ($tv->translation_start == $tv->translation_end){
              if ($tv->translation_end < $tv->translation_start){
                $translation_position = $tv->translation_end .'-' .$translation_position;
              } else {
                $translation_position .= '-'. $tv->translation_end;
              }
            }
          }

          my $cdna_position = "N/A";
          if ($tv->cdna_start){
            $cdna_position = $tv->cdna_start;
            unless ($tv->cdna_start == $tv->cdna_end){
              if ($tv->cdna_end < $tv->cdna_start){
                $cdna_position = $tv->cdna_end .'-' .$cdna_position;
              } else {
                $cdna_position .= '-'. $tv->cdna_end;
              }
            }
          }

          my $snp_string  = "N/A";
          my $slice_name = $var_feature->seq_region_name .":" . $location;
          if (exists $slices{$slice_name} ){
            $snp_string = $slices{$slice_name};
          }
          else {
            my $temp_slice;
            if ($var_feature->start <= $var_feature->end){
              eval { $temp_slice = $slice_adaptor->fetch_by_region("chromosome",
                $var_feature->seq_region_name, $var_feature->seq_region_start,
                $var_feature->seq_region_end); };
              if(!defined($temp_slice)) {
                $temp_slice = $slice_adaptor->fetch_by_region(undef,
                  $var_feature->seq_region_name, $var_feature->seq_region_start,
                  $var_feature->seq_region_end);
              }
            } else {
              eval {
                $temp_slice = $slice_adaptor->fetch_by_region("chromosome",
                $var_feature->seq_region_name, $var_feature->seq_region_end,
                $var_feature->seq_region_start); };
              if(!defined($temp_slice)) {
                $temp_slice = $slice_adaptor->fetch_by_region(undef,
                $var_feature->seq_region_name, $var_feature->seq_region_end,
                $var_feature->seq_region_start);
              }
            }
            my $snp_id;
            foreach my $vf (@{$temp_slice->get_all_VariationFeatures()}){
              next unless ($vf->seq_region_start == $var_feature->seq_region_start) &&
              ($vf->seq_region_end == $var_feature->seq_region_end);
              $snp_id = $vf->variation_name;
              last if defined($snp_id);
            }

            if ($snp_id =~/^\w/ ){
              my $snp_url =  $object->_url({
                'type'   => 'Variation',
                'action' => 'Summary',
                'v'      =>  $snp_id,
              });
              $snp_string = qq(<a href="$snp_url">$snp_id</a>);
            }
            $slices{$slice_name} = $snp_string;
          }

          $row->{'var'}       = $var_feature->variation_name;
          $row->{'location'}  = qq(<a href="$location_url">$location</a>);
          $row->{'gene'}      = $gene_string;
          $row->{'trans'}     = $transcript_string;
          $row->{'con'}       = $consequence_string;
          $row->{'cdna_pos'}  = $cdna_position;
          $row->{'prot_pos'}  = $translation_position;
          $row->{'aa'}        = $tv->pep_allele_string || 'N/A';
          $row->{'snp'}       = $snp_string;

          push (@table_rows, $row);
        }
      }
    }
  }

  foreach my $row ( sort { $a->{'var'} cmp $b->{'var'} } @table_rows){
     $table->add_row($row);
  }

  return $table;
}

1;

