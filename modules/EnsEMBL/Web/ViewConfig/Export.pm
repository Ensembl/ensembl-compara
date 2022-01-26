=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Export;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## Abstract method implementation
  my $self      = shift;
  my $misc_sets = $self->species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'};
  my $defaults  = {};

  $defaults->{'output'}        = 'fasta';
  $defaults->{'strand'}        = $self->hub->action eq 'Location' ? 'forward' : 'feature';
  $defaults->{$_}              = 0 for qw(flank5_display flank3_display);
  $defaults->{"fasta_$_"}      = 'yes' for qw(cdna coding peptide utr5 utr3 exon intron);
  $defaults->{"gff3_$_"}       = 'yes' for qw(gene transcript exon intron cds);
  $defaults->{"bed_$_"}        = 'yes'  for qw(variation similarity repeat genscan gene userdata);
  $defaults->{"gtf_$_"}        = 'yes' for qw(similarity repeat genscan contig variation marker gene vegagene estgene);
#  $defaults->{"psl_$_"}       = 'yes' for qw();
  $defaults->{"phyloxml_$_"}   = 'yes' for qw(cdna aligned);
  $defaults->{"phylopan_$_"}   = 'yes' for qw(cdna aligned);
  $defaults->{"phyloxml_$_"}   = 'no'  for qw(no_sequences);
  $defaults->{"phylopan_$_"}   = 'no'  for qw(no_sequences);
  $defaults->{'fasta_genomic'} = 'unmasked';

  foreach my $f (qw(csv tab gff)) {
    $defaults->{$f . '_' . $_} = 'yes' for qw(similarity repeat genscan variation gene);
    $defaults->{gff_probe} = 'yes' if ($f eq 'gff');  #had to put this one in here because i dont want csv or tab to have probe features, only gff

    next if $f eq 'gff';

    $defaults->{$f . '_miscset_' . $_} = 'yes' for keys %$misc_sets;
  }

  foreach my $f (qw(embl genbank)) {
    $defaults->{$f . '_' . $_} = 'yes' for qw(similarity repeat genscan contig variation marker gene vegagene estgene);
  }

  $self->set_default_options($defaults);
}

sub form_fields {}
sub field_order {}

