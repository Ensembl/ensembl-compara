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
  my $object = $self->object;

  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $object->data_species;
  my $action_url = $object->species_path($current_species)."/UserData/CheckConvert";
  my $variation_limit = 750;

  my $html;
  my $form = $self->modal_form('select', $action_url,);
  $form->add_notes({ 
    'heading'=>'Variant Effect Predictor:',
    'text'=>qq(
      <p class="space-below">(Formerly SNP Effect Predictor). This tool takes a
      list of variant positions and alleles, and predicts the effects of each
      of these on any overlapping features annotated in Ensembl. The
      tool accepts substitutions, insertions and deletions as input,
      uploaded as a list of <a href="/info/website/upload/var.html"
      target="_blank">tab separated values</a>, <a
      href="http://www.1000genomes.org/wiki/Analysis/Variant%20Call%20Format/vcf-variant-call-format-version-40"
      target="_blank">VCF</a> or Pileup format input.</p>
      
      <p>Upload is limited to $variation_limit variants; lines after the limit
      will be ignored. Users with more than $variation_limit variations can
      split files into smaller chunks, use the standalone <a
      href="ftp://ftp.ensembl.org/pub/misc-scripts/Variant_effect_predictor_2.0/"
      target="_blank">perl script</a> or the <a
      href="/info/docs/api/variation/variation_tutorial.html#Consequence"
      target="_blank">variation API</a>.</p>
  )});
  my $subheader = 'Upload file';

   ## Species now set automatically for the page you are on
  my @species;
  foreach my $sp ($object->species_defs->valid_species) {
    push @species, {'value' => $sp, 'name' => $object->species_defs->species_label($sp, 1)};
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
  );
  $form->add_element( type => 'Hidden', name => 'variation_limit', 'value' => $variation_limit);
  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );
  $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'URL',  name => 'url',  label => 'or provide file URL', size => 30 );
  
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'format',
      'label'   => "Input file format",
      'values'  => [
        { value => 'snp',     name => 'Ensembl default' },
        { value => 'vep_vcf', name => 'VCF'             },
        { value => 'pileup',  name => 'Pileup'          },
      ],
      'value'   => 'snp',
      'select'  => 'select',
  );
  
  
  ## OPTIONS
  $form->add_element('type' => 'SubHeader', 'value' => 'Options');
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of consequences to display',
    name   => 'consequence_format',
    values => [
      { value => 'display',  name => 'Ensembl terms'           },
      { value => 'SO',       name => 'Sequence Ontology terms' },
      { value => 'NCBI',     name => 'NCBI terms'              },
    ],
    value  => 'ensembl',
    select => 'select',
  );  
  
  $form->add_element(
    type  => 'CheckBox',
    name  => "check_existing",
    label => "Check for existing co-located variants",
    value => 'yes',
    selected => 1
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
    name  => "hgnc",
    label => "Show HGNC identifier for genes where available",
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
  
  
  $form->add_element('type' => 'SubHeader', 'value' => 'Non-synonymous SNP predictions (human only)');
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'SIFT predictions',
    name   => 'sift',
    values => [
      { value => 'no',         name => 'No'                   },
      { value => 'pred',       name => 'Prediction only'      },
      { value => 'score',      name => 'Score only'           },
      { value => 'pred_score', name => 'Prediction and score' },
    ],
    value  => 'no',
    select => 'select',
  );  
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'PolyPhen predictions',
    name   => 'polyphen',
    values => [
      { value => 'no',         name => 'No'                   },
      { value => 'pred',       name => 'Prediction only'      },
      { value => 'score',      name => 'Score only'           },
      { value => 'pred_score', name => 'Prediction and score' },
    ],
    value  => 'no',
    select => 'select',
  );
  
  $form->add_element(
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Condel consensus (SIFT/PolyPhen) predictions',
    name   => 'condel',
    values => [
      { value => 'no',         name => 'No'                   },
      { value => 'pred',       name => 'Prediction only'      },
      { value => 'score',      name => 'Score only'           },
      { value => 'pred_score', name => 'Prediction and score' },
    ],
    value  => 'no',
    select => 'select',
  );

  $html .= $form->render;
  return $html;
}


1;
