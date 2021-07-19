=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Transcript::TranscriptSeq;

use strict;
  
use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

use EnsEMBL::Web::TextSequence::View::Transcript;

use EnsEMBL::Web::TextSequence::Annotation::Exons;
use EnsEMBL::Web::TextSequence::Annotation::TranscriptVariations;

use List::Util qw(max);
use EnsEMBL::Web::Lazy::Hash qw(lazy_hash);

sub too_rare_snp {
  my ($self,$vf,$config) = @_;

  return 0 unless $config->{'hide_rare_snps'} and $config->{'hide_rare_snps'} ne 'off'; 
  my $val = abs $config->{'hide_rare_snps'};
  my $mul = ($config->{'hide_rare_snps'}<0)?-1:1;
  return ($mul>0) unless $vf->minor_allele_frequency;
  return ($vf->minor_allele_frequency - $val)*$mul < 0; 
}

sub _transcript_variation_to_variation_feature {
  my ($self,$tv) = @_;

  my $vfid = $tv->_variation_feature_id;
  my $val = ($self->{'vf_cache'}||{})->{$vfid};
  return $val if defined $val;
  return $tv->variation_feature;
}

sub _get_transcript_variations {
  my ($self,$args,$vf_cache) = @_;

  my $trans = $args->{'transcript'};
  # Most VFs will be in slice for transcript, so cache them.
  if($vf_cache and !$self->{'vf_cache'}) {

    my $vfa = $self->hub->get_adaptor('get_VariationFeatureAdaptor','variation');
    $self->{'vf_cache'} = {};
    my $vfs = $vfa->fetch_all_by_Slice_constraint($trans->feature_Slice);
    $self->{'vf_cache'}{$_->dbID} = $_ for(@$vfs);
    $vfs = $vfa->fetch_all_somatic_by_Slice_constraint($trans->feature_Slice);
    $self->{'vf_cache'}{$_->dbID} = $_ for(@$vfs);
  }
  my $tva = $self->hub->get_adaptor('get_TranscriptVariationAdaptor', 'variation');
  return $tva->fetch_all_by_Transcripts_with_constraint([ $trans ]);
}

