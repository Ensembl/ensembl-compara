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

use EnsEMBL::Web::Controller;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::TmpFile::Text;

use RTF::Writer;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;

  my $url_params = {'action' => 'Results'};

  my $error;
  my $format = $hub->param('format');
  my %data_info = %{$hub->species_defs->DATA_FORMAT_INFO};
  my $format_info = $hub->species_defs->DATA_FORMAT_INFO->{lc($format)};
  my $file;
  
  if (!$format_info) {
    $error = 'Format not recognised';
  }
  else {

    $file = EnsEMBL::Web::TmpFile::Text->new(extension => $format_info->{'ext'}, prefix => 'export');

    ## Create the component we need to get data from 
    my $class = 'EnsEMBL::Web::Component::'.$hub->param('data_type').'::'.$hub->param('component');
    my $component;
    if ($self->dynamic_use($class)) {
      my $builder = EnsEMBL::Web::Builder->new({
                        hub           => $hub,
                        object_params => EnsEMBL::Web::Controller::OBJECT_PARAMS,
      });
      $builder->create_objects(ucfirst($hub->param('data_type')), 'lazy');
      $hub->set_builder($builder);
      $component = $class->new($hub, $builder);
    }
    if (!$component) {
      warn "!!! Could not create component $class";
      $error = 'Export not available';
    }
    elsif (!$component->can('fetch_data')) {
      warn "!!! Export not implemented in component $class";
      $error = 'Export not available';
    }
    unless ($error) {
      ## Write data to output file in desired format
      ## N.B. replace with Bio::EnsEMBL::IO::Writer in due course
      my $write_method = 'write_'.lc($format);
      if ($self->can($write_method)) {
        $error = $self->$write_method($file, $component);
      }
      else {
        $error = 'Output not implemented for format '.$format;
      }
    }
  }

  if ($error) {
    $url_params->{'error'} = $error;
    $url_params->{'action'} = 'Error';
  }
  else {
    $url_params->{'file'} = $file->filename;
    $url_params->{'format'} = $format;
  }  

  $self->ajax_redirect($hub->url($url_params));
}

###### INDIVIDUAL FORMATS #############

