#$Id:#
package EnsEMBL::Web::Component::LRG::LRGSeq;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::LRG);

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
  my $slice     = $object->Obj;
  my $length    = $slice->length;
  my $species   = $object->species;
  my $type      = $object->type;
  my $site_type = ucfirst(lc $object->species_defs->ENSEMBL_SITETYPE) || 'Ensembl';
  
  my $html = sprintf('
    <div class="other-tool">
      <p><a class="seq_blast find" href="#">BLAST this sequence</a></p>
      <form class="external hidden seq_blast" action="/Multi/blastview" method="post">
        <fieldset>
          <input type="hidden" name="_query_sequence" value="%s" />
          <input type="hidden" name="query" value="peptide" />
          <input type="hidden" name="database" value="peptide" />
          <input type="hidden" name="species" value="%s" />
        </fieldset>
      </form>
    </div>',
    uc $slice->seq(1),
    $species
  );
  
  if ($length >= $self->{'subslice_length'}) {
    my $base_url = $self->ajax_url('sub_slice') . ";length=$length;name=" . $slice->name;
    
    $html .= '<div class="sequence_key"></div>' . $self->chunked_content($length, $self->{'subslice_length'}, $base_url);
  } else {
    $html .= $self->content_sub_slice($slice); # Direct call if the sequence length is short enough
  }
  
  $html .= $self->_info('Sequence markup', qq{
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
  });
  
  return $html;
}

sub content_sub_slice {
  my ($self, $slice) = @_;
  
  my $object = $self->object;
  my $start  = $object->param('subslice_start');
  my $end    = $object->param('subslice_end');
  my $length = $object->param('length');

  $slice ||= $object->slice;
  $slice   = $slice->sub_Slice($start, $end) if $start && $end;
  
  my $config = {
    display_width   => $object->param('display_width') || 60,
    site_type       => 'all',
    gene_name       => $object->Obj->stable_id,
    species         => $object->species,
    title_display   => 'yes',
    sub_slice_start => $start,
    sub_slice_end   => $end
  };

  for (qw(exon_display exon_ori snp_display line_numbering)) {
    $config->{$_} = $object->param($_) unless $object->param($_) eq 'off';
  }
  
  my @lrg_exons;
  
  foreach my $exon (@{$object->transcript->get_all_Exons}) {
    next unless $exon && $exon->isa('Bio::EnsEMBL::Exon');
    next if $exon->stable_id;
    
    $exon->stable_id('LRG Exon');
    push @lrg_exons, $exon;
  }
  
  
  $config->{'exon_features'} = \@lrg_exons;
  $config->{'slices'}        = [{ slice => $slice, name => $config->{'species'} }];
  
  if ($config->{'line_numbering'}) {
    $config->{'end_number'} = 1;
    $config->{'number'}     = 1;
  }
  
  my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config);

  $self->markup_exons($sequence, $markup, $config)     if $config->{'exon_display'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};
  $self->markup_line_numbers($sequence, $config)       if $config->{'line_numbering'};
  
  if ($start == 1) {
    $config->{'html_template'} = qq{<pre class="text_sequence" style="margin-bottom:0">&gt;} . $object->param('name') . "\n%s</pre>";
  } elsif ($end && $end == $length) {
    $config->{'html_template'} = '<pre class="text_sequence">%s</pre>';
  } elsif ($start && $end) {
    $config->{'html_template'} = '<pre class="text_sequence" style="margin:0 0 0 1em">%s</pre>';
  } else {
    $config->{'html_template'} = sprintf('<div class="sequence_key">%s</div>', $self->get_key($config)).qq{<pre class="text_sequence">&gt;} . $slice->name . "\n%s</pre>";
  }
  
  $config->{'html_template'} .= '<p class="invisible">.</p>';
  
  return $self->build_sequence($sequence, $config);
}

1;
