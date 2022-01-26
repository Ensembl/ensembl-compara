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

package EnsEMBL::Web::Command::DataExport::Output;

use strict;
use warnings;
no warnings 'uninitialized';

use RTF::Writer;
use Bio::AlignIO;
use IO::String;
use Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;
use Bio::EnsEMBL::Compara::Graph::HomologyPhyloXMLWriter;
use Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter;
use Bio::EnsEMBL::Compara::Graph::GeneTreeNodePhyloXMLWriter;
use Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter;

use EnsEMBL::Web::TextSequence::Output::RTF;

use EnsEMBL::Web::File::User;
use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Object::Transcript;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;

  my $controller;
  my $url_params = {};

  my $error;
  my $format = $hub->param('format');

  ## Clean up parameters to remove chosen format from name (see Component::DataExport)
  foreach ($hub->param) {
    if ($_ =~ /_$format$/) {
      (my $clean = $_) =~ s/_$format//;
      $hub->param($clean, $hub->param($_));
    }
  }

  my ($file, $name, $filename, $extension, $compression, $download_type);
  my %data_info = %{$hub->species_defs->multi_val('DATA_FORMAT_INFO')};
  my $format_info = $data_info{lc($format)};
 
  ## Make filename safe
  ($filename = $hub->param('name')) =~ s/ |-/_/g;
 
  ## Compress file by default
  $extension   = $format_info->{'ext'};
  $compression = $hub->param('compression');
  $download_type = $hub->param('download_type');
  $name = $hub->param('name');
  my $component;

  if (!$format_info) {
    $error = 'Format not recognised';
  }
  else {
    ## TODO - replace relevant parts with Bio::EnsEMBL::IO::Writer in due course
  
    ## Create the component we need to get data from 
    ($component, $error) = $self->object->create_component;

    # Override the options saved in viewconfig by the one selected by the user in the form (these settings are not saved to session since we don't call session->store afterwards)
    my $view_config = $hub->param('data_type') ? $hub->get_viewconfig({component => $component->id, type => $hub->param('data_type'), cache => 1}) : undef;
    for ($view_config ? $view_config->field_order : ()) {
      $view_config->set($_, $hub->param(sprintf '%s_%s', $_, $format) || 'off');
    }

    $file = EnsEMBL::Web::File::User->new(
      hub => $hub, 
      name => $filename, 
      extension => $extension, 
      compression => $compression eq 'gz' ? 'gz' : ''
    );

    ## Ugly hack - stuff file into package hash so we can get at it later without passing as argument
    $self->{'__file'} = $file;

    unless ($error) {
      ## Write data to output file in desired format

      my %align_formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
      my $in_bioperl    = grep { lc($_) eq lc($format) } keys %align_formats;
      ## Alignments and trees are handled by external writers
      if (($hub->param('align') && lc($format) ne 'rtf')
          || (ref($component) =~ /Paralog/ && $in_bioperl && lc($format) ne 'fasta')) {
        my %tree_formats  = EnsEMBL::Web::Constants::TREE_FORMATS;
        my $is_tree       = grep { lc($_) eq lc($format) } keys %tree_formats;
        if ($in_bioperl) {
          $error = $hub->param('align_type') eq 'msa_dna'
                    ? $self->write_homologue_seq($component)
                    : $self->write_alignment($component);
        }
        elsif (lc($format) eq 'phyloxml') {
          $error = $self->write_phyloxml($component);
        }
        elsif (lc($format) eq 'orthoxml') {
          $error = $self->write_orthoxml($component);
        }
        elsif ($is_tree) {
          $error = $self->write_tree($component);
        }
        else {
          $error = 'Output not implemented for format '.$format;
        }
      }
      elsif ($in_bioperl && $component =~ /Compara/) { 
        $error = ($hub->param('align_type') || $hub->param('seq_type') =~ /msa/) 
                    ? $self->write_alignment($component)
                    : $self->write_homologue_seq($component);
      }
      else {
        my $write_method = 'write_'.lc($format);
        if ($self->can($write_method)) {
          $error = $self->$write_method($component);
        }
        else {
          $error = 'Output not implemented for format '.$format;
        }
      }
    }
  } 

  if ($error) {
    $url_params->{'error'} = $error;
    $url_params->{'action'} = 'Error';
  }
  else {
    ## Parameters for file download
    $controller                     = 'Download' if $compression =~m/gz|uncompressed/ || $format eq 'RTF';    # if uncompressed format, user should be able to preview the file
    $url_params->{'action'}         = $compression =~m/gz|uncompressed/ || $format eq 'RTF' ? '' : 'Results'; # same as above
    $url_params->{'name'}           = $name;
    $url_params->{'filename'}       = $file->read_name;
    $url_params->{'format'}         = $format;
    $url_params->{'file'}           = $file->read_location;
    $url_params->{'compression'}    = $compression;
    $url_params->{'cdb'}            = $hub->param('cdb') || 'compara';
    $url_params->{'__clear'}        = 1;
    ## Pass parameters needed for Back button to work
    my @core_params = keys %{$hub->core_object('parameters')};
    push @core_params, qw(export_action data_type data_action component align g1);
    push @core_params, $self->config_params; 
    foreach (@core_params) {
      my @values = $component->param($_);
      $url_params->{$_} = scalar @values > 1 ? \@values : $values[0];
    }
  }
  $self->ajax_redirect($hub->url($controller || (), $url_params), $controller ? (undef, undef, 'download') : ());
}