sub write_rtf {
  my ($self, $file, $component) = @_;

  my ($sequence, $config, $block_mode) = $component->fetch_data; 
  warn "@@@ $sequence, $config, $block_mode";

  ## Configure RTF display
  my @colours        = (undef);  my $class_to_style = $self->_class_to_style;
  my $spacer         = $config->{'v_space'} ? ' ' x $config->{'display_width'} : '';
  my $c              = 1;
  my $i              = 0;
  my $j              = 0;
  my @output;

  foreach my $class (sort { $class_to_style->{$a}[0] <=> $class_to_style->{$b}[0] } keys %$class_to_style) {
    my $rtf_style = {};

    $rtf_style->{'\cf'      . $c++} = substr $class_to_style->{$class}[1]{'color'}, 1         
   if $class_to_style->{$class}[1]{'color'};    $rtf_style->{'\chcbpat' . $c++} = substr $class_to_style->{$class}[1]{'background-color'},
 1 if $class_to_style->{$class}[1]{'background-color'};
    $rtf_style->{'\b'}              = 1                                                       
   if $class_to_style->{$class}[1]{'font-weight'}     eq 'bold';
    $rtf_style->{'\ul'}             = 1                                                          if $class_to_style->{$class}[1]{'text-decoration'} eq 'underline';

    $class_to_style->{$class}[1] = $rtf_style;

    push @colours, [ map hex, unpack 'A2A2A2', $rtf_style->{$_} ] for sort grep /\d/, keys %$rtf_style;
  }

  foreach my $lines (@$sequence) {
    my ($section, $class, $previous_class, $count);

    $lines->[-1]{'end'} = 1;

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

        $section = '';
      }

      $section       .= $seq->{'letter'};
      $previous_class = $class;
      $count++;
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

  if ($block_mode) {
    foreach my $block (@output) {
      $rtf->paragraph(\'\fs20', $_)      for @$block;
      $rtf->paragraph(\'\fs20', $spacer) if $spacer;
    }
  } else {
    for my $i (0..$#{$output[0]}) {
      $rtf->paragraph(\'\fs20', $_->[$i]) for @output;
      $rtf->paragraph(\'\fs20', $spacer)  if $spacer;
    }
  }
 
  $rtf->close;

  print $file $string;

  $file->save;

  return undef; ## no error
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
      res  => [ $i++, { 'color' => "#$styles->{'SEQ_RESEQEUNCING'}{'default'}" } ],
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
  my ($self, $file, $component) = @_;
  my $hub     = $self->hub;
  my $error   = undef;

  my ($data, $config) = $component->fetch_data;

  my $data_type       = $hub->param('data_type');
  my $object          = $hub->core_object($data_type);

  my @trans_objects   = ($data_type eq 'Gene' || $data_type eq 'LRG') ? $object->get_all_transcripts : @$data;
  @trans_objects      = [$object] if($data_type eq 'Transcript');

  my $object_id       = ($data_type eq 'Gene' || $data_type eq 'LRG') ? $object->stable_id : '';
  my $slice           = $object->slice('expand');
  $slice              = $self->slice if($slice == 1);
  my $strand          = $hub->param('strand');
  if(($strand ne 1) && ($strand ne -1)) {$strand = $slice->strand;}
  if($strand != $slice->strand){ $slice=$slice->invert; }
  my $params          = $self->params;
  my $genomic         = $hub->param('genomic');
  my $seq_region_name = $object->seq_region_name;
  my $seq_region_type = $object->seq_region_type;
  my $slice_name      = $slice->name;
  my $slice_length    = $slice->length;
  my $fasta;
  if (scalar keys %$params) {
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

    foreach (@$data) {
      my $transcript = $_->Obj;
      my $id         = ($object_id ? "$object_id:" : '') . $transcript->stable_id;
      my $type       = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') ? $transcript->analysis->logic_name : $transcript->status . '_' . $transcript->biotype;

      $intron_id = 1;

      foreach (sort keys %$params) {
        my $o = $output->{$_}($transcript, $id, $type) if exists $output->{$_};

        next unless ref $o eq 'ARRAY';

        foreach (@$o) {
          $self->string(">$_->[0]");
          $self->string($fasta) while $fasta = substr $_->[1], 0, 60, '';
        }
      }

      $self->string('');
    }
  }

  if (defined $genomic && $genomic ne 'off') {
    my $masking = $genomic eq 'soft_masked' ? 1 : $genomic eq 'hard_masked' ? 0 : undef;
    my ($seq, $start, $end, $flank_slice);

    if ($genomic =~ /flanking/) {
      for (5, 3) {
        if ($genomic =~ /$_/) {
          if ($strand == $params->{'feature_strand'}) {
            ($start, $end) = $_ == 3 ? ($slice_length - $hub->param('flank3_display') + 1, $slice_length) : (1, $hub->param('flank5_display'));
          } else {
            ($start, $end) = $_ == 5 ? ($slice_length - $hub->param('flank5_display') + 1, $slice_length) : (1, $hub->param('flank3_display'));
          }

          $flank_slice = $slice->sub_Slice($start, $end);

          if ($flank_slice) {
            $seq  = $flank_slice->seq;

            $self->string(">$_' Flanking sequence " . $flank_slice->name);
            $self->string($fasta) while $fasta = substr $seq, 0, 60, '';
          }
        }
      }
    } else {
      $seq = defined $masking ? $slice->get_repeatmasked_seq(undef, $masking)->seq : $slice->seq;
      $self->string(">$seq_region_name dna:$seq_region_type $slice_name");
      $self->string($fasta) while $fasta = substr $seq, 0, 60, '';
    }
  }


  return $error;
}


1;
