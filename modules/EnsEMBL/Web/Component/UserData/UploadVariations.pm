=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::UserData::UploadVariations;

use strict;
use warnings;

no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Select File to Upload';
}

sub content {
  my $self = shift;
  my $hub = $self->hub;

  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;
  my $action_url = $hub->species_path($current_species)."/UserData/CheckConvert";
  my $variation_limit = 750;

  my $html;
  my $form = $self->modal_form('select', $action_url,);
  $form->add_notes({ 
    'heading'=>'Variant Effect Predictor:',
    'text'=>qq(
      <img src="/i/vep_logo_sm.png" style="float:right" alt="logo" />
      <p>This tool takes a list of variant positions and
      alleles, and predicts the effects of each of these on overlapping
      transcripts and regulatory regions annotated in Ensembl. The tool accepts
      substitutions, insertions and deletions as input, see <a
      href="/info/docs/tools/vep/vep_formats.html" target="_blank">data
      formats</a>.</p>
      
      <p>Upload is limited to $variation_limit variants; lines after the limit
      will be ignored. Users with more than $variation_limit variations can
      split files into smaller chunks, use the standalone <a
      href="/info/docs/tools/vep/script/index.html"
      target="_blank">perl script</a> or the <a
      href="/info/docs/api/variation/variation_tutorial.html#Consequence"
      target="_blank">variation API</a>. See also <a
      href="/info/docs/tools/vep/index.html" target="_blank">full
      documentation</a></p>
      
      <p><b>NB:</b> Ensembl now by default uses Sequence Ontology terms to
      describe variation consequences. See <a
      href="/info/genome/variation/predicted_data.html#consequences">this page</a>
      for details</p>
  )});
  my $subheader = 'Input file';

   ## Species now set automatically for the page you are on
  my @species;
  
  foreach my $sp ($hub->species_defs->valid_species) {
    push @species, {'value' => $sp, 'name' => $hub->species_defs->species_label($sp, 1).': '.$hub->species_defs->get_config($sp, 'ASSEMBLY_VERSION')};
  }
  @species = sort {$a->{'name'} cmp $b->{'name'}} @species;

  $form->add_element( type => 'Hidden', name => 'consequence_mapper', 'value' => 1);
  $form->add_element('type' => 'SubHeader', 'value' => $subheader);
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'species',
      'label'   => "Species",
      'values'  => \@species,
      'value'   => $current_species,
      'select'  => 'select',
      'width'   => '300px',
  );

  my $example = qq(1  881907  881906  -/C  +
5  140532  140532  T/C  +);

  $form->add_element( type => 'Hidden', name => 'variation_limit', 'value' => $variation_limit);
  $form->add_element( type => 'String', name => 'name', label => 'Name for this data (optional)' );
  $form->add_element( type => 'Text', name => 'text', label => 'Paste data', value => $example );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'URL',  name => 'url',  label => 'or provide file URL', size => 30 );
  
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'format',
      'label'   => "Input file format",
      'values'  => [
        { value => 'snp',     name => 'Ensembl default'     },
        { value => 'vep_vcf', name => 'VCF'                 },
        { value => 'pileup',  name => 'Pileup'              },
        { value => 'id',      name => 'Variant identifiers' },
        { value => 'id',      name => 'HGVS notations'      },
      ],
      'value'   => 'snp',
      'select'  => 'select',
  );
  
  
  ## OPTIONS
  $form->add_element('type' => 'SubHeader', 'value' => 'Options');
  
  $form->add_element(
      'type'    => 'RadioGroup',
      'name'    => 'core_type',
      'label'   => "Transcript database to use",
      'values'  => [
        { value => 'core',          name => 'Ensembl transcripts'          },
        { value => 'otherfeatures', name => 'RefSeq and other transcripts' },
      ],
      'value'   => 'core',
      'select'  => 'select',
  );
  
  $form->add_element(
    type  => 'CheckBox',
    name  => "regulatory",
    label => "Get regulatory region consequences (human and mouse only)",
    value => 'yes',
    selected => 1
  );
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of consequences to display',
    name   => 'terms',
    values => [
      { value => 'SO',       name => 'Sequence Ontology terms' },
      { value => 'display',  name => 'Old Ensembl terms'       },
    ],
    value  => 'SO',
    select => 'select',
  );  
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Check for existing co-located variants',
    name   => 'check_existing',
    values => [
      { value => 'no',     name => 'No'                      },
      { value => 'yes',    name => 'Yes'                     },
      { value => 'allele', name => 'Yes and compare alleles' },
    ],
    value  => 'yes',
    select => 'select',
  );
  
  $form->add_element(
    type   => 'CheckBox',
    label  => 'Get 1000 Genomes global allele frequency for existing variants',
    name   => 'gmaf',
    value  => 'yes',
    selected => 1,
  );
  
  $form->add_element(
    type  => 'CheckBox',
    name  => "coding_only",
    label => "Return results for variants in coding regions only",
    value => 'yes',
    selected => 0
  );
  
  $form->add_element(
    type  => 'CheckBox',
    name  => "symbol",
    label => "Show gene symbols (e.g. HGNC) where available",
    value => 'yes',
    selected => 0
  );
  
  $form->add_element(
    type  => 'CheckBox',
    name  => "protein",
    label => "Show Ensembl protein identifiers where available",
    value => 'yes',
    selected => 0
  );
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Show HGVS identifiers for variants where available',
    name   => 'hgvs',
    values => [
      { value => 'no',             name => 'No'                           },
      { value => 'coding',         name => 'Coding sequence only'         },
      { value => 'protein',        name => 'Protein sequence only'        },
      { value => 'coding_protein', name => 'Coding and protein sequence'  },
    ],
    value  => 'no',
    select => 'select',
  );
  
  $form->add_element('type' => 'SubHeader', 'value' => 'Missense SNP predictions (species limited)');
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'SIFT predictions (chicken, cow, dog, human, mouse, pig, rat and zebrafish)',
    name   => 'sift',
    values => [
      { value => 'no',    name => 'No'                   },
      { value => 'pred',  name => 'Prediction only'      },
      { value => 'score', name => 'Score only'           },
      { value => 'both',  name => 'Prediction and score' },
    ],
    value  => 'no',
    select => 'select',
  );  
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'PolyPhen predictions (human)',
    name   => 'polyphen',
    values => [
      { value => 'no',    name => 'No'                   },
      { value => 'pred',  name => 'Prediction only'      },
      { value => 'score', name => 'Score only'           },
      { value => 'both',  name => 'Prediction and score' },
    ],
    value  => 'no',
    select => 'select',
  );
  
  
  $form->add_element('type' => 'SubHeader', 'value' => 'Frequency filtering of existing variants (human only)');
  
  $form->add_element(
    type  => 'CheckBox',
    name  => "check_frequency",
    label => "Filter variants by frequency",
    value => 'yes',
    selected => 0,
    notes => '<strong>NB:</strong> Enabling frequency filtering may be slow for large datasets. The default options will filter out common variants found by the 1000 Genomes project.',
  );
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Filter',
    name   => 'freq_filter',
    values => [
      { value => 'exclude', name => 'Exclude' },
      { value => 'include', name => 'Include only' },
    ],
    value  => 'exclude',
    select => 'select',
  ); 
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    #label  => '',
    name   => 'freq_gt_lt',
    values => [
      { value => 'gt', name => 'variants with MAF greater than' },
      { value => 'lt', name => 'variants with MAF less than'    },
    ],
    value  => 'gt',
    select => 'select',
  ); 
  
  $form->add_element(
    type  => 'String',
    name  => 'freq_freq',
    value => '0.01',
    max   => 1,
  );
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    #label  => '',
    name   => 'freq_pop',
    values => [
      { value => '1kg_all', name => 'in 1000 genomes (1KG) combined population' },
      { value => '1kg_afr', name => 'in 1KG African combined population'        },
      { value => '1kg_amr', name => 'in 1KG American combined population'       },
      { value => '1kg_asn', name => 'in 1KG Asian combined population'          },
      { value => '1kg_eur', name => 'in 1KG European combined population'       },
      { value => '-',       name => '-----'                                     },
      { value => '1kg_asw', name => 'in 1KG ASW population'                     },
      { value => '1kg_ceu', name => 'in 1KG CEU population'                     },
      { value => '1kg_chb', name => 'in 1KG CHB population'                     },
      { value => '1kg_chs', name => 'in 1KG CHS population'                     },
      { value => '1kg_clm', name => 'in 1KG CLM population'                     },
      { value => '1kg_fin', name => 'in 1KG FIN population'                     },
      { value => '1kg_gbr', name => 'in 1KG GBR population'                     },
      { value => '1kg_ibs', name => 'in 1KG IBS population'                     },
      { value => '1kg_jpt', name => 'in 1KG JPT population'                     },
      { value => '1kg_lwk', name => 'in 1KG LWK population'                     },
      { value => '1kg_mxl', name => 'in 1KG MXL population'                     },
      { value => '1kg_pur', name => 'in 1KG PUR population'                     },
      { value => '1kg_tsi', name => 'in 1KG TSI population'                     },
      { value => '1kg_yri', name => 'in 1KG YRI population'                     },
      { value => '-',       name => '-----'                                     },
      { value => 'hap_asw', name => 'in HapMap ASW'                             },
      { value => 'hap_ceu', name => 'in HapMap CEU'                             },
      { value => 'hap_chb', name => 'in HapMap CHB'                             },
      { value => 'hap_chd', name => 'in HapMap CHD'                             },
      { value => 'hap_gih', name => 'in HapMap GIH'                             },
      { value => 'hap_jpt', name => 'in HapMap JPT'                             },
      { value => 'hap_lwk', name => 'in HapMap LWK'                             },
      { value => 'hap_mex', name => 'in HapMap MEX'                             },
      { value => 'hap_mkk', name => 'in HapMap MKK'                             },
      { value => 'hap_tsi', name => 'in HapMap TSI'                             },
      { value => 'hap_yri', name => 'in HapMap YRI'                             },
      { value => 'hap',     name => 'in any HapMap population'                  },
      { value => '-',       name => '-----'                                     },
      { value => 'any',     name => 'any 1KG phase 1 or HapMap population'      },
    ],
    value  => '1kg_all',
    select => 'select',
  ); 
  
  
  $form->add_element('type' => 'SubHeader', 'value' => ' ');
  
  my $render = $form->render;

  my @split = split /fieldset>/, $render;
  
  for my $i(0..$#split) {
    my $chunk = $split[$i];
    
    next unless $chunk =~ /filtering/;
    
    #warn $chunk;
    
    my ($count, $pos);
    while($chunk =~ m/<\/div>/g) {
      next unless ++$count == 2;
      $pos = pos $chunk;
    }
    
    my ($chunk1, $chunk2);
    $chunk1 = substr($chunk, 0, $pos);
    $chunk2 = substr($chunk, $pos);
    
    #$chunk =~ s/<\/div><\/div><div class="form-field"><div class="ff-right">//g;
    $chunk2 =~ s/<\/div><div class="form-field">//g;
    $chunk2 =~ s/ class="ff-right"//g;
    $chunk2 =~ s/div/span/g;
    $chunk2 =~ s/<span>/<span style="margin-right:2px">/g;
    $chunk2 =~ s/ ftext"/" style="width: 40px"/;
    $chunk2 =~ s/ class="fselect"//g;
    $chunk2 =~ s/ class="ff-label"/ style="margin-right:10px"/;
    $chunk2 =~ s/^<span/<div/;
    $chunk2 =~ s/span><\/$/div><br\/><\//;
    
    #warn $chunk2;
    
    $split[$i] = $chunk1.$chunk2;
  }
  
  $render = join "fieldset>", @split;

  $html .= $render;
  return $html;
}


1;
