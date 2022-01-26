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

package EnsEMBL::Web::ImageConfig::contigviewbottom;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use URI::Escape qw(uri_unescape);
use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Command::UserData::AddFile;

use parent qw(EnsEMBL::Web::ImageConfig);

sub glyphset_tracks {
  ## @override
  ## Adds trackhub tracks before returning the list of tracks
  my $self = shift;

  if (!$self->{'_glyphset_tracks'}) {
    $self->get_node('user_data')->after($_) for grep $_->get_data('trackhub_menu'), $self->tree->nodes;
    $self->SUPER::glyphset_tracks;
  }

  return $self->{'_glyphset_tracks'};
}

sub config_url_params {
  ## @override
  ## Returns list of trackhub related params along with other url params that can change the image config
  my $self = shift;
  return $self->SUPER::config_url_params || (), $self->type, qw(attach trackhub format menu);
}

sub update_from_url {
  ## @override
  my ($self, $params) = @_;

  my $hub             = $self->hub;
  my $session         = $hub->session;
  my $species         = $self->species;
  my $species_defs    = $self->species_defs;

  my $attach = !!$params->{'attach'};

  ## Don't use CGI::param here, as we want to keep values unescaped until we've finished splitting them
  delete $params->{$self->type};
  delete $params->{'attach'};
  my $raw_params;
  foreach (split(/;/, $self->hub->controller->query)) {
    $_ =~ /(\w+)=(.+)/;
    $raw_params->{$1} = $2;
  }
  my @values = grep $_, split(/,/, $raw_params->{'attach'} || ''); #attach=url:https://some_url_to_attach/=normal
  push @values, grep $_, split(/,/, $raw_params->{$self->type} || ''); # contigviewbottom=url:https://some_url_to_attach/=normal

  # if param name is 'trackhub'
  push @values, $raw_params->{'trackhub'} || ();

  # Backwards compatibility
  if ($params->{'format'} && $params->{'format'} eq 'DATAHUB') {
    $params->{'format'} = 'TRACKHUB';
  }

  my @other_values;
  foreach my $v (@values) {
    my $format = $params->{'format'};
    my ($url, $renderer);

    if ($v =~ /^url/) {
      $v =~ s/^url://;
      $attach = 1;
      ($url, $renderer) = split /=/, $v;
    }
    else {
      if ($v =~/^http|^ftp/) {
        $url = $v;
      }
    }

    if ($attach) {
      ## Backwards compatibility with 'contigviewbottom=url:http...'-type parameters
      ## as well as new 'attach=http...' parameter
      my $p = uri_unescape($url);

      my $menu_name   = $params->{'menu'};
      my $all_formats = $species_defs->multi_val('DATA_FORMAT_INFO');

      if (!$format) {
        my @path = split(/\./, $p);
        my $ext  = $path[-1] eq 'gz' ? $path[-2] : $path[-1];

        while (my ($name, $info) = each %$all_formats) {
          if ($ext =~ /^$name$/i) {
            $format = $name;
            last;
          }
        }
        if (!$format) {
          # Didn't match format name - now try checking format extensions
          while (my ($name, $info) = each %$all_formats) {
            if ($ext eq $info->{'ext'}) {
              $format = $name;
              last;
            }
          }
        }
      }

      my $style = $all_formats->{lc $format}{'display'} eq 'graph' ? 'wiggle' : $format;
      my $code  = join '_', md5_hex("$species:$p"), $session->session_id;
      my $n;

      if ($menu_name) {
        $n = $menu_name;
      } else {
        $n = $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
      }

      # Don't add if the URL or menu are the same as an existing track
      my $url_record_data = $session->get_record_data({'type' => 'url', 'code' => $code});
      my $duplicate_record_data = $session->get_record_data({'name' => $n, 'type' => 'url'});
      if (keys %$url_record_data) {
        $session->set_record_data({
          'type'      => 'message',
          'function'  => '_warning',
          'code'      => "duplicate_url_track_$code",
          'message'   => "You have already attached the URL $p. No changes have been made for this data source.",
        });

        next;
      } elsif (%$duplicate_record_data) {
        $session->set_record_data({
          'type'      => 'message',
          'function'  => '_error',
          'code'      => "duplicate_url_track_$n",
          'message'   => qq{Sorry, the menu "$n" is already in use. Please change the value of "menu" in your URL and try again.},
        });

        next;
      }

      # We then have to create a node in the user_config
      my %ensembl_assemblies = %{$species_defs->assembly_lookup};

      if (uc $format eq 'TRACKHUB') {
        my $info;
        ($n, $info) = $self->_add_trackhub($n, $p);
        if ($info->{'error'}) {
          my @errors = @{$info->{'error'} || []};
          $session->set_record_data({
            'type'      => 'message',
            'function'  => '_warning',
            'code'      => 'trackhub:' . md5_hex($p),
            'message'   => "There was a problem attaching trackhub $n: @errors",
          });
        } else {
          my $assemblies = $info->{'genomes'} || {$species => $species_defs->get_config($species, 'ASSEMBLY_VERSION')};

          foreach (keys %$assemblies) {
            my ($data_species, $assembly) = @{$ensembl_assemblies{$_} || []};
            if ($assembly) {
              my $data = $session->set_record_data({
                'type'        => 'url',
                'url'         => $p,
                'species'     => $data_species,
                'code'        => join('_', md5_hex($n . $data_species . $assembly . $p), $session->session_id),
                'name'        => $n,
                'format'      => $format,
                'style'       => $style,
                'assembly'    => $assembly,
              });
            }
          }
        }
      } else {
        ## Either upload or attach the file, as appropriate
        my $command = EnsEMBL::Web::Command::UserData::AddFile->new({'hub' => $hub});
        ## Fake the params that are passed by the upload form
        $hub->param('text', $p);
        $hub->param('format', $format);
        $command->upload_or_attach($renderer);
        ## Discard URL param, as we don't need it once we've uploaded the file,
        ## and it only messes up the page URL later
        $hub->input->delete('url');
      }
      # We have to create a URL upload entry in the session
      my $message  = sprintf('Data has been attached to your display from the following URL: %s', encode_entities($p));
      $session->set_record_data({
        'type'      => 'message',
        'function'  => '_info',
        'code'      => 'url_data:' . md5_hex($p),
        'message'   => $message,
      });
    } else {
      push @other_values, $v; # let the parent method deal with these
    }
  }

  if (@other_values) {
    $params->{$self->type} = join(',', @other_values);
  }

  return $self->SUPER::update_from_url($params);
}

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    image_resizeable  => 1,
    bottom_toolbar    => 1,
    sortable_tracks   => 'drag', # allow the user to reorder tracks on the image
    can_trackhubs     => 1,      # allow track hubs
    opt_halfheight    => 0,      # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_lines         => 1,      # draw registry lines
  });

  # First add menus in the order you want them for this display
  $self->create_menus(qw(
    sequence
    marker
    trans_associated
    transcript
    longreads
    prediction
    lrg
    dna_align_cdna
    dna_align_est
    dna_align_rna
    dna_align_other
    protein_align
    protein_feature
    rnaseq
    ditag
    simple
    genome_attribs
    misc_feature
    variation
    recombination
    somatic
    functional
    multiple_align
    conservation
    pairwise_blastz
    pairwise_tblat
    pairwise_other
    dna_align_compara
    genome_targeting
    oligo
    repeat
    external_data
    user_data
    decorations
    information
  ));

  my %desc = (
    contig    => 'Track showing underlying assembly contigs.',
    seq       => 'Track showing sequence in both directions. Only displayed at 1Kb and below.',
    codon_seq => 'Track showing 6-frame translation of sequence. Only displayed at 500bp and below.',
    codons    => 'Track indicating locations of start and stop codons in region. Only displayed at 50Kb and below.'
  );

  # Note these tracks get added before the "auto-loaded tracks" get added
  $self->add_tracks('sequence',
    [ 'contig',    'Contigs',             'contig',   { display => 'normal', strand => 'r', description => $desc{'contig'}                                                                }],
    [ 'seq',       'Sequence',            'sequence', { display => 'normal', strand => 'b', description => $desc{'seq'},       colourset => 'seq',      threshold => 1,   depth => 1      }],
    [ 'codon_seq', 'Translated sequence', 'codonseq', { display => 'off',    strand => 'b', description => $desc{'codon_seq'}, colourset => 'codonseq', threshold => 0.5, bump_width => 0 }],
    [ 'codons',    'Start/stop codons',   'codons',   { display => 'off',    strand => 'b', description => $desc{'codons'},    colourset => 'codons',   threshold => 50                   }],
  );

  $self->add_track('decorations', 'gc_plot', '%GC', 'gcplot', { display => 'normal',  strand => 'r', description => 'Shows percentage of Gs & Cs in region', sortable => 1 });

  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_trackhubs;
  $self->load_configured_bigwig;
  $self->load_configured_bigbed;
