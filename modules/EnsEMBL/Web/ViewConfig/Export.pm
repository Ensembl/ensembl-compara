package EnsEMBL::Web::ViewConfig::Export;

use strict;

use base qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw(init form);

use EnsEMBL::Web::Constants;

sub init {
  my $view_config = shift;
  
  my $misc_sets = $view_config->species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'};
  
  my %defaults;
  
  $defaults{'output'} = 'fasta';
  $defaults{'strand'} = $ENV{'ENSEMBL_ACTION'} eq 'Location' ? 'forward' : 'feature';
  
  $defaults{$_} = 0 for qw(flank5_display flank3_display);
  
  $defaults{'fasta_' . $_} = 'yes' for qw(cdna coding peptide utr5 utr3 exon intron);
  $defaults{'gff3_'  . $_} = 'yes' for qw(gene transcript exon intron cds);
  
  $defaults{'fasta_genomic'} = 'unmasked';
  
  foreach my $f (qw(csv tab gff)) {
    $defaults{$f . '_' . $_}         = 'yes' for qw(similarity repeat genscan variation gene);
    
    next if $f eq 'gff';
    
    $defaults{$f . '_miscset_' . $_} = 'yes' for keys %$misc_sets;
  }
  
  foreach my $f (qw(embl genbank)) {
    $defaults{$f . '_' . $_} = 'yes' for qw(similarity repeat genscan contig variation marker gene vegagene estgene);
  }
  
  $view_config->_set_defaults(%defaults);
  $view_config->storable = 1;
  $view_config->default_config = 0;
}

sub form {
  my ($view_config, $object) = @_;
  
  my $function = $object->function;
  
  return if $function !~ /Location|Gene|Transcript/;
  
  my $config = $object->config;
  my $slice = $object->slice;
  my $form_action = $object->_url({ action => 'Form', function => $function }, 1);
  my %gene_markup_options = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  
  $view_config->get_form->{'_attributes'}{'action'} = $form_action->[0];
  $view_config->get_form->{'_attributes'}{'id'} = 'export_configuration';
  $view_config->get_form->{'_attributes'}{'method'} = 'get';
    
  $view_config->add_fieldset;
  
  $view_config->add_form_element({
    type  => 'NoEdit',
    name  => 'location_to_export',
    label => 'Location to export',
    value => $slice->name
  });
  
  if ($function eq 'Gene') {
    $view_config->add_form_element({
      type  => 'NoEdit',
      name  => 'gene_to_export',
      label => 'Gene to export',
      value => $object->core_objects->gene_long_caption
    });
  } elsif ($function eq 'Transcript') {
    $view_config->add_form_element({
      type  => 'NoEdit',
      name  => 'transcript_to_export',
      label => 'Transcript to export',
      value => $object->core_objects->transcript_long_caption
    });
  } 
  
  $view_config->add_fieldset;
  
  my @output_values;
  
  foreach my $c (sort keys %$config) {
    foreach (@{$config->{$c}->{'formats'}}) {
      push (@output_values, { group => $config->{$c}->{'label'}, value => $_->[0], name => $_->[1] });
    }
  }
  
  if (scalar @output_values) {
    $view_config->add_form_element({
      type     => 'DropDown', 
      select   => 'select',
      required => 'yes',
      name     => 'output',
      label    => 'Output',
      values   => \@output_values
    });
  }
  
  if ($function eq 'Location') {
    my $s = $slice->strand;
    my @strand = map $s == $_ ? 'selected="selected"' : '', (1, -1);
    
    $view_config->add_form_element({
      type  => 'Raw',
      label => 'Select location',
      raw   => sprintf qq{
        <input type="text" size="1" value="%s" name="new_region" class="input-text required" />
        <input type="text" size="8" value="%s" name="new_start" class="input-text _posint required" />
        <input type="text" size="8" value="%s" name="new_end" class="input-text _posint required" />
        <select size="1" name="strand"><option value="1" %s>1</option><option value="-1" %s>-1</option></select>
      }, $slice->seq_region_name, $slice->start, $slice->end, @strand
    });
  } else {
    $view_config->add_form_element({
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
  
  $view_config->add_form_element($gene_markup_options{'flank5_display'});
  $view_config->add_form_element($gene_markup_options{'flank3_display'});
  
  $view_config->add_form_element({
    type  => 'Submit',
    class => 'submit',
    name  => 'next_top',
    value => 'Next >'
  });
  
  foreach my $c (sort keys %$config) {
    next unless $config->{$c}->{'params'};
    
    foreach my $f (@{$config->{$c}->{'formats'}}) {
      $view_config->add_fieldset("Options for $f->[1]");
      
      if ($f->[0] eq 'fasta') {
        my $genomic = [
          { value => 'unmasked',     name => 'Unmasked' },
          { value => 'soft_masked',  name => 'Repeat Masked (soft)' },
          { value => 'hard_masked',  name => 'Repeat Masked (hard)' },
          { value => '5_flanking',   name => "5' Flanking sequence" },
          { value => '3_flanking',   name => "3' Flanking sequence" },
          { value => '5_3_flanking', name => "5' and 3' Flanking sequences" }
        ];

        push @$genomic, { value => 'off', name => 'None' } unless $ENV{'ENSEMBL_ACTION'} eq 'Location';
        
        $view_config->add_form_element({
          type     => 'DropDown', 
          select   => 'select',
          required => 'yes',
          name     => 'fasta_genomic',
          label    => 'Genomic',
          values   => $genomic
        });
      }
      
      foreach (@{$config->{$c}->{'params'}}) {
        next unless defined $view_config->get("$f->[0]_$_->[0]");
        next if $_->[2] eq '0'; # Next if 0, but not if undef. Where is my === operator, perl?
        
        $view_config->add_form_element({
          type  => $config->{$c}->{'type'} || 'CheckBox',
          label => $_->[1],
          name  => "$f->[0]_$_->[0]",
          value => 'yes'
        });
      }
    }
  }
  
  $view_config->add_form_element({
    type  => 'Submit',
    class => 'submit',
    name  => 'next_bottom',
    value => 'Next >'
  });
  
  $view_config->add_form_element({
    type  => 'Hidden',
    name  => 'save',
    value => 'yes'
  });
  
  foreach (keys %{$form_action->[1]}) {
    $view_config->add_form_element({
      type  => 'Hidden',
      name  => $_,
      value => $form_action->[1]->{$_}
    });
  }
}

1;