sub config_params {
  my $self = shift;
  my @params;
  my $format = $self->hub->param('format');
  foreach ($self->hub->param) {
    next unless $_ =~ /_$format$/;
    push @params, $_;
  }
  return @params;
}

###### INDIVIDUAL FORMATS #############

sub write_rtf {
### RTF output is atypical, in that it aims to replicate the visual appearance
### of the page (a bit like image export) rather than processing data
  my ($self, $component) = @_;

  $self->hub->param('exon_display', 'on'); ## force exon highlighting on

  # XXX hack
  my ($sequence, $config, $block_mode);
  my $string;
  if($component->can('initialize_export_new')) {
    ($sequence, $config, $block_mode) = $component->initialize_export_new;
    return 'No sequence generated - did you select any required options?' unless scalar(@{$sequence||{}});

    my $view = $component->view;
    $view->output(EnsEMBL::Web::TextSequence::Output::RTF->new);

    $view->width($config->{'display_width'});
    $view->transfer_data_new($config);
    my $rtflist = $view->output->build_output($config,$config->{'line_numbers'},@{$view->sequences}>1,0);

    my $rtf = RTF::Writer->new_to_string(\$string);
    $rtf->prolog(
      fonts  => [ 'Courier New' ],
      colors => $view->output->c2s->colours,
    );
    $rtflist->emit($rtf);
    $rtf->close;
  } else {
    ($sequence, $config, $block_mode) = $component->initialize_export;
    return 'No sequence generated - did you select any required options?' unless scalar(@{$sequence||{}});

    my $view = $component->view;
    $view->output(EnsEMBL::Web::TextSequence::Output::RTF->new);

    $view->width($config->{'display_width'});
    $view->transfer_data($sequence,$config);
    my $rtflist = $view->output->build_output($config,$config->{'line_numbers'},@{$view->sequences}>1,0);

    my $rtf = RTF::Writer->new_to_string(\$string);
    $rtf->prolog(
      fonts  => [ 'Courier New' ],
      colors => $view->output->c2s->colours,
    );
    $rtflist->emit($rtf);
    $rtf->close;
  }
  my $result = $self->write_line($string);
  return $result->{'error'} || undef;
}