#  $self->load_configured_bam;

  #switch on some variation tracks by default
  if ($self->species_defs->DEFAULT_VARIATION_TRACKS) {
    while (my ($track, $style) = each (%{$self->species_defs->DEFAULT_VARIATION_TRACKS})) {
      $self->modify_configs([$track], {display => $style});
    }
  }
  elsif ($self->hub->database('variation')) {
    my $tracks = [qw(variation_feature_variation)];
    if ($self->species_defs->databases->{'DATABASE_VARIATION'} &&
        $self->species_defs->databases->{'DATABASE_VARIATION'}{'STRUCTURAL_VARIANT_COUNT'}) {
      push @$tracks, 'variation_feature_structural_smaller';
    }
    $self->modify_configs($tracks, {display => 'compact'});
  }

  # These tracks get added after the "auto-loaded tracks get addded
  if ($self->species_defs->ENSEMBL_MOD) {
    $self->add_track('information', 'mod', '', 'text', {
      name    => 'Message of the day',
      display => 'normal',
      menu    => 'no',
      strand  => 'r',
      text    => $self->species_defs->ENSEMBL_MOD
    });
  }

  $self->add_tracks('information',
    [ 'missing', '', 'text', { display => 'normal', strand => 'r', name => 'Disabled track summary', description => 'Show counts of number of tracks turned off by the user' }],
    [ 'info',    '', 'text', { display => 'normal', strand => 'r', name => 'Information',            description => 'Details of the region shown in the image' }]
  );

  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );

  ## LRG track
  if ($self->species_defs->HAS_LRG) {
    $self->add_tracks('lrg',
      [ 'lrg_transcript', 'LRG', 'lrg', {
        display     => 'off', # Switched off by default
        strand      => 'b',
        name        => 'LRG',
        description => 'Transcripts from the <a class="external" href="http://www.lrg-sequence.org">Locus Reference Genomic sequence</a> project.',
        logic_names => [ 'LRG_import' ],
        logic_name  => 'LRG_import',
        colours     => $self->species_defs->colour('gene'),
        label_key   => '[display_label]',
        colour_key  => '[logic_name]',
        zmenu       => 'LRG',
      }]
    );
  }

  ## Switch on multiple alignments defined in MULTI.ini
  my $compara_db      = $self->hub->database('compara');
  if ($compara_db) {
    my $defaults = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'COMPARA_DEFAULT_ALIGNMENT_IDS'};

    foreach my $default (@$defaults) {
      my ($mlss_id,$species,$method) = @$default;
      next unless $mlss_id;
      $self->modify_configs(
        [ 'alignment_compara_'.$mlss_id.'_constrained' ],
        { display => 'compact' }
      );
    }
  }

  my @feature_sets = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS');

  foreach my $f_set (@feature_sets) {
    $self->modify_configs(
      [ "regulatory_regions_funcgen_$f_set" ],
      { depth => 25, height => 6 }
    );
  }

  ## Turn off motif feature track by default
  $self->modify_configs(['fg_motif_features'], {'display' => 'off'});

  ## Regulatory build track now needs to be turned on explicitly
  $self->modify_configs(['regbuild'], {display => 'compact'});
}

1;