sub init_form {
  my ($self, $object) = @_;

  my $hub      = $self->hub;
  my $function = $hub->function;

  return if $function !~ /Location|Gene|Transcript|LRG|Variation/;

  my $action              = $hub->action;
  my $config              = $object->config;
  my $slice               = $object->slice;
  my $form_action         = $hub->url({ action => 'Form', function => $function }, 1);
  my %gene_markup_options = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  my $form                = $self->form;

  $form->set_attributes({
    action => $form_action->[0],
    id     => 'export_configuration',
    class  => ' export',
    method => 'get'
  });

  $self->add_fieldset;

  $self->add_form_element({
    type  => 'Hidden',
    name  => 'panel_type',
    class => 'panel_type',
    value => 'Exporter'
  });

  foreach (keys %{$form_action->[1]}) {
    $self->add_form_element({
      type  => 'Hidden',
      name  => $_,
      value => $form_action->[1]->{$_}
    });
  }

  if($function eq 'Location') {
    $self->add_form_element({
      type  => 'NoEdit',
      name  => 'location_to_export',
      label => 'Location to export',
      value => $slice->name
    });
  }
  if ($function eq 'Gene') {
    $self->add_form_element({
      type  => 'NoEdit',
      name  => 'gene_to_export',
      label => 'Gene to export',
      value => $hub->core_object('gene')->long_caption(1)
    });
  } elsif ($function eq 'Transcript') {
    $self->add_form_element({
      type  => 'NoEdit',
      name  => 'transcript_to_export',
      label => 'Transcript to export',
      value => $hub->core_object('transcript')->long_caption(1)
    });
  } elsif ($function eq 'Variation') {
    $self->add_form_element({
      type  => 'NoEdit',
      name  => 'variation_to_export',
      label => 'Variation to export',
      value => $hub->core_object('variation')->name,
    });
  }

  $self->add_fieldset;

  my @output_values;

  foreach my $c (sort keys %$config) {
    foreach (@{$config->{$c}->{'formats'}}) {
      push (@output_values, { group => $config->{$c}->{'label'}, value => $_->[0], caption => $_->[1] });
    }
  }

  if (scalar @output_values) {
    $self->add_form_element({
      type     => 'DropDown',
      select   => 'select',
      required => 'yes',
      name     => 'output',
      class    => '_stt',
      label    => 'Output',
      values   => \@output_values
    });
  }

  if ($function eq 'Location') {
    my $loc_size = scalar @{$hub->species_defs->ENSEMBL_CHROMOSOMES||[]} ? 4 : 20;
    $form->add_field({
      label     => 'Select location',
      inline    => 1,
      elements  => [
        { type => 'string',   size => $loc_size, value => $slice->seq_region_name, name => 'new_region', required => 1, class => "as-param" },
        { type => 'posint',   size => 8, value => $slice->start,           name => 'new_start',  required => 1, class => "as-param" },
        { type => 'posint',   size => 8, value => $slice->end,             name => 'new_end',    required => 1, class => "as-param" },
        { type => 'dropdown', size => 1, value => $self->get('strand'),    name => 'strand',     values => [{ value => 1, caption => 1 }, { value => -1, caption => -1 }] },
      ],
    });
  } else {
    $self->add_form_element({
      type     => 'DropDown',
      select   => 'select',
      required => 'yes',
      name     => 'strand',
      label    => 'Strand',
      values   => [
        { value => 'feature', caption => 'Feature strand' },
        { value => '1',       caption => 'Forward strand' },
        { value => '-1',      caption => 'Reverse strand' }
      ]
    });
  }

  $self->add_form_element($gene_markup_options{'flank5_display'});
  $self->add_form_element($gene_markup_options{'flank3_display'});

  $self->add_form_element({
    type  => 'Submit',
    class => 'submit',
    name  => 'next',
    value => 'Next >',
  });

  foreach my $c (sort keys %$config) {
    next unless $config->{$c}->{'params'};

    foreach my $f (@{$config->{$c}->{'formats'}}) {
      $self->add_fieldset("Options for $f->[1]")->set_attribute('class', "_stt_$f->[0]");

      if ($f->[0] eq 'fasta') {
        my $genomic = [
          { value => 'unmasked',     caption => 'Unmasked' },
          { value => 'soft_masked',  caption => 'Repeat Masked (soft)' },
          { value => 'hard_masked',  caption => 'Repeat Masked (hard)' },
          { value => '5_flanking',   caption => "5' Flanking sequence" },
          { value => '3_flanking',   caption => "3' Flanking sequence" },
          { value => '5_3_flanking', caption => "5' and 3' Flanking sequences" }
        ];

        push @$genomic, { value => 'off', caption => 'None' } unless $action eq 'Location';

        $self->add_form_element({
          type     => 'DropDown',
          select   => 'select',
          required => 'yes',
          name     => 'fasta_genomic',
          label    => 'Genomic',
          values   => $genomic
        });
      }

      ## If the fieldset has many checkboxes, provide a select/deselect all option
      my $params = $config->{$c}->{'params'} || [];
      my $checkbox_count;
      foreach (@$params) {
        $checkbox_count++ if (!$config->{$c}{'type'} || $config->{$c}{'type'} eq 'CheckBox');
      }
      if ($checkbox_count > 3) {
        $self->add_form_element({
                              'type'        => 'Checkbox',
                              'name'        => 'select_all',
                              'label'       => 'Select/deselect all',
                              'value'       => 'yes',
                              'field_class' => 'select_all',
                            });
      }

      foreach (@{$config->{$c}->{'params'}}) {
        next unless defined $self->get("$f->[0]_$_->[0]");
        next if $_->[2] eq '0'; # Next if 0, but not if undef. Where is my === operator, perl?

        $self->add_form_element({
          type  => $config->{$c}->{'type'} || 'CheckBox',
          label => $_->[1],
          name  => "$f->[0]_$_->[0]",
          value => 'yes'
        });
      }
    }
  }
}

1;