sub write_fasta {
  my ($self, $component) = @_;
  my $hub     = $self->hub;

  my $data_type   = $hub->param('data_type');
  my $data_object = $hub->core_object($data_type);
  my @data        = $component->get_export_data;

  my $slice;
  if ($hub->param('flank_size') || ($data_type eq 'Transcript' && $hub->param('flanking'))) {
    $slice = $self->object->expand_slice($data_object->slice);
  }
  else {
    $slice = $data_object->slice;
  }

  my $masking         = $hub->param('masking');
  my $seq_region_name = $data_object->seq_region_name;
  my $seq_region_type = $data_object->seq_region_type;
  my $slice_name      = $slice->name;
  my $slice_length    = $slice->length;
  my $fasta;

  my $intron_id;

  my $output = {
      cdna    => sub { 
                      my ($t, $id, $type) = @_; 
                      my $full_id = $t->display_id;
                      $full_id .= '.'.$t->version if $t->version;
                      $id = "$full_id $id" unless $id eq $full_id; 
                      [[ "$id cdna:$type", $t->spliced_seq ]] },
      coding  => sub { my ($t, $id, $type) = @_; [[ "$id cds:$type", $t->translateable_seq ]] },
      peptide => sub { my ($t, $id, $type) = @_; eval { [[ "$id peptide: " . $t->translation->stable_id . " pep:$type", $t->translate->seq ]] }},
      utr3    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr3:$type", $t->three_prime_utr->seq ]] }},
      utr5    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr5:$type", $t->five_prime_utr->seq ]] }},
      exon    => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id " . $_->display_id . " exon:$type", $_->seq->seq ]} @{$t->get_all_Exons} ] }},
      intron  => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id intron " . $intron_id++ . ":$type", $_->seq ]} @{$t->get_all_Introns} ] }}
  };

  my $options = EnsEMBL::Web::Constants::FASTA_OPTIONS;
  my @selected_options = $hub->param('extra');
  my $sequence = grep /sequence/, @selected_options;

  ## Skip the next section if we're only exporting genomic sequence
  @selected_options = () if ($sequence && $sequence == scalar @selected_options);

  my ($result, @errors);

  if (scalar @selected_options) {
    ## Only applicable to actual transcripts
    foreach my $transcript (@data) {
      my @id_info = EnsEMBL::Web::Object::Transcript::display_xref(undef, $transcript);
      my $id  = $id_info[0];
      if (!$id) {
        $id = $transcript->display_id;
        $id .= '.'.$transcript->version if $transcript->version;
      }
      my $type  = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') 
                      ? $transcript->analysis->logic_name 
                      : $transcript->biotype;

      $intron_id = 1;

      foreach my $opt (sort @selected_options) {
        next if $opt eq 'sequence';
        next unless exists $output->{$opt};

        my $o = $output->{$opt}($transcript, $id, $type);
        next unless ref $o eq 'ARRAY';

        foreach (@$o) {
          $result = $self->write_line(">$_->[0]");
          push @errors, @{$result->{'error'}||[]};
          $result = $self->write_line($fasta) while $fasta = substr $_->[1], 0, 60, '';
          push @errors, @{$result->{'error'}||[]};
        }
      }
      $result = $self->write_line('');
      push @errors, @{$result->{'error'}||[]};
    }
  }

  if ($sequence || $hub->param('select_sequence')) {
    my $mask_flag = $masking eq 'soft_masked' ? 1 : $masking eq 'hard_masked' ? 0 : undef;
    my ($seq, $start, $end, $flank_slice);

    $seq = defined $masking ? $slice->get_repeatmasked_seq(undef, $mask_flag)->seq : $slice->seq;
    $result = $self->write_line(">$seq_region_name dna:$seq_region_type $slice_name");
    push @errors, @{$result->{'error'}||[]};
    $result = $self->write_line($fasta) while $fasta = substr $seq, 0, 60, '';
    push @errors, @{$result->{'error'}||[]};
  }

  return join('; ', @errors) || undef;
}

sub write_emboss {
  my ($self, $component) = @_;

  my $data = $component->get_export_data;
  my ($result, @errors);

  foreach (@$data) {
    my $result = $self->write_line($_);
    push @errors, @{$result->{'error'}||[]};
  }
  return join('; ', @errors) || undef;
}

sub write_alignment {
  my ($self, $component) = @_;
  my $hub     = $self->hub;
  my $align = $hub->param('align');
  my ($alignment, $result);
  my $flag = $align ? undef : 'sequence';
  my $data = $component->get_export_data($flag);
  if (!$data) {
    $result->{'error'} = ['No data returned'];
  }
  else {
    my $export;
    my $format  = $hub->param('format');
    my $align_io = Bio::AlignIO->newFh(
      -fh     => IO::String->new($export),
      -format => $format
    );

    if (ref($data) eq 'ARRAY') {
      print $align_io $_ for @$data;
    }
    else {
      if (ref($data) =~ 'AlignedMemberSet') {
        if ($hub->param('align_type') eq 'msa_dna' || $hub->param('seq_type') =~ /dna/) {
          $data = $data->get_SimpleAlign(-SEQ_TYPE => 'cds', -APPEND_SP_SHORT_NAME => 1);
        }
        else {
          my %sa_param = (-APPEND_SP_SHORT_NAME => 1);
          if ($hub->param('data_action')) {
            $sa_param{'-REMOVE_GAPS'} = 1;
          }
          $data = $data->get_SimpleAlign(%sa_param);
        }
      }
      if (ref($data) =~ 'SimpleAlign') {
        $alignment = $data;
      }
      else {
        $self->object->{'alignments_function'} = 'get_SimpleAlign';

        $alignment = $self->object->get_alignments({
          'slice'     => $data->slice,
          'align'     => $hub->param('align'),
          'species'   => $hub->species,
          'type'      => $hub->param('data_type'),
          'component' => $hub->param('data_action'), 
        });
      }

      print $align_io $alignment;
    }

    $result = $self->write_line($export);
  }
  return $result->{'error'} || undef;
}

