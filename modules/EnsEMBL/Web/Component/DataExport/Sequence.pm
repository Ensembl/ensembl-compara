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


  my $settings = [
        [ 'strand',     'Strand',           'DropDown',  {'fasta' => ''}, $strands ],
        [ 'upstream',   "5' Flanking sequence (upstream)",   'PosInt', {'rtf' => 600} ],
        [ 'downstream', "3' Flanking sequence (downstream)", 'PosInt', {'rtf' => 600} ],
        [ 'genomic',    'Genomic',          'DropDown',  {'fasta' => ''}, $genomic ],
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


  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form();

  my $fieldset  = $form->add_fieldset('Settings');

  ## TODO Needs to be configurable with JavaScript
  my $format = 'fasta';
  foreach (@$settings) {
    my $params = {
      'name'    => 'config_'.$_->[0],
      'label'   => $_->[1],
      'type'    => $_->[2],
      'value'   => $_->[3]{$format},
    };
    $params->{'values'} = $_->[4] if $_->[2] eq 'DropDown';
    $fieldset->add_field([$params]);
  }
  $fieldset->add_field([{
      'name'      => 'config_extra',
      'type'      => 'Checklist',
      'label'     => 'Sequence(s)',
      'values'    => $checklist,
      'selectall' => 1,
  }]);


  $fieldset->add_button({
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Export',
  });

  return $form->render;
}

1;
