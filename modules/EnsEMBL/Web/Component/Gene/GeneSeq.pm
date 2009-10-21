package EnsEMBL::Web::Component::Gene::GeneSeq;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);

sub _init {
  my $self = shift;
  my $object = $self->object;
  
  $self->cacheable(1);
  $self->ajaxable(1);
  
  $self->{'subslice_length'} = $object->param('force') || 10000 * ($object->param('display_width') || 60) if $object;
}

sub caption { return undef; }

sub content {
  my $self = shift;
  
  my $object    = $self->object;
  my $slice     = $object->get_slice_object->Obj; # Object for this section is the slice
  my $length    = $slice->length;
  my $species   = $object->species;
  my $type      = $object->type;
  my $site_type = ucfirst(lc $object->species_defs->ENSEMBL_SITETYPE) || 'Ensembl';
  
  my $html = $self->_info('Sequence markup', qq{
    <p>
      $site_type has a number of sequence markup pages on the site. You can view the exon/intron structure
      of individual transcripts by selecting the transcript name in the table above, then clicking
      Exons in the left hand menu. Alternatively you can see the sequence of the transcript along with its
      protein translation and variation features by selecting the transcript followed by Sequence &gt; cDNA.
    </p>
    <p>
      This view and the transcript based sequence views are configurable by clicking on the "Configure this page"
      link in the left hand menu
    </p>
  }) . '<br />';

  if ($length >= $self->{'subslice_length'}) {
    my $base_url = "/$species/Component/$type/Web/GeneSeq/sub_slice?length=$length;name=" . $slice->name;
    
    $html .= $self->get_key($object, $site_type) . $self->chunked_content($length, $self->{'subslice_length'}, $base_url);
  } else {
    $html .= $self->content_sub_slice($slice); # Direct call if the sequence length is short enough
  }
  
  return $html;
}

sub content_sub_slice {
  my ($self, $slice) = @_;
  
  my $object = $self->object;
  my $start  = $object->param('subslice_start');
  my $end    = $object->param('subslice_end');
  my $length = $object->param('length');
  
  $slice ||= $object->get_slice_object->Obj;
  
  $slice = $slice->sub_Slice($start, $end) if $start && $end;
  
  my $config = {
    display_width => $object->param('display_width') || 60,
    site_type     => ucfirst(lc $object->species_defs->ENSEMBL_SITETYPE) || 'Ensembl',
    gene_name     => $object->Obj->stable_id,
    species       => $object->species,
    title_display => 'yes',
    key_template  => qq{<p><code><span class="%s">THIS STYLE:</span></code> %s</p>},
    key           => ''
  };

  for (qw(exon_display exon_ori snp_display line_numbering)) {
    $config->{$_} = $object->param($_) unless $object->param($_) eq 'off';
  }
  
  $config->{'exon_features'} = $object->Obj->get_all_Exons;
  $config->{'slices'} = [{ slice => $slice, name => $config->{'species'} }];

  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'} = 1;
  }

  my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);

  $self->markup_exons($sequence, $markup, $config) if $config->{'exon_display'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
  $self->markup_line_numbers($sequence, $config) if $config->{'line_numbering'};
  
  if ($start == 1) {
    $config->{'html_template'} = qq{<pre style="margin-bottom:0">&gt;} . $object->param('name') . "\n%s</pre>";
  } elsif ($end && $end == $length) {
    $config->{'html_template'} = '<pre style="margin-top:0">%s</pre>';
  } elsif ($start && $end) {
    $config->{'html_template'} = '<pre style="margin:0 0 0 1em">%s</pre>';
  } else {
    $config->{'html_template'} = "<p>$config->{'key'}</p><pre>&gt;" . $slice->name . "\n%s</pre>";
  }
  
  return $self->build_sequence($sequence, $config);
}

sub get_key {
  my ($self, $object, $site_type) = @_;
  
  my $key_template = '<p><code><span class="%s">THIS STYLE:</span></code> %s</p>';
  my $gene_name    = $object->Obj->stable_id;
  my $exon_label   = ucfirst $object->param('exon_display');
  my $rtn;
  
  $exon_label = $site_type if $exon_label eq 'Core';
  
  my @map = (
    [ 'exon_display', 'eg,eo'    ],
    [ 'snp_display',  'sn,si,sd' ]
  );
  
  my $key = {
    eg  => "Location of $gene_name exons",
    eo  => "Location of $exon_label exons",
    sn  => 'Location of SNPs',
    si  => 'Location of inserts',
    sd  => 'Location of deletes'
  };
  
  foreach (@map) {
    next if ($object->param($_->[0])||'off') eq 'off';
    
    $rtn .= sprintf $key_template, $_, $key->{$_} for split ',', $_->[1];
  }
  
  return $rtn;
}

1;