sub get {
  my ($self,$args) = @_;

  my $trans = $args->{'transcript'};
  my $object = EnsEMBL::Web::Root->new_object('Transcript',$trans);
  my $slice = $trans->feature_Slice;
  my @exons = @{$trans->get_all_Exons};
  my $trans_strand = $exons[0]->strand;
  my $start_phase  = $exons[0]->phase;
  my $start_pad    = $start_phase > 0 ? $start_phase : 0; # Determines if the transcript starts mid-codon
  my $cd_start     = $trans->cdna_coding_start;
  my $cd_end       = $trans->cdna_coding_end;
  my $config = $args->{'config'};
  $config->{'species'} = $args->{'species'};
  my $adorn = $args->{'adorn'};

  my $seq;
  my $mk = {};
  if ($trans->translation) {
    my $five_prime  = $trans->five_prime_utr;
    my $three_prime = $trans->three_prime_utr;
        
    $_ = $_ ? $_->seq : $_ for $five_prime, $three_prime;
        
    $seq = join '', ($five_prime||''), $trans->translateable_seq, ($three_prime||'');
  } else {
    $seq = $trans->seq->seq;
  }
  my $length = length $seq;
  $config->{'length'} = $length;
  my @markup;

  my @reference_seq = map {{ letter => $_ }} split '', $seq;
  my $variation_seq = { name => 'snp_display', seq => [] };
  my $coding_seq    = { name => 'coding_seq',  seq => [] };
  my $protein_seq   = { name => 'translation', seq => [] };
  my @rna_seq;
  if ($config->{'rna'}) {
    my @rna_notation = $object->rna_notation($trans);
    
    if (@rna_notation) {
      @rna_seq = map {{ name => 'rna', seq => [ map {{ letter => $_ }} split '', $_ ] }} @rna_notation;
    } else {
      $config->{'rna'} = 0;
    }
  }

  if ($config->{'exons'}) {
    my $flip = 0;
    my $pos = $start_pad;
    
    foreach (@exons) {
      $pos += length $_->seq->seq;
      $flip = 1 - $flip;
      push @{$mk->{'exons'}{$pos}{'type'}}, $mk->{'exons'}{$pos}{'overlap'} ? 'exon2' : "exon$flip";
    }   
  }   
  delete $mk->{$length}; # We get a key which is too big, causing an empty span to be printed later

  for (0..$length - 1) {
    # Set default vaules
    $variation_seq->{'seq'}[$_]{'letter'} = ' ';
    $coding_seq->{'seq'}[$_]{'letter'}    = $protein_seq->{'seq'}[$_]{'letter'} = '.'; 
    
    if (defined $cd_start and $_ + 1 >= $cd_start && $_ + 1 <= $cd_end) {
      $coding_seq->{'seq'}[$_]{'letter'} = $reference_seq[$_]{'letter'} if $config->{'coding_seq'};
    } elsif ($config->{'codons'}) {
      $mk->{'codons'}{$_}{'class'} = 'cu';
    }     
  }
  
  $_ += $start_pad for $cd_start, $cd_end; # Shift values so that codons and variations appear in the right place

  my $can_translate = 0;

  eval {
    my $pep_obj    = $trans->translate;
    my $peptide    = $pep_obj->seq;
    my $flip       = 0;
    my $startphase = $trans->translation->start_Exon->phase;
    my $s          = 0;
    
    $can_translate = 1;
    
    if ($startphase > 0) {
      $s = 3 - $startphase;
      $peptide = substr $peptide, 1;
    }   
    
    for (my $i = $cd_start + $s - 1; $i + 2 <= $cd_end; $i += 3) {
      if ($config->{'codons'}) {
        $mk->{'codons'}{$i}{'class'} = $mk->{'codons'}{$i + 1}{'class'} = $mk->{'codons'}{$i + 2}{'class'} = "c$flip";
    
        $flip = 1 - $flip;
      }   
    
      if ($config->{'translation'}) {
        $protein_seq->{'seq'}[$i]{'letter'}     = $protein_seq->{'seq'}[$i + 2]{'letter'} = '-';
        $protein_seq->{'seq'}[$i + 1]{'letter'} = substr($peptide, int(($i + 1 - $cd_start) / 3), 1) || ($i + 1 < $cd_end ? '*' : '.'); 
      }   
    }   
  };  

  # If the transcript starts or ends mid-codon, make the protein sequence show -X- at the start or the end respectively
  if ($config->{'translation'}) {
    my ($pos_start, $pos_end, $strip_end);
    my @partial = qw(- X -);

    if ($start_pad) {
      ($pos_start) = grep $protein_seq->{'seq'}[$_ - 1]{'letter'} eq '.', 1..3; # Find the positions of . characters at the start
    }   

    # If length is multiple of 3, ignore it. If length is 1 or 2 more than a multiple of 3 we use 2 or 1 (respectively) characters from @partial to complete 3 bases.
    if ($strip_end = (3 - ($cd_end - $cd_start + 1) % 3) % 3) {
      ($pos_end) = grep $protein_seq->{'seq'}[$_ + 1]{'letter'} =~ /\*|\-/, -3..-1; # Find the positions of - or * characters at the end
    }   

    # Replace with as much of -X- as fits in the space and remove the extra chars from the end if required
    $protein_seq->{'seq'}[$pos_start]{'letter'} = $partial[ $pos_start ]  while $pos_start--;
    $protein_seq->{'seq'}[$pos_end]{'letter'}   = $partial[ $pos_end ]    while $pos_end++;

    splice @{$protein_seq->{'seq'}}, -1 * $strip_end if $strip_end;
  }
  
  $config->{'slices'} = [{ vtype => 'main', seq => \@reference_seq, slice => $slice }];

  unshift @markup, $mk;
  my @seq_names = ( $config->{'species'} );
  for ($variation_seq, $coding_seq, $protein_seq, @rna_seq) {
    if ($config->{$_->{'name'}}) {
      if ($_->{'name'} eq 'snp_display') {
        unshift @markup, {}; 
        unshift @{$config->{'slices'}}, { vtype => $_->{'name'}, seq => $_->{'seq'} }; 
        unshift @seq_names,$_->{'name'};
      } else {
        push @markup, {}; 
        push @{$config->{'slices'}}, { slice => $slice, name => $_->{'name'} , vtype => $_->{'name'}, seq => $_->{'seq'} };
        push @seq_names,$_->{'name'};
      }
    }     
  }
  $self->view->set_annotations($config);
  $self->view->prepare_ropes($config,$config->{'slices'});

  my $main_idx;
  my $idx = 0;
  my @nseq = @{$self->view->sequences};
  foreach my $sl (@{$config->{'slices'}}) {
    my $seq = shift @nseq;
    $seq->legacy($sl->{'seq'});
    $main_idx = $idx if $sl->{'vtype'} eq 'main';
    $idx++;
  }
  
  $config->{'transcript'} = $args->{'transcript'};

  my $seq0 = $self->view->sequences->[$main_idx];
  die "No seq0" unless $seq0 and defined $main_idx;
  $self->view->annotate($config,$config->{'slices'}[$main_idx],$markup[$main_idx],$seq,$seq0);

  my @sequence = map { $_->legacy } @{$self->view->sequences};
 
  if (!$config->{'utr'}) {
    foreach (@sequence) {
      splice @$_, $cd_end;
      splice @$_, 0, $cd_start - 1;
    }     
        
    $config->{'length'} = scalar @{$sequence[0]};
        
    foreach my $mk (grep scalar keys %$_, @markup) {
      my $shifted; 
          
      foreach my $type (keys %$mk) {
        my %tmp = map { $_ - $cd_start + 1 >= 0 && $_ - $cd_start + 1 < $config->{'length'} ? ($_ - $cd_start + 1 => $mk->{$type}{$_}) : () } keys %{$mk->{$type}};
        my $decap = max(-1,grep {  $_-$cd_start+1 < 0 } keys %{$mk->{$type}});
        $shifted->{$type} = \%tmp;
        if($decap > 0 and $type eq 'exons') {
          $shifted->{$type}{0}{'type'} = $mk->{$type}{$decap}{'type'};
        }   
      }     
              
      $mk = $shifted;
    }
  }

 # Used to set the initial sequence colour
  if ($config->{'exons'}) {
    $_->{'exons'}{0}{'type'} ||= [ 'exon0' ] for @markup;
  }
  
  return ($self->view->sequences,\@markup,\@seq_names);
}

