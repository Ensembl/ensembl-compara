# $Id$

package EnsEMBL::Web::ViewConfig::Export;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self      = shift;
  my $misc_sets = $self->species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'};
  my $defaults  = {};
  
  $defaults->{'output'}        = 'fasta';
  $defaults->{'strand'}        = $self->hub->action eq 'Location' ? 'forward' : 'feature';
  $defaults->{$_}              = 0 for qw(flank5_display flank3_display);
  $defaults->{"fasta_$_"}      = 'yes' for qw(cdna coding peptide utr5 utr3 exon intron);
  $defaults->{"gff3_$_"}       = 'yes' for qw(gene transcript exon intron cds);
  $defaults->{"bed_$_"}        = 'yes' for qw(userdata description);
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
  
  $self->set_defaults($defaults);
}

sub form {
  my ($self, $object) = @_;
  
  my $hub      = $self->hub;
  my $function = $hub->function;
  
  return if $function !~ /Location|Gene|Transcript|LRG|Variation/;
  
  my $action              = $hub->action;
  my $config              = $object->config;
  my $slice               = $object->slice;
  my $form_action         = $hub->url({ action => 'Form', function => $function }, 1);
  my %gene_markup_options = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  my $form                = $self->get_form;
  
  $form->set_attributes({
    action => $form_action->[0],
    id     => 'export_configuration',
    class  => ' export',
    method => 'get'
  });
    
  $self->add_fieldset;
  
  $self->add_form_element({
    type    => 'Hidden',
    name    => 'panel_type',
    classes => [ 'panel_type' ],
    value   => 'Exporter'
  });
  
  foreach (keys %{$form_action->[1]}) {
    $self->add_form_element({
      type  => 'Hidden',
      name  => $_,
      value => $form_action->[1]->{$_}
    });
  }
  
  $self->add_form_element({
    type  => 'NoEdit',
    name  => 'location_to_export',
    label => 'Location to export',
    value => $slice->name
  });
  
  if ($function eq 'Gene') {
    $self->add_form_element({
      type  => 'NoEdit',
      name  => 'gene_to_export',
      label => 'Gene to export',
      value => $hub->core_objects->{'gene'}->long_caption
    });
  } elsif ($function eq 'Transcript') {    
    $self->add_form_element({
      type  => 'NoEdit',
      name  => 'transcript_to_export',
      label => 'Transcript to export',
      value => $hub->core_objects->{'transcript'}->long_caption
    });
  } elsif ($function eq 'Variation') {
    $self->add_form_element({
      type  => 'NoEdit',
      name  => 'variation_to_export',
      label => 'Variation to export',
      value => $hub->core_objects->{'variation'}->name,
    });
  }

  $self->add_fieldset(undef, 'general_options');
  
  my @output_values;
  
  foreach my $c (sort keys %$config) {
    foreach (@{$config->{$c}->{'formats'}}) {
      push (@output_values, { group => $config->{$c}->{'label'}, value => $_->[0], name => $_->[1] });
    }
  }
  
  if (scalar @output_values) {
    $self->add_form_element({
      type     => 'DropDown', 
      select   => 'select',
      required => 'yes',
      name     => 'output',
      classes  => [ 'output_type' ],
      label    => 'Output',
      values   => \@output_values
    });
  }
  
  if ($function eq 'Location') {
    $form->add_field({
      label     => 'Select location',
      inline    => 1,
      elements  => [
        { type => 'string',   size => 1, value => $slice->seq_region_name, name => 'new_region', required => 1 },
        { type => 'posint',   size => 8, value => $slice->start,           name => 'new_start',  required => 1 },
        { type => 'posint',   size => 8, value => $slice->end,             name => 'new_end',    required => 1 },
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
        { value => 'feature', name => 'Feature strand' },
        { value => '1',       name => 'Forward strand' },
        { value => '-1',      name => 'Reverse strand' }
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
      $self->add_fieldset("Options for $f->[1]", $f->[0]);
      
      if ($f->[0] eq 'fasta') {
        my $genomic = [
          { value => 'unmasked',     name => 'Unmasked' },
          { value => 'soft_masked',  name => 'Repeat Masked (soft)' },
          { value => 'hard_masked',  name => 'Repeat Masked (hard)' },
          { value => '5_flanking',   name => "5' Flanking sequence" },
          { value => '3_flanking',   name => "3' Flanking sequence" },
          { value => '5_3_flanking', name => "5' and 3' Flanking sequences" }
        ];

        push @$genomic, { value => 'off', name => 'None' } unless $action eq 'Location';
        
        $self->add_form_element({
          type     => 'DropDown', 
          select   => 'select',
          required => 'yes',
          name     => 'fasta_genomic',
          label    => 'Genomic',
          values   => $genomic
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