sub write_homologue_seq {
  my ($self, $component) = @_;
  my $hub     = $self->hub;
  my $result;

  my $data = $component->get_export_data('sequence');
  if ($data) {
    my $format    = lc($hub->param('format'));
    my $file      = $self->{'__file'};
    my $file_path = $file->absolute_write_path;
    $file->touch;
    my %params = (-format => $format, -ID_TYPE=>'STABLE_ID');
    if ($hub->param('seq_type') =~ /_dna/ || $hub->param('align_type') eq 'msa_dna') {
      $params{'-SEQ_TYPE'} = 'cds';
    }
    eval {
      if (ref($data) =~ /GeneTreeNode/) {
        $data->get_AlignedMemberSet()->print_sequences_to_file($file_path, %params);
      }
      else {
        $data->print_sequences_to_file($file_path, %params);
      }
    };
    if ($@) {
      $result = {'error' => ['Error writing sequences to file']};
      warn ">>> ERROR THROWN BY print_sequences_to_file: $@";
    }
    else {
      $result = {'content' => $file->read};
    }
  }
  else {
    $result = {'error' => ['No data returned by API']};
  } 
 
  return $result->{'error'} || undef;
}

sub write_tree {
  my ($self, $component) = @_;
  my $hub     = $self->hub;
  my $format  = lc($hub->param('format'));
  my $tree    = $component->get_export_data('tree');

  my %formats = EnsEMBL::Web::Constants::TREE_FORMATS;
  $format     = 'newick' unless $formats{$format};
  my $fn      = $formats{$format}{'method'};
  my @params  = map $hub->param($_), @{$formats{$format}{'parameters'} || []};
  my $string  = $tree->$fn(@params);

  if ($formats{$format}{'split'}) {
    my $reg = '([' . quotemeta($formats{$format}{'split'}) . '])';
    $string =~ s/$reg/$1\n/g;
  }

  my $result = $self->write_line($string);
  return $result->{'error'} || undef;
}

sub write_phyloxml {
  my ($self, $component) = @_;
  my $hub  = $self->hub;
  my $cdb  = $hub->param('cdb') || 'compara';

  my $tree = $component->get_export_data('genetree');

  my ($type, $method);
  if (ref($component) =~ /Tree/) {
    $method = 'trees';
    $type = ref($component) =~ /SpeciesTree/ ? 'CAFE' : 'Gene';
    $type .= 'Tree';
    $type .= 'Node' if ref($tree) =~ /Node/;
  }
  else {
    $method = 'homologies';
    $type = 'Homology';
  }
  my $class = sprintf('Bio::EnsEMBL::Compara::Graph::%sPhyloXMLWriter', $type);

  my $handle = IO::String->new();
  my $w = $class->new(
      -SOURCE       => $cdb eq 'compara' ? $SiteDefs::ENSEMBL_SITETYPE:'Ensembl Genomes',
      -ALIGNED      => $hub->param('aligned') eq 'on' ? 1 : 0,
      -CDNA         => $hub->param('cdna') eq 'on' ? 1 : 0,
      -NO_SEQUENCES => $hub->param('no_sequences') eq 'on' ? 1 : 0,
      -HANDLE       => $handle,
  );

  $self->_writexml($method, $tree, $handle, $w);
}

sub write_orthoxml {
  my ($self, $component) = @_;
  my $hub     = $self->hub;
  my $cdb     = $hub->param('cdb') || 'compara';
  my ($data)  = $component->get_export_data('genetree');

  my $method_type;
  if (ref($component) =~ /ComparaTree/) {
    $method_type = ref($data) =~ /Node/ ? 'subtrees' : 'trees';     
  }
  else {
    $method_type = 'homologies';
  }

  my $handle = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(
    -SOURCE => $cdb eq 'compara' ? $hub->species_defs->ENSEMBL_SITETYPE : 'Ensembl Genomes',
    -SOURCE_VERSION => $hub->species_defs->SITE_RELEASE_VERSION,
    -HANDLE => $handle,
  );
  $self->_writexml($method_type, $data, $handle, $w);
}

sub _writexml{
  my ($self, $method_type, $data, $handle, $w) = @_;
  my $hub = $self->hub;
  my $method = 'write_'.$method_type;
  $w->$method($data);
  $w->finish();

  my $out = ${$handle->string_ref()};
  my $result = $self->write_line($out);
  return $result->{'error'} || undef;
}

sub write_line { 
  my ($self, $string) = @_;
  my $file = $self->{'__file'};
  return $file->write_line($string);
}

1;
