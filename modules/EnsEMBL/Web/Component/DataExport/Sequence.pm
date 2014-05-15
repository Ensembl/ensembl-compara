=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::DataExport::Sequence;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::DataExport);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {

  my $self  = shift;
  my $hub   = $self->hub;

  ### Options for sequence output
  my $strands = [
        { value => 'feature', caption => 'Feature strand' },
        { value => '1',       caption => 'Forward strand' },
        { value => '-1',      caption => 'Reverse strand' }
      ];
  my $genomic = [
          { value => 'unmasked',     caption => 'Unmasked' },
          { value => 'soft_masked',  caption => 'Repeat Masked (soft)' },
          { value => 'hard_masked',  caption => 'Repeat Masked (hard)' },
          { value => '5_flanking',   caption => "5' Flanking sequence" },
          { value => '3_flanking',   caption => "3' Flanking sequence" },
          { value => '5_3_flanking', caption => "5' and 3' Flanking sequences" }
      ];
  my $checklist = [
        { 'value' => 'cdna',       'caption' => 'cDNA',             'checked' => '1' },
        { 'value' => 'coding',     'caption' => 'Coding sequence',  'checked' => '1' },
        { 'value' => 'peptide',    'caption' => 'Peptide sequence', 'checked' => '1' },
        { 'value' => 'utr5',       'caption' => "5' UTR",           'checked' => '1' },
        { 'value' => 'utr3',       'caption' => "3' UTR",           'checked' => '1' },
        { 'value' => 'exon',       'caption' => 'Exons',            'checked' => '1' },
        { 'value' => 'intron',     'caption' => 'Introns',          'checked' => '1' },
      ];

  my $settings = {
        'strand' => {
            'label'   => 'Strand', 
            'type'    => 'DropDown', 
            'values'  => $strands 
        },
        'flank5_display' => {
            'label'     => "5' Flanking sequence (upstream)",  
            'type'      => 'NonNegInt',  
            'defaults'  => {'rtf' => 600},
        },
        'flank3_display' => { 
            'label'     => "3' Flanking sequence (downstream)", 
            'type'      => 'NonNegInt',  
            'defaults'  => {'rtf' => 600},
        },
        'genomic' => {
            'label' => 'Genomic',   
            'type'  => 'DropDown', 
            'values' => $genomic,
        },
        'extra' => {
          'type'      => 'Checklist',
          'label'     => 'Sequence(s)',
          'values'    => $checklist,
          'selectall' => 1,
        },
  };

  ## Options per format
  my $format_settings = {
    'rtf'   => {'hidden' => [qw(flank5_display flank3_display)]},
    'fasta' => {'shown'  => [qw(strand flank5_display flank3_display genomic extra)]},
  };

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form();

  ## TODO Needs to be configurable with JavaScript!
  my $format    = 'rtf';
  my $fields    = $format_settings->{$format};
  my $legend    = $fields->{'shown'} ? 'Settings' : '';
  my $fieldset  = $form->add_fieldset($legend);

  ## Add custom fields for this data type and format
  while (my($key, $field_array) = each (%$fields)) {
    foreach (@$field_array) {
      my $field_info = $settings->{$_};
      $field_info->{'name'} = $_;
      $field_info->{'value'}  = $field_info->{'defaults'}{$format} if $field_info->{'defaults'}{$format};
      delete $field_info->{'defaults'};
      if ($key eq 'hidden') {
        $field_info->{'type'}   = 'Hidden';
        $fieldset->add_hidden($field_info);
      }
      else {
        $fieldset->add_field($field_info);
      }
    }
  }

  $fieldset->add_button({
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Export',
  });

  return $form->render;
}

1;
