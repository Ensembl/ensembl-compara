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

package EnsEMBL::Web::Command::DataExport::Output;

use strict;
use warnings;
no warnings 'uninitialized';

use RTF::Writer;
use Bio::AlignIO;
use IO::String;
use Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;
use Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter;
use Bio::EnsEMBL::Compara::Graph::GeneTreeNodePhyloXMLWriter;
use Bio::EnsEMBL::Compara::Graph::CAFETreePhyloXMLWriter;

use EnsEMBL::Web::File::User;
use EnsEMBL::Web::Constants;

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

  my ($file, $filename, $extension, $compression);
  my %data_info = %{$hub->species_defs->multi_val('DATA_FORMAT_INFO')};
  my $format_info = $data_info{lc($format)};
 
  ## Make filename safe
  ($filename = $hub->param('name')) =~ s/ |-/_/g;
 
  ## Compress file by default
  $extension   = $format_info->{'ext'};
  $compression = $hub->param('compression');

  if (!$format_info) {
    $error = 'Format not recognised';
  }
  else {
    ## TODO - replace relevant parts with Bio::EnsEMBL::IO::Writer in due course
  
    ## Create the component we need to get data from 
    my $component;
    ($component, $error) = $self->object->create_component;

    $file = EnsEMBL::Web::File::User->new(hub => $hub, name => $filename, extension => $extension, compression => $compression);

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
          $error = $self->write_alignment($component);
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
    $controller                     = 'Download' if $compression || $format eq 'RTF';    # if uncompressed format, user should be able to preview the file
    $url_params->{'action'}         = $compression || $format eq 'RTF' ? '' : 'Results'; # same as above
    $url_params->{'filename'}       = $file->read_name;
    $url_params->{'format'}         = $format;
    $url_params->{'file'}           = $file->read_location;
    $url_params->{'compression'}    = $compression;
    $url_params->{'__clear'}        = 1;
    ## Pass parameters needed for Back button to work
    my @core_params = keys %{$hub->core_object('parameters')};
    push @core_params, qw(export_action data_type component align);
    push @core_params, $self->config_params; 
    foreach my $species (grep { /species_/ } $hub->param) {
      push @core_params, $species;
    } 
    foreach (@core_params) {
      my @values = $hub->param($_);
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
  my ($sequence, $config, $block_mode) = $component->initialize_export; 
  return 'No sequence generated - did you select any required options?' unless scalar(@{$sequence||{}});

  ## Configure RTF display
  my @colours        = (undef);  
  my $class_to_style = $self->_class_to_style;
  my $spacer         = $config->{'v_space'} ? ' ' x $config->{'display_width'} : '';
  my $c              = 1;
  my $i              = 0;
  my $j              = 0;
  my $previous_j     = undef;
  my $sp             = 0;
  my $newline        = 1;
  my @output;

  foreach my $class (sort { $class_to_style->{$a}[0] <=> $class_to_style->{$b}[0] } keys %$class_to_style) {
    my $rtf_style = {};

    $rtf_style->{'\cf'      . $c++} = substr $class_to_style->{$class}[1]{'color'}, 1         
      if $class_to_style->{$class}[1]{'color'};    
    $rtf_style->{'\chshdng0\chcbpat'.$c.'\cb'.$c++} = substr $class_to_style->{$class}[1]{'background-color'}, 1 
      if $class_to_style->{$class}[1]{'background-color'};
    $rtf_style->{'\b'}              = 1
      if $class_to_style->{$class}[1]{'font-weight'}     eq 'bold';
    $rtf_style->{'\ul'}             = 1
      if $class_to_style->{$class}[1]{'text-decoration'} eq 'underline';

    $class_to_style->{$class}[1] = $rtf_style;

    push @colours, [ map hex, unpack 'A2A2A2', $rtf_style->{$_} ] for sort grep /\d/, keys %$rtf_style;
  }

  foreach my $lines (@$sequence) {
    next unless @$lines;
    my ($section, $class, $previous_class, $count, %stash);

    $lines->[-1]{'end'} = 1;

    ## Output each line of sequence letters
    my $num;
    my $is_alignment = $self->hub->param('align');
    foreach my $seq (@$lines) {
      if ($seq->{'class'}) {
        $class = $seq->{'class'};

        if ($config->{'maintain_colour'} && $previous_class =~ /\s*(e\w)\s*/ && $class !~ /\s*(e\w)\s*/) {
          $class .= " $1";
        }
      } elsif ($config->{'maintain_colour'} && $previous_class =~ /\s*(e\w)\s*/) {
        $class = $1;
      } else {
        $class = '';
      }

      $class = join ' ', sort { $class_to_style->{$a}[0] <=> $class_to_style->{$b}[0] } split /\s+/, $class;

      ## RTF has no equivalent of text-transform, so we must manually alter the text
      if ($class =~ /\b(el)\b/) {
        $seq->{'letter'} = lc($seq->{'letter'});
      }

      ## Add species name at beginning of each line if this is an alignment
      ## (on pages, this is done by build_sequence, but that adds HTML)
      my $sp_string;
      if ($config->{'comparison'} && !scalar($output[$i][$j])) {
    
        if (scalar keys %{$config->{'padded_species'}}) {
          $sp_string = $config->{'padded_species'}{$config->{'seq_order'}[$i]} || $config->{'display_species'};
        } else {
          $sp_string = $config->{'display_species'};
        }

        $sp_string .= '  ';
        push @{$output[$i][$j]}, [ undef, $sp_string ];
      }

      $seq->{'letter'} =~ s/<a.+>(.+)<\/a>/$1/ if $seq->{'url'};

      if ($count == $config->{'display_width'} || $seq->{'end'} || defined $previous_class && $class ne $previous_class) {
        my $style = join '', map keys %{$class_to_style->{$_}[1]}, split ' ', $previous_class;

        $section .= $seq->{'letter'} if $seq->{'end'};

        if ($config->{'number'} && 
              (!scalar @{$output[$i][$j]||[]} 
                  || ($is_alignment && (!defined($previous_j) || $j != $previous_j)))) {
          $num = scalar @{$output[$i][$j]|| []} > 1 ? $num : shift @{$config->{'line_numbers'}{$i}};
          my $pad1 = ' ' x ($config->{'padding'}{'pre_number'} - length $num->{'label'});
          my $pad2 = ' ' x ($config->{'padding'}{'number'}     - length $num->{'start'});

          push @{$output[$i][$j]}, [ \'', $config->{'h_space'} . sprintf '%6s ', "$pad1$num->{'label'}$pad2$num->{'start'}" ];
        }
        $previous_j     = $j;

        push @{$output[$i][$j]}, [ \$style, $section ];

        if ($count == $config->{'display_width'}) {
          $count = 0;
          $j++;
        }
        
        $section = '';
      }

      $section       .= $seq->{'letter'};
      $previous_class = $class;
      $count++;
    }

    $i++;
    $j = 0;
    $previous_j = undef;
  }

  ### Write information to RTF file
  my $string;
  my $rtf  = RTF::Writer->new_to_string(\$string);

  $rtf->prolog(
    fonts  => [ 'Courier New' ],
    colors => \@colours,
  );

  ## Each paragraph is font size 24 (12pt), plus
  ## we explicitly set font to default (0) for Mac compatibility
  if ($block_mode) {
    foreach my $block (@output) {
      $rtf->paragraph(\'\fs24\f0', $_)      for @$block;
      $rtf->paragraph(\'\fs24\f0', $spacer) if $spacer;
    }
  } else {
    for my $i (0..$#{$output[0]}) {
      $rtf->paragraph(\'\fs20\f0', $_->[$i]) for @output;
      $rtf->paragraph(\'\fs24\f0', $spacer)  if $spacer;
    }
  }
 
  $rtf->close;

  my $result = $self->write_line($string);
  return $result->{'error'} || undef;
}

sub _class_to_style {
  my $self = shift;

  if (!$self->{'class_to_style'}) {
    my $hub          = $self->hub;
    my $colourmap    = $hub->colourmap;
    my $species_defs = $hub->species_defs;
    my $styles       = $species_defs->colour('sequence_markup');
    my $var_styles   = $species_defs->colour('variation');
    my $i            = 1;

    my %class_to_style = (
      con  => [ $i++, { 'background-color' => "#$styles->{'SEQ_CONSERVATION'}{'default'}" } ],
      dif  => [ $i++, { 'background-color' => "#$styles->{'SEQ_DIFFERENCE'}{'default'}" } ],
      res  => [ $i++, { 'color' => "#$styles->{'SEQ_RESEQUENCING'}{'default'}" } ],
      e0   => [ $i++, { 'color' => "#$styles->{'SEQ_EXON0'}{'default'}" } ],
      e1   => [ $i++, { 'color' => "#$styles->{'SEQ_EXON1'}{'default'}" } ],
      e2   => [ $i++, { 'color' => "#$styles->{'SEQ_EXON2'}{'default'}" } ],
      eu   => [ $i++, { 'color' => "#$styles->{'SEQ_EXONUTR'}{'default'}" } ],
      ef   => [ $i++, { 'color' => "#$styles->{'SEQ_EXONFLANK'}{'default'}" } ],
      eo   => [ $i++, { 'background-color' => "#$styles->{'SEQ_EXONOTHER'}{'default'}" } ],
      eg   => [ $i++, { 'color' => "#$styles->{'SEQ_EXONGENE'}{'default'}", 'font-weight' => 'bold' } ],
      c0   => [ $i++, { 'background-color' => "#$styles->{'SEQ_CODONC0'}{'default'}" } ],
      c1   => [ $i++, { 'background-color' => "#$styles->{'SEQ_CODONC1'}{'default'}" } ],
      cu   => [ $i++, { 'background-color' => "#$styles->{'SEQ_CODONUTR'}{'default'}" } ],
      co   => [ $i++, { 'background-color' => "#$styles->{'SEQ_CODON'}{'default'}" } ],
      aa   => [ $i++, { 'color' => "#$styles->{'SEQ_AMINOACID'}{'default'}" } ],
      end  => [ $i++, { 'background-color' => "#$styles->{'SEQ_REGION_CHANGE'}{'default'}", 'color' => "#$styles->{'SEQ_REGION_CHANGE'}{'label'}" } ],
      bold => [ $i++, { 'font-weight' => 'bold' } ],
      el   => [$i++, { 'color' => "#$styles->{'SEQ_EXON0'}{'default'}", 'text-transform' => 'lowercase' } ],

    );

    foreach (keys %$var_styles) {
      my $style = { 'background-color' => $colourmap->hex_by_name($var_styles->{$_}{'default'}) };

      $style->{'color'} = $colourmap->hex_by_name($var_styles->{$_}{'label'}) if $var_styles->{$_}{'label'};

      $class_to_style{$_} = [ $i++, $style ];
    }

    $class_to_style{'var'} = [ $i++, { 'color' => "#$styles->{'SEQ_MAIN_SNP'}{'default'}", 'background-color' => '#FFFFFF', 'font-weight' => 'bold', 'text-decoration' => 'underline' } ];

    $self->{'class_to_style'} = \%class_to_style;
  }

  return $self->{'class_to_style'};
}

sub write_fasta {
  my ($self, $component) = @_;
  my $hub     = $self->hub;

  my $data_type   = $hub->param('data_type');
  my $data_object = $hub->core_object($data_type);
  my @data        = $component->get_export_data;

  ## Do a bit of munging of this data, according to export options selected
  my $stable_id   = ($data_type eq 'Gene' || $data_type eq 'LRG') ? $data_object->stable_id : '';
  my $slice       = $self->object->expand_slice($data_object->slice);

  my $masking         = $hub->param('masking');
  my $seq_region_name = $data_object->seq_region_name;
  my $seq_region_type = $data_object->seq_region_type;
  my $slice_name      = $slice->name;
  my $slice_length    = $slice->length;
  my $fasta;

  my $intron_id;

  my $output = {
      cdna    => sub { my ($t, $id, $type) = @_; [[ "$id cdna:$type", $t->spliced_seq ]] },
      coding  => sub { my ($t, $id, $type) = @_; [[ "$id cds:$type", $t->translateable_seq ]] },
      peptide => sub { my ($t, $id, $type) = @_; eval { [[ "$id peptide: " . $t->translation->stable_id . " pep:$type", $t->translate->seq ]] }},
      utr3    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr3:$type", $t->three_prime_utr->seq ]] }},
      utr5    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr5:$type", $t->five_prime_utr->seq ]] }},
      exon    => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id " . $_->id . " exon:$type", $_->seq->seq ]} @{$t->get_all_Exons} ] }},
      intron  => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id intron " . $intron_id++ . ":$type", $_->seq ]} @{$t->get_all_Introns} ] }}
  };

  my $options = EnsEMBL::Web::Constants::FASTA_OPTIONS;
  my @selected_options = $hub->param('extra');
  my $sequence = grep /sequence/, @selected_options;
  my ($result, @errors);

  if (scalar @selected_options) {
    ## Only applicable to actual transcripts
    foreach my $transcript (@data) {
      my $id    = ($stable_id ? "$stable_id:" : '') . $transcript->stable_id;
      my $type  = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') 
                      ? $transcript->analysis->logic_name 
                      : $transcript->status . '_' . $transcript->biotype;

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
          $data = $data->get_SimpleAlign(-APPEND_SP_SHORT_NAME => 1);
        }
      }
      if (ref($data) =~ 'SimpleAlign') {
        $alignment = $data;
      }
      else {
        $self->object->{'alignments_function'} = 'get_SimpleAlign';

        $alignment = $self->object->get_alignments({
          'slice'   => $data->slice,
          'align'   => $hub->param('align'),
          'species' => $hub->species,
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
      $data->print_sequences_to_file($file_path, %params);
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

  my $type = ref($component) =~ /SpeciesTree/ ? 'CAFE' : 'Gene';
  $type .= 'Tree';
  $type .= 'Node' if ref($tree) =~ /Node/;
  my $class = sprintf('Bio::EnsEMBL::Compara::Graph::%sPhyloXMLWriter', $type);

  my $handle = IO::String->new();
  my $w = $class->new(
    -SOURCE       => $cdb eq 'compara' ? $SiteDefs::ENSEMBL_SITETYPE:'Ensembl Genomes',
    -ALIGNED      => $hub->param('aligned') eq 'on' ? 1 : 0,
    -CDNA         => $hub->param('cdna') eq 'on' ? 1 : 0,
    -NO_SEQUENCES => $hub->param('no_sequences') eq 'on' ? 1 : 0,
    -HANDLE       => $handle,
  );
  $self->_writexml('trees', $tree, $handle, $w);
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
  return $file->write_line("$string\r\n");
}

1;
