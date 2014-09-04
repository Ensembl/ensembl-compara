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

package EnsEMBL::Web::Command::DataExport::Output;

use strict;

use RTF::Writer;
use Bio::AlignIO;
use IO::String;

use EnsEMBL::Web::File;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;

  my $url_params = {'action' => 'Results'};
  my @redirect_params;

  my $error;
  my $format = $hub->param('format');

  ## Clean up parameters to remove chosen format from name (see Component::DataExport)
  foreach ($hub->param) {
    if ($_ =~ /_$format$/) {
      (my $clean = $_) =~ s/_$format//;
      $hub->param($clean, $hub->param($_));
    }
  }

  my ($file, $filename, $random_dir, $extension, $compression);
  my %data_info = %{$hub->species_defs->DATA_FORMAT_INFO};
  my $format_info = $hub->species_defs->DATA_FORMAT_INFO->{lc($format)};
 
  ## Make filename safe
  ($filename = $hub->param('name')) =~ s/ |-/_/g;
 
  ## Compress file by default
  $extension   = $format_info->{'ext'};
  $compression = $hub->param('compression');
  my $compress    = $compression ? 1 : 0;
  $extension   .= '.'.$compression if $compress;

  if (!$format_info) {
    $error = 'Format not recognised';
  }
  else {
    ## TODO - replace relevant parts with Bio::EnsEMBL::IO::Writer in due course
  
    ## Create the component we need to get data from 
    my $component;
    ($component, $error) = $self->object->create_component;

    $file = EnsEMBL::Web::File->new(hub => $hub, name => $filename, extension => $extension, prefix => 'export',  compress => $compress);

    ## Ugly hack - stuff file into package hash so we can get at it later without passing as argument
    $self->{'__file'} = $file;

    unless ($error) {
      ## Write data to output file in desired format

      ## All non-RTF alignments go via a single outputter
      if ($hub->param('align') && lc($format) ne 'rtf') {
        my @data = $component->get_export_data;
        $error = $self->write_alignments($format, @data);
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
    $url_params->{'filename'}       = $file->filename;
    $url_params->{'format'}         = $format;
    $url_params->{'path'}          .= '/export/'.$file->random_path.$file->filename;
    $url_params->{'compression'}    = $compression;
    ## Pass parameters needed for Back button to work
    my @core_params = keys %{$hub->core_object('parameters')};
    push @core_params, qw(export_action data_type component align);
    push @core_params, $self->config_params; 
    foreach (@core_params) {
      my @values = $hub->param($_);
      $url_params->{$_} = scalar @values > 1 ? \@values : $values[0];
    }
  }  
  my $url = $hub->url($url_params);

  $self->ajax_redirect($hub->url($url_params), @redirect_params);
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
  my $file = $self->{'__file'};
  my $error;

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

  ## Rotate the species if this is an alignment
  my $repeat = scalar keys %{$config->{'padded_species'}||{}};

  foreach my $lines (@$sequence) {
    next unless @$lines;
    my ($section, $class, $previous_class, $count, %stash);

    $lines->[-1]{'end'} = 1;

    ## Output each line of sequence letters
    foreach my $seq (@$lines) {
      $sp = 0 if $sp == $repeat;
      next unless keys %{$seq||{}};
      warn "... SP = $sp for ".$seq->{'letter'};
      warn "... $section";
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

      ## Add species name if this is an alignment
      ## (on pages, this is done by build_sequence, but that adds HTML)
      my $pre_string;
      if ($config->{'comparison'} && $newline) {
    
        if (scalar keys %{$config->{'padded_species'}}) {
          $pre_string = $config->{'padded_species'}{$config->{'seq_order'}[$sp]} || $config->{'display_species'};
        } else {
          $pre_string = $config->{'display_species'};
        }

        $pre_string .= '  ';
        ## To avoid styling the species name like sequence, put this letter
        ## back in the queue and just process the species name
        my %recycle = keys %stash ? %stash : %$seq;
        unshift @$lines, \%recycle;
        $seq = {'letter' => $pre_string};
        $newline = 0;
      }

      $seq->{'letter'} =~ s/<a.+>(.+)<\/a>/$1/ if $seq->{'url'};

      if ($count == $config->{'display_width'} || $seq->{'end'} || defined $previous_class && $class ne $previous_class) {
        my $style = join '', map keys %{$class_to_style->{$_}[1]}, split ' ', $previous_class;

        $section .= $seq->{'letter'} if $seq->{'end'};

        if (!scalar @{$output[$i][$j] || []} && $config->{'number'}) {
          my $num  = shift @{$config->{'line_numbers'}{$i}};
          my $pad1 = ' ' x ($config->{'padding'}{'pre_number'} - length $num->{'label'});
          my $pad2 = ' ' x ($config->{'padding'}{'number'}     - length $num->{'start'});

          push @{$output[$i][$j]}, [ \'', $config->{'h_space'} . sprintf '%6s ', "$pad1$num->{'label'}$pad2$num->{'start'}" ];
        }

        push @{$output[$i][$j]}, [ \$style, $section ];

        if ($count == $config->{'display_width'}) {
          $count = 0;
          $j++;
        }
        
        $newline = 1;
        %stash = %$seq;
        $seq   = {};
        $section = '';
      }

      $section       .= $seq->{'letter'} if keys %$seq;
      $seq            = {};
      $previous_class = $class;
      $count++;
      $sp++;
    }

    $i++;
    $j = 0;
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

  $file->write_line($string);

  return $error || $file->error;
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
      bold => [ $i++, { 'font-weight' => 'bold' } ]
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
  my $error   = undef;

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

  foreach my $transcript (@data) {
    my $id         = ($stable_id ? "$stable_id:" : '') . $transcript->stable_id;
    my $type       = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') ? $transcript->analysis->logic_name : $transcript->status . '_' . $transcript->biotype;

    $intron_id = 1;

    foreach my $opt (sort @selected_options) {
      next if $opt eq 'sequence';
      next unless exists $output->{$opt};

      my $o = $output->{$opt}($transcript, $id, $type);
      next unless ref $o eq 'ARRAY';

      foreach (@$o) {
        $self->write_line(">$_->[0]");
        $self->write_line($fasta) while $fasta = substr $_->[1], 0, 60, '';
      }
    }

    $self->write_line('');
  }

  if ($sequence) {
    my $mask_flag = $masking eq 'soft_masked' ? 1 : $masking eq 'hard_masked' ? 0 : undef;
    my ($seq, $start, $end, $flank_slice);

    $seq = defined $masking ? $slice->get_repeatmasked_seq(undef, $mask_flag)->seq : $slice->seq;
    $self->write_line(">$seq_region_name dna:$seq_region_type $slice_name");
    $self->write_line($fasta) while $fasta = substr $seq, 0, 60, '';
  }

  my $file = $self->{'__file'};
  return $error || $file->error;
}

sub write_alignments {
  my ($self, $format, $location) = @_;
  my $hub = $self->hub;

  $self->object->{'alignments_function'} = 'get_SimpleAlign';

  my $alignments = $self->object->get_alignments({
                                                'slice'   => $location->slice,
                                                'align'   => $hub->param('align'),
                                                'species' => $hub->species,
                                              });

  my $export;

  my $align_io = Bio::AlignIO->newFh(
    -fh     => IO::String->new($export),
    -format => $format
  );

  print $align_io $alignments;

  $self->write_line($export);
}

sub write_line { 
  my ($self, $string) = @_;
  my $file = $self->{'__file'};
  $file->write_line("$string\r\n");
}

1;