###

sub get_sequence_data {
  my ($self, $object, $config,$adorn) = @_;

  my $hub = $self->hub;
  my ($sequence,$markup,$names) = $self->get({
    species => $config->{'species'},
    type => $object->get_db,
    transcript => $object->Obj,
    config => $config,
    adorn => $adorn,
    conseq_filter => [$self->param('consequence_filter')],
    hidden_sources => [$self->param('hidden_sources')],
  });
 
  $config->{'names'} = $names;
 
  return ($sequence,$markup,$names);
}

sub initialize_new {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object('transcript');

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);

  my $adorn = $hub->param('adorn') || 'none';
 
  my $config = { 
    species         => $hub->species,
    transcript      => 1,
    variants_as_n   => scalar $self->param('variants_as_n')
  };
 
  $config->{'display_width'} = $vc->get('display_width');
  $config->{$_} = ($self->param($_) eq 'on') ? 1 : 0 for qw(exons exons_case codons coding_seq translation rna snp_display utr hide_long_snps hide_rare_snps);
  $config->{'codons'}      = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $object->Obj->translation;
 
  if ($self->param('line_numbering') && $self->param('line_numbering') ne 'off') {
    $config->{'line_numbering'} = 'on';
    $config->{'number'}         = 1;
  }
  
  $self->set_variation_filter($config);
  
  my $view = $self->view($config);
  
  my ($sequences, $markup,$names) = $self->get_sequence_data($object, $config, $adorn);

  # XXX hack to set principal
  $sequences->[1]->principal(1) if @$sequences>1 and $config->{'snp_display'};

  $self->view->markup($sequences,$markup,$config);

  $view->legend->expect('variants') if ($config->{'snp_display'}||'off') ne 'off';

  return ($sequences, $config);
}

sub content {
  my $self = shift;
  my ($sequences, $config) = $self->initialize_new;

  return  $self->describe_filter($config).$self->build_sequence($sequences, $config);
}

sub export_options { return {'action' => 'Transcript'}; }

sub initialize_export_new {
  my $self = shift;
  my $hub = $self->hub;
  my ($sequence, $config) = $self->initialize_new;
  return ($sequence, $config);
}

sub make_view {
  my ($self) = @_;

  return EnsEMBL::Web::TextSequence::View::Transcript->new(
    $self->hub
  );
}

1;
